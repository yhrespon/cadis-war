"""Correctifs v2 : torse en loft (remplace le torse creux de Body), manches, poignets,
jambes calées sur les bottes d'origine (mesures faites sur le maillage, pas à la main)."""
import numpy as np
from rig import *
from geo import *

HIPS, SPINE, SPINE1, SPINE2, NECK, HEAD = 1, 2, 3, 4, 5, 6
LSH, LARM, LFA, LHAND = 8, 9, 10, 11
RSH, RARM, RFA, RHAND = 16, 17, 18, 19
LUP, LLEG, LFOOT, RUP, RLEG, RFOOT = 24, 25, 26, 29, 30, 31

def dominant(m):
    return m['joints'][np.arange(len(m['pos'])), m['weights'].argmax(1)]

def sstep(t):
    t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

# ------------------------------------------------------------------ mesures sur le modèle
_MEAS = {}

def measure(base):
    if _MEAS: return _MEAS
    M = {m['name']: m for m in base.meshes}
    body, shoes = M['Body'], M['Shoes']
    P = body['pos']; dom = dominant(body)
    arms = {}
    for side, ids in ((1, (LSH, LARM, LFA)), (-1, (RSH, RARM, RFA))):
        sel = np.isin(dom, ids); rows = []
        for x in np.arange(10, 58, 3.0):
            s = sel & (np.abs(P[:, 0] * side - x) < 2.0)
            if s.sum() >= 6:
                y0, y1 = np.percentile(P[s, 1], [2, 98]); z0, z1 = np.percentile(P[s, 2], [2, 98])
                rows.append((x, (y0 + y1) / 2, (z0 + z1) / 2, (y1 - y0) / 2, (z1 - z0) / 2))
        r = np.array(rows)
        # lissage léger + bornes
        for c in (1, 2, 3, 4):
            r[:, c] = np.convolve(np.pad(r[:, c], 1, mode='edge'), [0.25, 0.5, 0.25], mode='valid')
        r[:, 3] = np.clip(r[:, 3], 2.6, 7.0); r[:, 4] = np.clip(r[:, 4], 2.6, 7.0)
        arms[side] = r
    # section de l'avant-bras (fin) et de la main (début) pour les poignets
    wrist = {}
    for side, fa, hd in ((1, LFA, LHAND), (-1, RFA, RHAND)):
        out = []
        for ids, lo, hi in (((fa,), 53, 57.5), ((hd,), 63.5, 67)):
            s = np.isin(dom, ids) & (P[:, 0] * side > lo) & (P[:, 0] * side < hi)
            y0, y1 = np.percentile(P[s, 1], [3, 97]); z0, z1 = np.percentile(P[s, 2], [3, 97])
            out.append(((y0 + y1) / 2, (z0 + z1) / 2, (y1 - y0) / 2, (z1 - z0) / 2))
        wrist[side] = out
    # bottes : section par hauteur, par côté
    boots = {}
    SP = shoes['pos']
    for side in (1, -1):
        rows = []
        for yy in (31, 28, 25, 22, 19, 16, 13, 10):
            s = (SP[:, 0] * side > 0) & (np.abs(SP[:, 1] - yy) < 1.6)
            x0, x1 = (SP[s, 0] * side).min(), (SP[s, 0] * side).max(); z0, z1 = SP[s, 2].min(), SP[s, 2].max()
            rows.append((yy, (x0 + x1) / 2, (z0 + z1) / 2, (x1 - x0) / 2 - 0.5, (z1 - z0) / 2 - 0.5))
        boots[side] = np.array(rows)
    _MEAS.update(arms=arms, wrist=wrist, boots=boots)
    return _MEAS

# ------------------------------------------------------------------ torse
#            y     demi-largeur  z avant  z arrière
TORSO = np.array([
    [82, 14.8, 10.8, -8.4], [88, 14.6, 10.9, -7.6], [94, 13.9, 12.2, -7.4], [100, 12.0, 12.6, -6.6],
    [106, 10.5, 13.0, -6.0], [112, 10.9, 13.5, -6.0], [118, 12.3, 12.2, -6.2], [124, 14.0, 11.0, -6.4],
    [128, 15.2, 10.0, -6.4], [132, 14.8, 8.6, -6.0], [136, 11.5, 6.4, -4.8], [140, 5.8, 4.6, -3.0]])

