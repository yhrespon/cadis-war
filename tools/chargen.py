"""Génération de personnages variés à partir du modèle Fuse (atlas recoloré, vêtements/cheveux procéduraux, proportions)."""
import numpy as np, cv2
from PIL import Image
from rig import *
from geo import *
import body_parts as bp

HIPS, SPINE, SPINE1, SPINE2, NECK, HEAD = 1, 2, 3, 4, 5, 6
LUP, LLEG, LFOOT, RUP, RLEG, RFOOT = 24, 25, 26, 29, 30, 31
AW, AH = 1536, 512   # atlas final : 1280x512 recadré + 256 px de pastilles de couleurs

SKINS = {'clair': (232, 190, 165), 'beige': (214, 168, 134), 'mate': (190, 140, 105),
         'brun': (150, 98, 72), 'fonce': (98, 62, 46), 'ebene': (66, 42, 32)}

def colorize(img, mask, target, strength=1.0):
    m = mask > 0
    px = img[m].astype(np.float64)
    lum = px @ np.array([.299, .587, .114]); ref = max(lum.mean(), 1.0)
    out = np.clip(np.array(target, float)[None] * (lum / ref)[:, None], 0, 255)
    img[m] = (px * (1 - strength) + out * strength).astype(np.uint8)

def tone(img, mask, target):
    """Teinte de peau : pixels proches de la peau -> teinte cible complète ; lèvres, sourcils, ongles -> luminosité seule.
    Épaule douce (genou à 200) pour ne pas délaver les peaux claires."""
    m = mask > 0
    px = img[m].astype(np.float64)
    med = np.median(px, axis=0); d = np.linalg.norm(px - med, axis=1)
    sig = max(np.percentile(d, 70), 8.0)
    core = d < sig
    mean = px[core].mean(0)
    tgt = np.array(target, float)
    ratio = tgt / np.maximum(mean, 1)
    lum = np.array([.299, .587, .114])
    g = (tgt @ lum) / max(mean @ lum, 1)
    w = np.exp(-(d / (1.8 * sig)) ** 2)[:, None]
    out = w * px * ratio + (1 - w) * px * (g ** 0.6)
    out = np.where(out < 200, out, 200 + 55 * np.tanh((out - 200) / 55))
    img[m] = np.clip(out, 0, 255).astype(np.uint8)

