"""Coques de crâne construites sur le profil MESURÉ de la tête de Body (cheveux, casquette), avec ligne de bord variable
(naissance des cheveux, tempes, nuque). Remplace les ellipsoïdes à rayons constants (qui laissaient percer le front)."""
import numpy as np
from geo import loft, solid_part, unit

XC = -0.2
#         y     demi-largeur  z avant  z arrière   (mesuré sur Body, hors nez et oreilles ; front = z du front)
_BASE = [
    [140.0, 4.0, 6.4, 2.1], [142.0, 4.8, 11.5, -1.0], [144.0, 5.6, 13.6, -1.7], [146.0, 6.6, 14.0, -2.3],
    [148.0, 7.4, 14.2, -3.6], [150.0, 7.8, 14.6, -4.8], [152.0, 8.0, 14.0, -5.3], [154.0, 8.1, 14.2, -5.3],
    [156.0, 7.7, 13.9, -5.0], [158.0, 7.0, 13.1, -4.5], [160.0, 6.0, 10.3, -2.8]]
# demi-largeur mesurée SANS les oreilles (elles dépassent à |x|~9) ; sommet : arrondi elliptique (au lieu d'un cône)
for _y in (161.0, 161.8, 162.3, 162.65, 162.9):
    _f = np.sqrt(max(1 - ((_y - 160.0) / 2.9) ** 2, 0.0))
    _BASE.append([_y, 6.0 * _f, 3.75 + 6.55 * _f, 3.75 - 6.55 * _f])
HEAD_TAB = np.array(_BASE)
Y_TOP = 162.9

def _tab(y):
    yy = HEAD_TAB[:, 0]
    a = np.interp(y, yy, HEAD_TAB[:, 1]); zf = np.interp(y, yy, HEAD_TAB[:, 2]); zb = np.interp(y, yy, HEAD_TAB[:, 3])
    return a, (zf + zb) / 2, (zf - zb) / 2

def edge_curve(front, side, back, dips=()):
    """hauteur du bord en fonction de l'angle phi (0 = devant, pi/2 = côté, pi = derrière).
    dips : ((phi_deg, profondeur, largeur_deg), ...) symétriques : pattes devant l'oreille, dégagement de l'oreille, nuque."""
    def f(phi):
        c = np.cos(phi)
        e = side + (front - side) * np.clip(c, 0, 1) ** 1.6 + (back - side) * np.clip(-c, 0, 1) ** 1.3
        ph = np.degrees(np.minimum(phi % (2 * np.pi), 2 * np.pi - phi % (2 * np.pi)))
        for deg, depth, w in dips: e = e - depth * np.exp(-((ph - deg) / w) ** 2)
        return e
    return f

def cap_shell(edge, offset=1.0, nu=22, nv=48, grow=0.0):
    """Coque sur le crâne : rangées de l'apex vers le bord edge(phi). offset = épaisseur ; grow = gonflement (afro)."""
    phis = np.linspace(0, 2 * np.pi, nv, endpoint=False)
    E = edge(phis)
    P = [np.array([XC, Y_TOP + 0.55 * offset, 2.9])]
    for i in range(1, nu + 1):
        t = (i / nu) ** 1.7
        for ph, e in zip(phis, E):
            y = (Y_TOP - 0.3) - t * ((Y_TOP - 0.3) - e)
            a, zc, rz = _tab(y)
            off = offset + grow * np.sin(np.pi * min(t * 1.4, 1.0)) ** 0.7
            P.append(np.array([XC + (a + off) * np.sin(ph), y, zc + (rz + off) * np.cos(ph)]))
    pos = np.array(P); tris = []
    for j in range(nv):                                   # éventail de l'apex
        tris.append((0, 1 + (j + 1) % nv, 1 + j))
    for i in range(nu - 1):
        for j in range(nv):
            a0 = 1 + i * nv + j; b0 = 1 + i * nv + (j + 1) % nv; c0 = a0 + nv; d0 = b0 + nv
            tris += [(a0, b0, c0), (b0, d0, c0)]
    idx = np.array(tris, int)
    # orientation vers l'extérieur
    ctr = np.array([XC, 152.0, 4.0]); tri = pos[idx]; fc = tri.mean(1); fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    flip = ((fc - ctr) * fn).sum(1) < 0; idx[flip] = idx[flip][:, [0, 2, 1]]
    return pos, idx

def back_curtain(y_top=151.0, y_bot=122.0, phi_span=(74, 286), off=1.2, nv=30, nu=14, wave=0.55, nstrip=15):
    """Cheveux longs : rideau derrière/à côté de la tête, ondulé (mèches), qui s'évase vers les épaules.
    Retourne une liste de bandes (pos, idx), une par mèche, pour pouvoir alterner deux nuances."""
    phis = np.radians(np.linspace(*phi_span, nv)); ys = np.linspace(y_top, y_bot, nu)
    P = []
    for y in ys:
        a, zc, rz = _tab(min(y, 150.0))
        k = np.clip((150.0 - y) / 26.0, 0, 1)
        for j, ph in enumerate(phis):
            w = wave * k * np.sin(j * 1.9 + y * 0.35) + 0.35 * k * np.sin(j * 4.1 - y * 0.2)     # mèches
            aa = a + off + 2.2 * k + w; rr = rz + off + 1.0 * k + w; z0 = zc - 1.6 * k
            # pointe des mèches : léger rétrécissement tout en bas
            tip = 1.0 - 0.10 * np.clip((y - y_bot) < 2.5, 0, 1) * 0
            P.append([XC + aa * np.sin(ph) * tip, y, z0 + rr * np.cos(ph)])
    pos = np.array(P)
    ctr = np.array([XC, 140.0, 3.0])
    strips = []
    cols = np.linspace(0, nv - 1, nstrip + 1).round().astype(int)
    for s in range(nstrip):
        j0, j1 = cols[s], cols[s + 1]; tris = []
        for i in range(nu - 1):
            for j in range(j0, j1):
                a0 = i * nv + j; b0 = a0 + 1; c0 = a0 + nv; d0 = c0 + 1
                tris += [(a0, b0, c0), (b0, d0, c0)]
        idx = np.array(tris, int)
        tri = pos[idx]; fc = tri.mean(1); fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        flip = ((fc - ctr) * fn).sum(1) < 0; idx[flip] = idx[flip][:, [0, 2, 1]]
        used = np.unique(idx); rm = -np.ones(len(pos), int); rm[used] = np.arange(len(used))
        strips.append((pos[used], rm[idx]))
    return strips

# dips : patte devant l'oreille (~62°), oreille dégagée (~92° : pas de dip), nuque effilée derrière l'oreille (~128°)
STYLE_DIPS = {
    'court': ((60, 3.4, 12), (128, 3.0, 18)), 'coupe': ((60, 2.4, 12), (128, 2.4, 18)), 'queue': ((60, 2.0, 12), (128, 1.5, 18)),
    'chignon': ((60, 1.6, 12), (128, 1.2, 18)), 'rase': ((60, 1.0, 10),), 'longs': (), 'afro': (), 'crete': ((60, 1.0, 10),),
}
STYLE_EDGES = {   # (devant, côtés, derrière) en y
    'rase':   (158.6, 154.8, 151.0), 'court': (156.2, 153.8, 148.0), 'coupe': (157.6, 152.8, 147.0),
    'afro':   (155.5, 150.0, 143.5), 'queue': (156.6, 153.0, 149.0), 'chignon': (156.4, 152.6, 148.5),
    'crete':  (158.6, 154.8, 151.0), 'longs': (156.0, 150.5, 146.0),
}