def torso_profile(gender='f'):
    T = TORSO.copy(); y = T[:, 0]
    if gender == 'm':
        T[:, 1] *= np.where(y >= 118, 1.10, 1.0); T[:, 1] += np.where((y >= 94) & (y <= 112), 0.9, 0.0)
        T[:, 2] -= np.where((y >= 104) & (y <= 124), 1.9, 0.0)
        T[:, 2] -= np.where((y >= 92) & (y < 104), 0.6, 0.0)
    else:
        T[:, 1] -= np.where((y >= 102) & (y <= 108), 0.5, 0.0); T[:, 2] += np.where((y >= 110) & (y <= 116), 0.8, 0.0)
    return T

def torso_weights(pos):
    y = pos[:, 1]; n = len(y)
    jy = np.array([86.4, 96.3, 107.9, 121.1, 140.0]); jid = [HIPS, SPINE, SPINE1, SPINE2, HEAD]
    w = np.zeros((n, 6)); ids = np.zeros((n, 6), int)
    for k in range(5):
        if k == 0: xs, fp = [jy[0], jy[1]], [1, 0]
        elif k == 4: xs, fp = [jy[3], jy[4]], [0, 1]
        else: xs, fp = [jy[k - 1], jy[k], jy[k + 1]], [0, 1, 0]
        w[:, k] = np.interp(y, xs, fp); ids[:, k] = jid[k]
    ax = np.abs(pos[:, 0] + 0.2)
    t = 0.85 * np.clip((ax - 11) / 6, 0, 1) * np.clip((y - 116) / 6, 0, 1)
    w[:, :5] *= (1 - t)[:, None]; w[:, 5] = t; ids[:, 5] = np.where(pos[:, 0] >= -0.2, LSH, RSH)
    o = np.argsort(-w, axis=1)[:, :4]
    W = np.take_along_axis(w, o, 1); J = np.take_along_axis(ids, o, 1)
    W /= W.sum(1, keepdims=True) + 1e-12
    return J, W

def torso_loft(prof, y_top, y_bot, pad, uv, nseg=24, caps=True, step=2.0):
    ys = np.arange(y_top, y_bot - 1e-6, -step)
    if ys[-1] > y_bot + 1e-6: ys = np.append(ys, y_bot)
    a = np.interp(ys, prof[:, 0], prof[:, 1]); zf = np.interp(ys, prof[:, 0], prof[:, 2]); zb = np.interp(ys, prof[:, 0], prof[:, 3])
    path = np.stack([np.full_like(ys, -0.2), ys, (zf + zb) / 2], 1)
    rad = np.stack([a + pad, (zf - zb) / 2 + pad], 1)
    pos, idx = loft(path, rad, nseg, cap_start=caps, cap_end=caps)
    J, W = torso_weights(pos)
    return solid_part(pos, idx, uv, J, W)

def pelvis(prof, uv, pad=0.6):
    """Bassin : part de y=92 avec le MÊME profil que le haut (raccord sans marche) ; le bas s'effile en U (largeur ET
    épaisseur) pour rester dans le volume des cuisses : plus de bloc à bords durs qui dépasse à l'entrejambe."""
    ys = np.array([92.0, 89.0, 86.0, 83.0, 80.0, 77.0])
    a_top = np.interp(92, prof[:, 0], prof[:, 1]) + 0.8
    a = np.array([a_top, a_top - 0.6, a_top - 1.8, 10.5 + pad, 7.2 + pad, 4.0 + pad])
    y3 = ys[:3]
    zf = np.interp(y3, prof[:, 0], prof[:, 2]); zb = np.interp(y3, prof[:, 0], prof[:, 3])
    zc = np.concatenate([(zf + zb) / 2, [0.2, -0.2, -0.4]])
    rz = np.concatenate([(zf - zb) / 2 + np.array([0.8, pad, pad]), [7.3 + pad * 0.3, 6.2 + pad * 0.3, 4.6]])
    path = np.stack([np.full_like(ys, -0.2), ys, zc], 1)
    pos, idx = loft(path, np.stack([a, rz], 1), 24, cap_start=True, cap_end=True)
    n = len(pos); J = np.zeros((n, 4), int); W = np.zeros((n, 4)); y = pos[:, 1]
    ts = np.clip((y - 84) / 8, 0, 1) * 0.7
    J[:, 0] = HIPS; W[:, 0] = 1 - ts; J[:, 1] = SPINE; W[:, 1] = ts
    return solid_part(pos, idx, uv, J, W)

