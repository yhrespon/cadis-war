"""Géométrie procédurale : loft (tubes), dômes (cheveux), coques (vêtements), normales."""
import numpy as np

def unit(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-12)

def calc_normals(pos, idx):
    n = np.zeros_like(pos)
    tri = pos[idx]
    fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    for k in range(3): np.add.at(n, idx[:, k], fn)
    return unit(n)

def loft(path, radii, nseg=14, cap_start=False, cap_end=False, rot=0.0):
    """Tube le long de path (K,3) ; radii (K,2) = (rayon u, rayon v). Retourne pos, idx, ring_id(K)"""
    path = np.asarray(path, float); radii = np.asarray(radii, float); K = len(path)
    T = unit(np.gradient(path, axis=0))
    P = []; C = []
    ang = np.linspace(0, 2 * np.pi, nseg, endpoint=False) + rot
    for k in range(K):
        t = T[k]; ref = np.array([1.0, 0, 0]) if abs(t[0]) < 0.9 else np.array([0, 0, 1.0])
        u = unit(ref - t * np.dot(ref, t)); v = np.cross(t, u)
        P.append(path[k] + radii[k, 0] * np.cos(ang)[:, None] * u + radii[k, 1] * np.sin(ang)[:, None] * v)
        C.append(np.repeat(path[k][None], nseg, 0))
    P = np.concatenate(P); C = np.concatenate(C)
    tris = []
    for k in range(K - 1):
        for s in range(nseg):
            a = k * nseg + s; b = k * nseg + (s + 1) % nseg; c = a + nseg; d = b + nseg
            tris += [(a, c, b), (b, c, d)]
    pos = P; idx = np.array(tris, int)
    if cap_start or cap_end:
        extra = []
        for flag, k in ((cap_start, 0), (cap_end, K - 1)):
            if not flag: continue
            ci = len(pos); pos = np.vstack([pos, path[k][None]])
            for s in range(nseg):
                extra.append((ci, k * nseg + (s + 1) % nseg, k * nseg + s) if k == 0 else (ci, k * nseg + s, k * nseg + (s + 1) % nseg))
        idx = np.vstack([idx, np.array(extra, int)])
        C = np.vstack([C, np.zeros((len(pos) - len(C), 3))])
        for i in range(len(C)):
            if i >= K * nseg: C[i] = pos[i]
    # orientation sortante
    tri = pos[idx]; fc = tri.mean(1); fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    cc = C[idx[:, 0]]
    flip = ((fc - cc) * fn).sum(1) < 0
    # les caps ont cc==pos[ci] : ne pas retourner selon ce test
    idx[flip] = idx[flip][:, [0, 2, 1]]
    return pos, idx

def dome(center, radii, offset=1.0, lim=(60, 90, 100), nu=16, nv=30, vscale=1.0, shift=(0, 0, 0)):
    """Calotte ellipsoïdale ; lim=(devant, côtés, arrière) en degrés depuis le sommet."""
    center = np.asarray(center, float); radii = np.asarray(radii, float) + offset
    pos = []; nrm = []
    f, s, bk = lim
    phis = np.linspace(0, 2 * np.pi, nv, endpoint=False)
    for i in range(nu + 1):
        for ph in phis:
            c = np.cos(ph)
            L = s + (f - s) * max(c, 0) ** 1.5 + (bk - s) * max(-c, 0) ** 1.5
            th = np.radians(L) * i / nu
            d = np.array([np.sin(th) * np.sin(ph), np.cos(th), np.sin(th) * np.cos(ph)])
            p = center + radii * d * np.array([1, vscale, 1]) + np.array(shift) * (i == 0) * 0
            pos.append(p); nrm.append(unit(d / radii))
    pos = np.array(pos); nrm = np.array(nrm)
    tris = []
    for i in range(nu):
        for j in range(nv):
            a = i * nv + j; b = i * nv + (j + 1) % nv; c = a + nv; d = b + nv
            tris += [(a, b, c), (b, d, c)]
    idx = np.array(tris, int)
    tri = pos[idx]; fc = tri.mean(1); fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    flip = ((fc - center) * fn).sum(1) < 0
    idx[flip] = idx[flip][:, [0, 2, 1]]
    return pos, idx

def sector_brim(center, y, z0, r_in, r_out, half_angle=65, n=14, thick=0.9, drop=2.6, rows=4):
    """Visière incurvée : secteur devant la tête, qui s'abaisse vers l'extérieur ; deux faces (dessus/dessous) + tranche
    pour une épaisseur réelle (fermée, donc propre même sans rendu double face)."""
    center = np.asarray(center, float)
    a = np.radians(np.linspace(-half_angle, half_angle, n))
    P = []
    for r in range(rows):
        t = r / (rows - 1); rad = r_in + (r_out - r_in) * t
        wid = 1.0 - 0.52 * t ** 1.2                             # visière qui se rétrécit vers le bout (≈18 cm de large au bout)
        yy = y - drop * t ** 1.6 - 0.0
        P.append(np.stack([center[0] + rad * wid * np.sin(a), np.full(n, yy), z0 + rad * np.cos(a)], 1))
    top = np.concatenate(P); bot = top - np.array([0, thick, 0]) * 1.0
    pos = np.vstack([top, bot]); nb = len(top); tris = []
    for r in range(rows - 1):
        for i in range(n - 1):
            a0 = r * n + i; b0 = a0 + 1; c0 = a0 + n; d0 = c0 + 1
            tris += [(a0, c0, b0), (b0, c0, d0)]                         # dessus (normale +y)
            tris += [(nb + a0, nb + b0, nb + c0), (nb + b0, nb + d0, nb + c0)]   # dessous
    for i in range(n - 1):                                               # tranche extérieure
        a0 = (rows - 1) * n + i
        tris += [(a0, a0 + 1, nb + a0), (a0 + 1, nb + a0 + 1, nb + a0)]
    for r in range(rows - 1):                                            # tranches latérales
        for i in (0, n - 1):
            a0 = r * n + i; c0 = a0 + n
            tris += [(a0, c0, nb + a0), (c0, nb + c0, nb + a0)]
    return pos, np.array(tris, int)

def merge(parts):
    """parts: liste de dict(pos,nrm,uv,joints,weights,idx) -> un dict fusionné"""
    out = {k: [] for k in ('pos', 'nrm', 'uv', 'joints', 'weights', 'idx')}; off = 0
    for p in parts:
        for k in ('pos', 'nrm', 'uv', 'joints', 'weights'): out[k].append(p[k])
        out['idx'].append(p['idx'] + off); off += len(p['pos'])
    return {k: np.concatenate(v) for k, v in out.items()}

def solid_part(pos, idx, uv_xy, joints, weights, nrm=None):
    n = len(pos)
    return dict(pos=pos, nrm=calc_normals(pos, idx) if nrm is None else nrm,
                uv=np.tile(np.asarray(uv_xy, float), (n, 1)),
                joints=joints, weights=weights, idx=idx)
