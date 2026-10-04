"""Réduction de maillage par effondrement d'arêtes (QEM, demi-arête a->b) pour maillages skinnés non soudés.
Sommets de couture (position dupliquée) et de bord : jamais supprimés -> UV / normales / poids conservés. Sans dépendance (numpy + heapq)."""
import heapq
import numpy as np

def _plane_quadrics(V, F):
    p0, p1, p2 = V[F[:, 0]], V[F[:, 1]], V[F[:, 2]]
    n = np.cross(p1 - p0, p2 - p0)
    area = np.linalg.norm(n, axis=1)
    ok = area > 1e-14
    n[ok] /= area[ok][:, None]
    d = -(n * p0).sum(1)
    P = np.concatenate([n, d[:, None]], 1)
    Qf = P[:, :, None] * P[:, None, :] * (area[:, None, None] * 0.5)
    Qf[~ok] = 0
    return Qf

def decimate(V, F, target_tris, protect=None, max_normal_dot=0.25):
    """V (n,3) float, F (m,3) int. protect : masque bool de sommets intouchables. Retourne (F_new, keep_vertex_mask_index_map).
    Les sommets ne sont jamais déplacés : F_new indexe le même tableau V (à compacter ensuite par l'appelant)."""
    V = V.astype(np.float64); F = F.copy()
    n = len(V)
    # sommets de couture : positions identiques
    key = np.round(V * 1e5).astype(np.int64)
    _, inv, cnt = np.unique(key, axis=0, return_inverse=True, return_counts=True)
    inv = inv.reshape(-1)
    locked = cnt[inv] > 1
    # bords : arêtes à une seule face
    e = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    es = np.sort(e, 1)
    ek = es[:, 0].astype(np.int64) * n + es[:, 1]
    u, c = np.unique(ek, return_counts=True)
    bnd = u[c == 1]
    locked[(bnd // n)] = True; locked[(bnd % n)] = True
    if protect is not None: locked |= protect
    Qf = _plane_quadrics(V, F)
    Q = np.zeros((n, 4, 4))
    for k in range(3): np.add.at(Q, F[:, k], Qf)
    alive = np.ones(len(F), bool)
    vfaces = [set() for _ in range(n)]
    for fi, f in enumerate(F):
        for v in f: vfaces[v].add(fi)
    ver = np.zeros(n, np.int64)
    Vh = np.concatenate([V, np.ones((n, 1))], 1)
    def cost(a, b):
        q = Q[a] + Q[b]; v = Vh[b]
        return float(v @ q @ v)
    heap = []
    def push_edges(a):
        nb = set()
        for fi in vfaces[a]:
            for v in F[fi]:
                if v != a: nb.add(int(v))
        for b in nb:
            if not locked[a]: heapq.heappush(heap, (cost(a, b), a, b, ver[a], ver[b]))
            if not locked[b]: heapq.heappush(heap, (cost(b, a), b, a, ver[b], ver[a]))
    seen = set()
    for f in F:
        for i in range(3):
            a, b = int(f[i]), int(f[(i + 1) % 3])
            if (a, b) in seen: continue
            seen.add((a, b)); seen.add((b, a))
            if not locked[a]: heapq.heappush(heap, (cost(a, b), a, b, 0, 0))
            if not locked[b]: heapq.heappush(heap, (cost(b, a), b, a, 0, 0))
    ntri = int(alive.sum())
    while ntri > target_tris and heap:
        c, a, b, va, vb = heapq.heappop(heap)
        if ver[a] != va or ver[b] != vb or locked[a]: continue
        fa = vfaces[a]
        if not fa: continue
        shared = [fi for fi in fa if b in F[fi]]
        if len(shared) != 2: continue
        # condition de lien : voisins communs == 2 sommets opposés
        na = {int(v) for fi in fa for v in F[fi]} - {a}
        nb = {int(v) for fi in vfaces[b] for v in F[fi]} - {b}
        opp = {int(v) for fi in shared for v in F[fi]} - {a, b}
        if (na & nb) != opp: continue
        # contrôle de retournement
        bad = False
        for fi in fa:
            if fi in shared: continue
            f = F[fi]
            p = [V[x] if x != a else V[b] for x in f]
            nn = np.cross(p[1] - p[0], p[2] - p[0]); ln = np.linalg.norm(nn)
            q = V[f]; no = np.cross(q[1] - q[0], q[2] - q[0]); lo = np.linalg.norm(no)
            if ln < 1e-12 or lo < 1e-12 or (nn @ no) / (ln * lo) < max_normal_dot: bad = True; break
        if bad: continue
        for fi in shared:
            alive[fi] = False; ntri -= 1
            for v in F[fi]: vfaces[v].discard(fi)
        for fi in list(fa):
            F[fi][F[fi] == a] = b; vfaces[b].add(fi)
        fa.clear()
        Q[b] += Q[a]; ver[a] += 1; ver[b] += 1
        push_edges(b)
    return F[alive]