# ------------------------------------------------------------------ bras
def arm_weights(xabs, side, c1=18.0, w1=8.0):
    ids = (LSH, LARM, LFA, LHAND) if side > 0 else (RSH, RARM, RFA, RHAND)
    s1 = sstep((xabs - c1) / w1); s2 = sstep((xabs - 36) / 7); s3 = sstep((xabs - 55) / 6)
    w = np.stack([1 - s1, s1 * (1 - s2), s1 * s2 * (1 - s3), s1 * s2 * s3], 1)
    J = np.tile(np.array(ids), (len(xabs), 1)); return J, w

SLEEVE_C1, SLEEVE_W1 = 8.0, 16.0

def sleeve(base, side, x_end, pad, uv, x_start=6.0, nseg=14):
    r = measure(base)['arms'][side]
    xs = np.append(np.arange(x_start, x_end, 3.0), x_end)
    cy = np.interp(xs, r[:, 0], r[:, 1]); cz = np.interp(xs, r[:, 0], r[:, 2])
    ry = np.interp(xs, r[:, 0], r[:, 3]); rz = np.interp(xs, r[:, 0], r[:, 4])
    taper = np.interp(xs, [x_start, x_start + 8], [0.95, 1.0])
    pe = pad + 2.4 * np.clip(1 - (xs - x_start) / 12.0, 0, 1)          # emmanchure plus ample : recouvre l'épaule du corps
    k = 0.55 + 0.45 * sstep((xs - x_start) / 10.0)                       # début effilé : la manche sort du torse sans disque saillant
    cy = cy - (1 - k) * 3.0                                              # le départ s'abaisse vers la pente d'épaule
    path = np.stack([side * xs, cy, cz], 1)
    rad = np.stack([(rz * taper + pe) * k, (ry * taper + pe) * k], 1)   # u = z, v = y (tangente selon x)
    pos, idx = loft(path, rad, nseg, cap_start=True)
    J, W = arm_weights(np.abs(pos[:, 0]), side, SLEEVE_C1, SLEEVE_W1)   # transition épaule->bras plus précoce : plus d'épaulette horizontale bras baissés
    return solid_part(pos, idx, uv, J, W)

def wrist(base, side, uv, nseg=12):
    (fy, fz, fry, frz), (hy, hz, hry, hrz) = measure(base)['wrist'][side]
    xs = np.array([54.0, 57.0, 60.5, 64.0, 67.0]); t = np.clip((xs - 54) / 13, 0, 1)
    cy = fy + (hy - fy) * t; cz = fz + (hz - fz) * t
    ry = np.minimum(fry + (hry - fry) * t, 3.4) * 0.97; rz = np.minimum(frz + (hrz - frz) * t, 3.4) * 0.97
    path = np.stack([side * xs, cy, cz], 1)
    pos, idx = loft(path, np.stack([rz, ry], 1), nseg, cap_start=True, cap_end=True)
    J, W = arm_weights(np.abs(pos[:, 0]), side)
    return solid_part(pos, idx, uv, J, W)

# ------------------------------------------------------------------ jambes
UPPER = np.array([   # y, cx(abs), cz, rx, rz  (haut de la jambe jusqu'au mollet)
    [96, 9.0, 0.8, 6.4, 8.2], [88, 9.4, 0.6, 6.7, 8.0], [80, 10.2, -0.2, 6.9, 7.4], [60, 10.0, -1.4, 6.0, 6.4],
    [52, 9.8, -1.8, 5.5, 5.8], [44, 10.6, -1.6, 5.1, 5.3], [39, 11.5, -1.3, 4.9, 4.8], [35, 12.3, -0.9, 4.8, 4.4], [32, 12.6, -1.1, 4.6, 4.6]])
# (y=35 et 32 : mesurés sur la jambe de Body ; la mesure des bottes à y>=31 ne voit que le bord de la tige)

def leg_rows(base, side):
    b = measure(base)['boots'][side]
    return np.vstack([UPPER, b[b[:, 0] <= 28]])     # y décroissant