class Atlas:
    def __init__(self, base):
        tex = np.array(base.tex)
        nrm = np.array(Image.open(f'{SRC}/textures/PackedMaterial0mat_normal.png').convert('RGB'))
        self.color = np.zeros((AH, AW, 3), np.uint8); self.alpha = np.full((AH, AW), 255, np.uint8)
        self.color[:, :1280] = cv2.resize(tex[3072:4096, :2560, :3], (1280, 512), interpolation=cv2.INTER_AREA)
        self.alpha[:, :1280] = cv2.resize(tex[3072:4096, :2560, 3], (1280, 512), interpolation=cv2.INTER_AREA)
        self.normal = np.zeros((AH, AW, 3), np.uint8); self.normal[:] = (128, 128, 255)
        self.normal[:, :1280] = cv2.resize(nrm[3072:4096, :2560], (1280, 512), interpolation=cv2.INTER_AREA)
        self.tiles = {}

    def mask(self, mesh):
        uv = mesh['uv']; pts = np.stack([uv[:, 0] * 2048, (uv[:, 1] - 0.75) * 2048], 1)[mesh['idx']]
        m = np.zeros((AH, AW), np.uint8); cv2.fillPoly(m, np.round(pts).astype(np.int32), 255); return m

    def swatch(self, color):
        key = tuple(int(c) for c in color)
        if key not in self.tiles:
            i = len(self.tiles); assert i < 32, 'trop de couleurs'
            x0 = 1280 + 64 * (i % 4); y0 = 64 * (i // 4)
            self.color[y0:y0 + 64, x0:x0 + 64] = key; self.tiles[key] = (x0 + 32, y0 + 32)
        x, y = self.tiles[key]; return np.array([x / AW, y / AH])

def remap_uv(uv):
    return np.stack([uv[:, 0] * 2048 / AW, (uv[:, 1] - 0.75) * 4], 1)

def dominant(m):
    return m['joints'][np.arange(len(m['pos'])), m['weights'].argmax(1)]

def sub_shell(mesh, sel, offset, uv_xy):
    faces = mesh['idx'][sel[mesh['idx']].all(1)]
    used = np.unique(faces); rm = -np.ones(len(mesh['pos']), int); rm[used] = np.arange(len(used))
    pos = mesh['pos'][used] + mesh['nrm'][used] * offset
    return dict(pos=pos, nrm=mesh['nrm'][used].copy(), uv=np.tile(uv_xy, (len(used), 1)),
                joints=mesh['joints'][used].copy(), weights=mesh['weights'][used].copy(), idx=rm[faces])

def leg_weights(y, side):
    up, lg, ft = (LUP, LLEG, LFOOT) if side > 0 else (RUP, RLEG, RFOOT)
    n = len(y); J = np.zeros((n, 4), int); W = np.zeros((n, 4))
    def blend(a, b, t): return a, b, t
    for i, yy in enumerate(y):
        if yy >= 90: j = [(HIPS, 1.0)]
        elif yy >= 80: t = (90 - yy) / 10; j = [(HIPS, 1 - t), (up, t)]
        elif yy >= 47: j = [(up, 1.0)]
        elif yy >= 36: t = (47 - yy) / 11; j = [(up, 1 - t), (lg, t)]
        elif yy >= 14: j = [(lg, 1.0)]
        elif yy >= 6: t = (14 - yy) / 8; j = [(lg, 1 - t), (ft, t)]
        else: j = [(ft, 1.0)]
        for k, (jj, ww) in enumerate(j): J[i, k] = jj; W[i, k] = ww
    return J, W

def spine_weights(pos, top_joint=HEAD):
    n = len(pos); J = np.zeros((n, 4), int); W = np.zeros((n, 4)); J[:, 0] = top_joint; W[:, 0] = 1; return J, W

def leg_tube(side, y_top, y_bot, pad, color_uv, nseg=14):
    s = 1 if side > 0 else -1
    P = np.array([(10.0, 92, -0.8), (10.4, 78, -1.4), (9.6, 60, -2.0), (9.2, 48, -2.4), (9.2, 41.6, -2.5), (9.4, 30, -2.4), (9.9, 18, -2.2), (10.2, 9, -2.1)])
    R = np.array([(8.4, 8.8), (8.0, 8.2), (6.8, 7.2), (6.0, 6.4), (5.6, 5.9), (5.2, 5.4), (4.6, 4.8), (4.3, 4.5)])
    # rééchantillonner entre y_top et y_bot
    ys = np.linspace(y_top, y_bot, 12)
    path = np.stack([np.interp(ys[::-1], P[::-1, 1], P[::-1, 0]) * s, ys,
                     np.interp(ys[::-1], P[::-1, 1], P[::-1, 2])[::-1] if False else np.interp(ys, P[::-1, 1], P[::-1, 2])], 1)
    path[:, 0] = np.interp(ys, P[::-1, 1], P[::-1, 0]) * s
    rad = np.stack([np.interp(ys, P[::-1, 1], R[::-1, 0]) + pad, np.interp(ys, P[::-1, 1], R[::-1, 1]) + pad], 1)
    pos, idx = loft(path, rad, nseg)
    ring_y = np.repeat(ys, nseg)
    ring_y = np.concatenate([ring_y, np.zeros(len(pos) - len(ring_y))])
    J, W = leg_weights(pos[:, 1], side)
    return solid_part(pos, idx, color_uv, J, W)

def pelvis(color_uv, pad=0.5):
    path = np.array([(0, 99.5, 1.5), (0, 94, 1.5), (0, 88, 1.5), (0, 82, 1.5)])
    rad = np.array([(12.2, 9.2), (13.0, 9.8), (14.0, 10.4), (14.2, 10.4)]) + pad
    pos, idx = loft(path, rad, 20)
    J = np.zeros((len(pos), 4), int); W = np.zeros((len(pos), 4)); J[:, 0] = HIPS; W[:, 0] = 1
    return solid_part(pos, idx, color_uv, J, W)

def skirt(color_uv, length=62, flare=1.0):
    ys = np.linspace(99, length, 10)
    rx = np.interp(ys, [length, 99], [13.5 + 7 * flare, 12.4]); rz = np.interp(ys, [length, 99], [11 + 6 * flare, 9.4])
    path = np.stack([np.zeros_like(ys), ys, np.full_like(ys, 1.5)], 1)
    pos, idx = loft(path, np.stack([rx, rz], 1), 22)
    J = np.zeros((len(pos), 4), int); W = np.zeros((len(pos), 4))
    for i, p in enumerate(pos):
        y = p[1]; t = np.clip((90 - y) / 14, 0, 1)
        side = LUP if p[0] >= 0 else RUP
        J[i, 0] = HIPS; J[i, 1] = side; W[i, 0] = 1 - t * 0.9; W[i, 1] = t * 0.9
        # léger poids ressort jambe pour jupes courtes
    return solid_part(pos, idx, color_uv, J, W)

def make_hair(style, uv_xy, uv_alt=None):
    import headshell as hs
    parts = []
    def add(pos, idx, J=None, W=None):
        if J is None:
            J = np.zeros((len(pos), 4), int); W = np.zeros((len(pos), 4)); J[:, 0] = HEAD; W[:, 0] = 1
        parts.append(solid_part(pos, idx, uv_xy, J, W))
    if style == 'chauve': return []
    E = hs.edge_curve(*hs.STYLE_EDGES[style], dips=hs.STYLE_DIPS.get(style, ()))
    if style == 'rase':     add(*hs.cap_shell(E, 0.5))
    elif style == 'court':  add(*hs.cap_shell(E, 1.0))
    elif style == 'coupe':  add(*hs.cap_shell(E, 1.9, grow=0.8))
    elif style == 'afro':
        # vraie boule de cheveux : dôme centré sur le crâne, plus haut et plus large que la tête, bord = naissance/oreilles/nuque
        nu_, nv_ = 22, 40
        pos, idx = dome((hs.XC, 154.0, 2.6), (9.0, 9.0, 9.4), offset=3.6, lim=(76, 94, 122), nu=nu_, nv=nv_)
        for r_, f_ in enumerate((0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.01, 0.03, 0.06, 0.10, 0.15, 0.22)):
            sl = slice(r_ * nv_, (r_ + 1) * nv_)      # bord arrondi vers l'intérieur : plus de coupe nette en « casque »
            pos[sl, 0] = hs.XC + (pos[sl, 0] - hs.XC) * (1 - f_); pos[sl, 2] = 2.6 + (pos[sl, 2] - 2.6) * (1 - f_)
        add(pos, idx)
    elif style == 'longs':
        add(*hs.cap_shell(E, 1.3))
        for k, (pos, idx) in enumerate(hs.back_curtain()):
            J = np.zeros((len(pos), 4), int); W = np.zeros((len(pos), 4))
            t = np.clip((pos[:, 1] - 134) / 10, 0, 1); J[:, 0] = HEAD; J[:, 1] = SPINE2; W[:, 0] = t; W[:, 1] = 1 - t
            parts.append(solid_part(pos, idx, uv_alt if (uv_alt is not None and k in (2, 5, 6, 9, 12)) else uv_xy, J, W))
    elif style == 'queue':
        add(*hs.cap_shell(E, 1.0))
        path = np.array([(-0.2, 158.0, -6.4), (-0.2, 153.0, -10.0), (-0.2, 145.0, -11.2), (-0.2, 136.0, -10.6)]); rad = np.array([(2.6, 2.6), (3.0, 3.0), (2.4, 2.4), (1.2, 1.2)])
        pos, idx = loft(path, rad, 10, cap_end=True); add(pos, idx)
    elif style == 'chignon':
        add(*hs.cap_shell(E, 1.0))
        path = np.array([(-0.2, 160.0, -1.0), (-0.2, 164.2, -2.2), (-0.2, 168.2, -2.6), (-0.2, 170.8, -2.6)]); rad = np.array([(3.2, 3.2), (4.8, 4.8), (4.4, 4.4), (1.5, 1.5)])
        pos, idx = loft(path, rad, 14, cap_start=True, cap_end=True); add(pos, idx)
    elif style == 'crete':
        add(*hs.cap_shell(E, 0.5))
        path = np.array([(-0.2, 150.0, -7.0), (-0.2, 155.0, -6.9), (-0.2, 160.0, -5.4), (-0.2, 164.6, -1.0), (-0.2, 165.8, 3.5), (-0.2, 164.8, 8.0), (-0.2, 161.5, 12.4), (-0.2, 157.0, 15.2)])
        rad = np.array([(1.3, 2.4), (1.3, 2.8), (1.3, 3.0), (1.3, 3.0), (1.3, 3.0), (1.3, 3.0), (1.3, 2.6), (1.3, 1.8)])
        pos, idx = loft(path, rad, 8, cap_start=True, cap_end=True); add(pos, idx)
    return parts

def cap_parts(color_uv, kind='casquette', color2_uv=None):
    """Casquette : couronne sur le crâne mesuré (bord au-dessus des oreilles), visière incurvée épaisse (2e couleur), bouton."""
    import headshell as hs
    out = []
    def head(p, i, uv):
        J = np.zeros((len(p), 4), int); W = np.zeros((len(p), 4)); J[:, 0] = HEAD; W[:, 0] = 1
        out.append(solid_part(p, i, uv, J, W))
    c2 = color_uv if color2_uv is None else color2_uv
    head(*hs.cap_shell(hs.edge_curve(153.6, 153.0, 150.0, dips=((70, 0.8, 14),)), 1.3, grow=0.4), color_uv)
    # bandeau intérieur sombre visible au bord (épaisseur de couture)
    if kind == 'casquette':
        head(*sector_brim(np.array([-0.2, 0, 0]), 153.9, 4.4, 10.6, 21.0, 60, 15, thick=0.8, drop=3.4), c2)
    p, i = loft(np.array([(-0.2, 163.2, 2.9), (-0.2, 164.2, 2.9)]), np.array([(1.1, 1.1), (0.8, 0.8)]), 10, cap_start=True, cap_end=True); head(p, i, c2)
    return out

def compact(m):
    """supprime les sommets inutilisés (en place)"""
    used = np.unique(m['idx']); rm = -np.ones(len(m['pos']), int); rm[used] = np.arange(len(used))
    for k in ('pos', 'nrm', 'uv', 'joints', 'weights'): m[k] = m[k][used]
    m['idx'] = rm[m['idx']]

def build(base, spec):
    A = Atlas(base)
    M = [dict(name=m['name'], pos=m['pos'].copy(), nrm=m['nrm'].copy(), uv=m['uv'].copy(), joints=m['joints'].copy(),
              weights=m['weights'].copy(), idx=m['idx'].copy()) for m in base.meshes]
    names = {m['name']: k for k, m in enumerate(M)}
    masks = {n: A.mask(M[k]) for n, k in names.items()}
    gender = spec.get('gender', 'f')
    # --- couleurs des pièces d'origine ---
    skin = SKINS[spec['skin']] if isinstance(spec['skin'], str) else spec['skin']
    tone(A.color, masks['Body'], skin)
    orig = spec.get('orig', {})
    if 'Tops' in orig: colorize(A.color, masks['Tops'], orig['Tops'], 0.9)
    if 'Bottoms' in orig: colorize(A.color, masks['Bottoms'], orig['Bottoms'], 0.85)
    colorize(A.color, masks['Shoes'], spec.get('shoes', (40, 40, 44)), 0.85)
    colorize(A.color, masks['Gloves'], spec.get('gloves_color', (30, 30, 30)), 0.9)
    colorize(A.color, masks['Hair'], spec.get('hair_color', (60, 40, 25)), 1.0)
    body = M[names['Body']]
    dom = dominant(body); P = body['pos'].copy()
    # --- le torse creux de Body est supprimé, remplacé par un loft (peau) ---
    torso_v = np.isin(dom, [HIPS, SPINE, SPINE1, SPINE2]) & (P[:, 1] < 139.0)
    body['idx'] = body['idx'][~torso_v[body['idx']].any(1)]
    # moignons de jambes de Body (y 21-36, le reste de la jambe n'existe pas dans le modèle) : remplacés par les tubes
    # procéduraux dès qu'on n'utilise pas le pantalon d'origine -> plus de peau qui perce sous le jean
    if spec.get('bottom', ('orig', None))[0] != 'orig':
        leg_v = np.isin(dom, [LUP, LLEG, LFOOT, RUP, RLEG, RFOOT]) & (P[:, 1] < 40.0)
        body['idx'] = body['idx'][~leg_v[body['idx']].any(1)]
    # bras d'origine recouverts par une manche procédurale : retirés jusqu'à 1 cm sous le bord de la manche
    # (supprime les éclats de peau qui perçaient à l'épaule / à l'aisselle ; la manche cache le raccord)
    sleeve_end = {'tshirt': 33, 'manches': 56, 'veste': 57}.get(spec.get('top', ('orig', None))[0])
    if sleeve_end:
        arm_v = np.isin(dom, [bp.LSH, bp.LARM, bp.LFA, bp.RSH, bp.RARM, bp.RFA]) & (np.abs(P[:, 0] + 0.2) < sleeve_end - 1.0) & (np.abs(P[:, 0]) > 9.0)
        body['idx'] = body['idx'][~arm_v[body['idx']].all(1)]
    compact(body)
    dom = dominant(body); P = body['pos']
    prof = bp.torso_profile(gender)
    sk = A.swatch(skin)
    parts = [M[names[n]] for n in ('Eyelashes', 'default', 'Body')]
    has_sleeves = spec.get('top', ('orig', None))[0] in ('tshirt', 'manches', 'veste')
    prof_c = bp.shoulder_clip(prof) if has_sleeves else prof      # profil du torse sous manches
    parts.append(bp.torso_loft(prof_c, 140, 88, 0.0, sk))
    for s in (1, -1): parts.append(bp.wrist(base, s, sk))
    # --- haut ---
    top, tcol = spec.get('top', ('orig', None))
    if top == 'orig': parts.append(M[names['Tops']])
    elif top != 'none':
        uvc = A.swatch(tcol)
        if top == 'debardeur':   parts.append(bp.torso_loft(prof, 139, 92, 0.8, uvc))
        elif top == 'tshirt':
            parts.append(bp.torso_loft(prof_c, 139, 92, 0.8, uvc))
            parts += [bp.sleeve(base, s, 33, 0.8, uvc) for s in (1, -1)]
        elif top == 'manches':
            parts.append(bp.torso_loft(prof_c, 139, 92, 0.8, uvc))
            parts += [bp.sleeve(base, s, 56, 0.8, uvc) for s in (1, -1)]
        elif top == 'veste':
            parts.append(bp.torso_loft(prof_c, 139.5, 92, 1.4, uvc))   # ourlet à 92 comme les autres hauts (v5c : plus de bord dentelé)
            parts += [bp.sleeve(base, s, 57, 1.4, uvc) for s in (1, -1)]
    # --- bas ---
    bot, bcol = spec.get('bottom', ('orig', None))
    if bot == 'orig': parts.append(M[names['Bottoms']])
    else:
        uvb = A.swatch(bcol)
        parts.append(bp.pelvis(prof, uvb, 0.7))
        a92 = float(np.interp(92, prof[:, 0], prof[:, 1])) + 0.8
        L = lambda s, yt, yb, pad, uv, ob=True: bp.leg_tube(base, s, yt, yb, pad, uv, over_boot=ob, a_top=a92 if yt >= 88 else None)
        if bot == 'jean':      parts += [L(s, 91, 23, 0.7, uvb) for s in (1, -1)]
        elif bot == 'cargo':   parts += [L(s, 91, 23, 1.6, uvb) for s in (1, -1)]
        elif bot == 'short':
            parts += [L(s, 91, 56, 0.9, uvb) for s in (1, -1)]
            parts += [L(s, 58, 16, 0.0, sk, False) for s in (1, -1)]
        elif bot == 'jupe':
            parts += [bp.skirt(prof, uvb, 64)] + [L(s, 68, 16, 0.0, sk, False) for s in (1, -1)]
        elif bot == 'jupe_longue':
            parts += [bp.skirt(prof, uvb, 36, 0.8)] + [L(s, 40, 16, 0.0, sk, False) for s in (1, -1)]
        # jambes nues sous short/jupe : aussi sous 'jean' pas nécessaire (couvertes)
    parts.append(M[names['Shoes']])
    if spec.get('gloves'): parts.append(M[names['Gloves']])
    if spec.get('hair') == 'orig': parts.append(M[names['Hair']])
    # --- cheveux / barbe / couvre-chef ---
    hc = spec.get('hair_color', (60, 40, 25))
    if spec.get('hair', 'chauve') not in ('orig', 'chauve'):
        hc_alt = tuple(int(min(255, v * 1.2 + 5)) for v in hc)
        parts += make_hair(spec['hair'], A.swatch(hc), A.swatch(hc_alt))
    if spec.get('hat'):
        hk, hcol = spec['hat'][:2]; hc2 = spec['hat'][2] if len(spec['hat']) > 2 else tuple(int(v * 0.45) for v in hcol)
        parts += cap_parts(A.swatch(hcol), hk, A.swatch(hc2))
    if spec.get('beard'):
        # barbe peinte sur la texture du visage (voir faceart.py) : pas de volume, bords lissés
        import faceart
        hd_tri = (dom[body['idx']] == HEAD).all(1)
        faceart.paint_beard(A, body, hd_tri, hc, spec['beard'])
    return A, parts, M, names

def finalize(base, A, parts, M, names, spec):
    for m in M:   # remap uv des pièces d'origine (identifiées par identité d'objet)
        pass
    out = []
    origs = {id(m) for m in M}
    for p in parts:
        q = dict(p)
        if id(p) in origs: q['uv'] = remap_uv(p['uv'])
        out.append(q)
    mesh = merge(out)
    # --- proportions ---
    sx, sy, sz, hs = spec.get('build', (1, 1, 1, 1.0))
    Wp = base.Wp.copy(); piv = Wp[NECK].copy()
    P = mesh['pos']
    wh = np.where(np.isin(mesh['joints'], [HEAD, 7]), mesh['weights'], 0).sum(1)
    P = P + wh[:, None] * ((piv + hs * (P - piv)) - P)
    for j in (HEAD, 7): Wp[j] = piv + hs * (Wp[j] - piv)
    S = np.array([sx, sy, sz]); P = P * S; Wp = Wp * S
    mesh['pos'] = P * 0.01; Wp = Wp * 0.01
    mesh['nrm'] = calc_normals(mesh['pos'], mesh['idx']) if False else unit(mesh['nrm'] / S)
    return mesh, Wp
