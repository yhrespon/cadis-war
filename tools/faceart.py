"""Barbe peinte sur la texture du visage (masque analytique lissé évalué par pixel en 3D, bords nets, aucun volume).
Principe : on rastérise les positions 3D des triangles de la tête dans l'espace UV, puis on évalue pour chaque pixel
une fonction de forme (distance signée lissée) ; le résultat est mélangé dans l'atlas du personnage (copie propre)."""
import numpy as np, cv2

def uv_position_map(mesh, tri_sel, AW, AH):
    """(AH,AW,3) positions 3D interpolées dans l'espace UV de l'atlas + masque des pixels couverts."""
    uv = mesh['uv']; P = mesh['pos']
    px = np.stack([uv[:, 0] * 2048, (uv[:, 1] - 0.75) * 2048], 1)
    pm = np.zeros((AH, AW, 3), np.float32); ok = np.zeros((AH, AW), bool)
    for t in mesh['idx'][tri_sel]:
        a, b, c = px[t[0]], px[t[1]], px[t[2]]
        x0, x1 = int(np.floor(min(a[0], b[0], c[0]))), int(np.ceil(max(a[0], b[0], c[0])))
        y0, y1 = int(np.floor(min(a[1], b[1], c[1]))), int(np.ceil(max(a[1], b[1], c[1])))
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, AW - 1); y1 = min(y1, AH - 1)
        if x1 < x0 or y1 < y0: continue
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        l0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        l1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        l2 = 1 - l0 - l1; m = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not m.any(): continue
        pos = l0[..., None] * P[t[0]] + l1[..., None] * P[t[1]] + l2[..., None] * P[t[2]]
        sl = (slice(y0, y1 + 1), slice(x0, x1 + 1))
        pm[sl][m] = pos[m]; ok[sl] |= m
    return pm, ok

def sstep(t):
    t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)

def beard_alpha(p, kind='complete', xc=-0.2):
    """p : (...,3) positions (cm). Retourne alpha 0..1 (forme analytique lissée : menton arrondi, pattes qui montent vers l'oreille)."""
    x = np.abs(p[..., 0] - xc); y = p[..., 1]; z = p[..., 2]
    s = 0.45
    # joue : limite haute = ligne qui monte du coin de la bouche (x=4.2, y=145) vers la patte (x=8, y=150.5)
    cheek_top = 145.0 + np.clip(x - 4.2, 0, None) * 1.45
    cheek = sstep((cheek_top - y) / s + 0.5) * sstep((x - 3.4) / 0.8) * sstep((8.9 - x) / 0.9 + 0.5)
    # menton arrondi (sous la lèvre inférieure), plus étroit que la mâchoire
    chin_w = 6.4 - 0.18 * np.clip(143.8 - y, 0, None) ** 1.5 * 0.0
    chin = sstep((143.9 - y) / s + 0.5) * sstep((chin_w - x) / 1.3 + 0.5)
    a = np.maximum(cheek, chin)
    a *= sstep((y - 139.6) / 0.8)                                   # s'arrête au cou
    if kind == 'complete':
        yhi = 147.6 - 0.22 * x; ylo = 146.0 + 0.05 * x
        must = sstep((yhi - y) / 0.28 + 0.5) * sstep((y - ylo) / 0.28 + 0.5) * sstep((4.7 - x) / 0.9 + 0.5)
        must *= 1 - 0.85 * sstep((0.5 - x) / 0.25)                   # fente sous le nez
        a = np.maximum(a, must)
    a *= sstep((z - 0.8) / 2.5)                                      # devant / côtés seulement
    return np.clip(a, 0, 1)

def paint_beard(A, body, head_tri, hair_color, kind='complete', seed=3):
    pm, ok = uv_position_map(body, head_tri, A.color.shape[1], A.color.shape[0])
    al = beard_alpha(pm, kind) * ok
    # lèvres : jamais couvertes (dégagement net, texture d'origine conservée)
    x = np.abs(pm[..., 0] + 0.2); y = pm[..., 1]
    lips = (x < 3.9) & (y >= 143.7) & (y <= 146.0)
    if kind != 'complete': al[lips] = 0
    else: al[lips & (y < 146.0)] = 0
    rng = np.random.default_rng(seed)
    noise = cv2.GaussianBlur(rng.random(al.shape).astype(np.float32), (0, 0), 0.8)
    noise = (noise - noise.mean()) / (noise.std() + 1e-6)
    dens = np.clip(0.96 + 0.06 * noise, 0, 1)                       # grain de poils (pas de masse unie)
    al = np.clip(al * dens, 0, 1)
    al = cv2.GaussianBlur(al.astype(np.float32), (0, 0), 0.6)
    col = A.color.astype(np.float32); hc = np.array(hair_color, np.float32)
    lum = (col @ np.array([.299, .587, .114], np.float32)) / 150.0
    hair = hc[None, None] * np.clip(0.85 + 0.2 * lum, 0.6, 1.15)[..., None]
    A.color[:] = np.clip(col * (1 - al[..., None]) + hair * al[..., None], 0, 255).astype(np.uint8)
    return float(al.max())