def leg_weights(y, side):
    up, lg, ft = (LUP, LLEG, LFOOT) if side > 0 else (RUP, RLEG, RFOOT)
    n = len(y); J = np.zeros((n, 4), int); W = np.zeros((n, 4))
    s_top = sstep((90 - y) / 12); s_knee = sstep((47 - y) / 11); s_ank = sstep((14 - y) / 8)
    J[:, 0] = HIPS; W[:, 0] = 1 - s_top
    J[:, 1] = up;   W[:, 1] = s_top * (1 - s_knee)
    J[:, 2] = lg;   W[:, 2] = s_top * s_knee * (1 - s_ank)
    J[:, 3] = ft;   W[:, 3] = s_top * s_knee * s_ank
    return J, W

def leg_tube(base, side, y_top, y_bot, pad, uv, nseg=14, over_boot=True, a_top=None):
    R = leg_rows(base, side); ry_ = R[::-1, 0]
    ys = np.append(np.arange(y_top, y_bot, -4.0), y_bot)
    if a_top is not None: ys = np.unique(np.concatenate([ys, [y_top - 2.0, y_top - 5.0]]))[::-1]
    ys = ys[ys >= y_bot - 1e-6]
    f = lambda c: np.interp(ys, ry_, R[::-1, c])
    cx, cz, rx, rz = f(1) * side, f(2), f(3), f(4)
    if a_top is not None:
        # haut de jambe rétréci pour épouser la taille du haut (pas de marche), élargi aux hanches sur ~8 cm
        t = sstep((y_top - ys) / 8.0)
        rx_t = rx * 0.82; rz_t = rz * 0.92
        cx_t = side * np.minimum(np.abs(cx), a_top - rx_t - pad)
        cx = cx_t + t * (cx - cx_t); rx = rx_t + t * (rx - rx_t); rz = rz_t + t * (rz - rz_t)
    bw = np.clip((35 - ys) / 4, 0, 1) if over_boot else np.zeros_like(ys)
    pe = pad + bw * max(0.0, 0.85 - pad)
    path = np.stack([cx, ys, cz], 1)
    pos, idx = loft(path, np.stack([rx + pe, rz + pe], 1), nseg, cap_start=True, cap_end=True)
    J, W = leg_weights(pos[:, 1], side)
    return solid_part(pos, idx, uv, J, W)

def skirt(prof, uv, length=62, flare=1.0):
    # démarre à y=92 (fin du haut) avec le même rayon que lui : plus de recouvrement 92-99
    ys = np.linspace(92, length, 10)
    a0 = np.interp(92, prof[:, 0], prof[:, 1]) + 0.8
    d0 = (np.interp(92, prof[:, 0], prof[:, 2]) - np.interp(92, prof[:, 0], prof[:, 3])) / 2 + 0.8
    zc0 = (np.interp(92, prof[:, 0], prof[:, 2]) + np.interp(92, prof[:, 0], prof[:, 3])) / 2
    a0 = max(a0, 17.0)   # hanches : la jupe doit couvrir le bassin
    rx = np.interp(ys, [length, 92], [a0 + 5.5 * flare, a0]); rz = np.interp(ys, [length, 92], [d0 + 6 * flare, d0])
    path = np.stack([np.full_like(ys, -0.2), ys, np.interp(ys, [length, 92], [1.5, zc0])], 1)
    pos, idx = loft(path, np.stack([rx, rz], 1), 24, cap_start=True)
    n = len(pos); J = np.zeros((n, 4), int); W = np.zeros((n, 4))
    t = np.clip((90 - pos[:, 1]) / 14, 0, 1) * 0.9
    J[:, 0] = HIPS; W[:, 0] = 1 - t
    J[:, 1] = np.where(pos[:, 0] >= 0, LUP, RUP); W[:, 1] = t
    return solid_part(pos, idx, uv, J, W)


def shoulder_clip(prof, caps=((118, 13.0), (122, 13.2), (126, 12.8), (130, 12.2), (134, 11.2), (138, 8.6))):
    """Pour les hauts à manches : le torse se resserre à hauteur d'épaule, c'est la manche (emmanchure) qui fait la ligne
    d'épaule -> plus d'intersection torse/manche presque à fleur (dents de scie)."""
    T = prof.copy(); cy = np.array([c[0] for c in caps]); cv = np.array([c[1] for c in caps])
    lim = np.interp(T[:, 0], cy, cv, left=1e9)
    T[:, 1] = np.minimum(T[:, 1], lim)
    return T
