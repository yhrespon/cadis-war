"""Fond animé de l'écran principal : boucle parfaite de 10 s (1280x720, 24 i/s, Theora .ogv) + affiche fixe .png.
Ville la nuit : étoiles scintillantes, nuages qui dérivent, projecteurs qui balaient, fenêtres qui s'allument/s'éteignent,
feux d'antennes, circulation (phares/feux arrière) sur chaussée mouillée aux reflets ondulants, halo de lune, et le titre
« C.A.D.I.S WARS » (or + reflet qui passe) incrusté dans l'image.

Usage : python3 tools/gen_menu_video.py            -> art/menu_bg.ogv + art/menu_bg.png (dure ~2-4 min)
        python3 tools/gen_menu_video.py --preview  -> seulement l'affiche + une planche de contrôle (/tmp/preview_sheet.png)
Nécessite : numpy, opencv, pillow, ffmpeg avec libtheora."""
import os
import sys
import subprocess
import time
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont

SW, SH = 2560, 1440            # résolution de construction (statique)
VW, VH = 1280, 720             # résolution de la vidéo
FPS, DUR = 24, 10
N = FPS * DUR
T = float(DUR)
F = np.float32
HORIZON = int(SH * 0.74)
HZ = HORIZON * VH // SH        # horizon en pixels vidéo
ROAD_TOP = HZ + 4
RH = VH - ROAD_TOP
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot_project', 'art')
FONTS = '/usr/share/fonts/truetype/google-fonts/'
FOG = np.array([0.40, 0.25, 0.42], F)
rng = np.random.default_rng(2026)


def lerp(a, b, t):
    return a + (b - a) * t


def down(a):
    return cv2.resize(a, (VW, VH), interpolation=cv2.INTER_AREA)


def smooth_noise(w, h, scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((h, w), F)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gw, gh = max(2, int(w / scale * (2 ** o))), max(2, int(h / scale * (2 ** o)))
        out += amp * cv2.resize(r.random((gh, gw)).astype(F), (w, h), interpolation=cv2.INTER_CUBIC)
        tot += amp
        amp *= 0.5
    return out / tot


def periodic_noise_x(P, h, octaves, seed):
    """Bruit de largeur P, périodique en x (P multiple de 8*2^octaves-1)."""
    r = np.random.default_rng(seed)
    out = np.zeros((h, P), F)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        gw = 8 * 2 ** o
        gh = max(2, int(h / (P / gw) * 0.9))
        grid = r.random((gh, gw)).astype(F)
        gp = np.pad(grid, ((0, 0), (2, 2)), mode='wrap')
        step = P // gw
        res = cv2.resize(gp, ((gw + 4) * step, h), interpolation=cv2.INTER_CUBIC)
        out += amp * res[:, 2 * step:2 * step + P]
        tot += amp
        amp *= 0.5
    return out / tot


# ================================================================ STATIQUE : ciel
t0 = time.time()
print('ciel…', flush=True)
top, mid, low, glow = (np.array(c, F) / 255 for c in ((5, 8, 26), (30, 24, 70), (118, 60, 98), (236, 128, 84)))
sky = np.zeros((SH, 1, 3), F)
for i in range(SH):
    tt = min(i / HORIZON, 1.0)
    if tt < 0.5:
        c = lerp(top, mid, (tt / 0.5) ** 0.9)
    elif tt < 0.85:
        c = lerp(mid, low, ((tt - 0.5) / 0.35) ** 1.1)
    else:
        c = lerp(low, glow, ((tt - 0.85) / 0.15) ** 1.4)
    sky[i, 0] = c
sky_s = np.repeat(sky, SW, axis=1)
xx = np.linspace(0, 1, SW, dtype=F)[None, :]
yy = np.linspace(0, 1, SH, dtype=F)[:, None]
d = np.sqrt(((xx - 0.5) * 1.3) ** 2 + ((yy - 0.74) * 2.4) ** 2)
sky_s += (np.exp(-(d / 0.30) ** 2) * 0.32)[..., None] * np.array([1.0, 0.45, 0.25], F)
sky_base = down(sky_s)
del sky_s

# étoiles : 4 groupes, chacun scintille avec sa propre phase
STAR_G = []
fade_s = np.clip(1 - np.arange(SH) / (HORIZON * 0.7), 0, 1)[:, None].astype(F) ** 1.2
for g in range(4):
    st = np.zeros((SH, SW), F)
    for _ in range(420):
        x, y = rng.integers(0, SW), rng.integers(0, int(HORIZON * 0.7))
        st[y, x] = rng.random() ** 3 * 0.9 + 0.1
    st = cv2.GaussianBlur(st, (0, 0), 1.1) * 6.0 * fade_s
    STAR_G.append(down(st[..., None].repeat(3, 2) * np.array([0.85, 0.9, 1.0], F)))
STAR_M = [1, 2, 1, 2]

# lune
MX, MY, MR = int(SW * 0.87), int(SH * 0.17), 84
dd = np.sqrt((np.arange(SW, dtype=F)[None, :] - MX) ** 2 + (np.arange(SH, dtype=F)[:, None] - MY) ** 2)
halo = np.exp(-(dd / (MR * 3.6)) ** 2) * 0.55 + np.exp(-(dd / (MR * 9)) ** 2) * 0.22
MOON_HALO = down(halo[..., None] * np.array([0.55, 0.62, 0.9], F))
disc = np.clip((MR - dd) / 2.5, 0, 1).astype(F)
tex = smooth_noise(SW, SH, 40, 4, seed=9)
moon_col = np.array([0.98, 0.96, 0.86], F)[None, None] * (0.86 + 0.14 * tex[..., None])
shade = np.clip(1.0 - 0.28 * ((np.arange(SW, dtype=F)[None, :] - MX) / MR + 0.5).clip(0, 1) * disc, 0, 1)
MOON_A = down(disc)[..., None]
MOON_C = down(moon_col * shade[..., None] * disc[..., None]) / np.maximum(MOON_A, 1e-4)
del dd, halo, disc, tex, moon_col, shade

# nuages (dérive horizontale, périodique : 320 px par boucle)
CP = 320
cl = periodic_noise_x(CP, VH, 4, seed=3)
cl = np.clip((cl - 0.5) * 3.2, 0, 1)
cl = np.tile(cl, (1, 6))
cl = cv2.GaussianBlur(cl, (0, 0), sigmaX=30, sigmaY=4.5)
band = np.exp(-((np.arange(VH) - HZ * 0.62) / (VH * 0.16)) ** 2)[:, None].astype(F)
CLOUD = cl * band * 0.55          # (VH, 6*CP)
CLOUD_COL = np.array([0.55, 0.32, 0.45], F) * 0.6

# projecteurs (calculés en 320x180 à chaque image)
BW, BH = VW // 4, VH // 4
bpx, bpy = np.meshgrid(np.arange(BW, dtype=F), np.arange(BH, dtype=F))
BEAMS = [(0.22, 10.0, 0.07, 0.0), (0.78, -10.0, 0.06, 0.5)]    # x, angle de base, ouverture, phase


def beams_at(t):
    out = np.zeros((BH, BW), F)
    oy = HORIZON / SH * BH + 3
    for bx, a0d, spread, ph in BEAMS:
        ox = bx * BW
        a0 = np.deg2rad(-90 + a0d + 11.0 * np.sin(2 * np.pi * (t / T + ph)))
        vx, vy = bpx - F(ox), bpy - F(oy)
        r = np.sqrt(vx ** 2 + vy ** 2) + 1e-3
        ang_d = np.arccos(np.clip((vx * F(np.cos(a0)) + vy * F(np.sin(a0))) / r, -1, 1))
        out += (np.exp(-(ang_d / spread) ** 2) * np.exp(-r / (BH * 0.95)) * (vy < 0)).astype(F)
    out = cv2.resize(out, (VW, VH), interpolation=cv2.INTER_LINEAR)
    return cv2.GaussianBlur(out, (0, 0), 2)[..., None] * np.array([0.30, 0.38, 0.55], F) * 0.55


# ================================================================ STATIQUE : immeubles (4 plans)
print('immeubles…', flush=True)
WIN_G = 4
WIN_M = [1, 2, 1, 3]
WIN_PH = [0.0, 0.25, 0.5, 0.75]
fb_y = (np.arange(VH, dtype=F) + 0.5) * SH / VH
FBMAP = (np.exp(-((fb_y - (HORIZON - 40)) / 260.0) ** 2) * 0.20).astype(F)[:, None, None]


def build_layer(depth, hmin, hmax, wmin, wmax, base_col, win_p, win_energy, seed):
    r = np.random.default_rng(seed)
    mask = np.zeros((SH, SW), F)
    layer = np.zeros((SH, SW, 3), F)
    wstat = np.zeros((SH, SW, 3), F)
    groups = [np.zeros((SH, SW, 3), F) for _ in range(WIN_G)]
    blinks = [np.zeros((SH, SW, 3), F) for _ in range(2)]
    x = -int(r.integers(0, 80))
    base_y = HORIZON + int(lerp(-6, 10, depth))
    while x < SW + 100:
        bw = int(r.integers(wmin, wmax))
        bh = int(r.integers(hmin, hmax) * (0.6 if abs(x / SW - 0.87) < 0.1 else 1.0))
        top_y = base_y - bh
        col = base_col * r.uniform(0.85, 1.15)
        cv2.rectangle(layer, (x, top_y), (x + bw, base_y), col.tolist(), -1)
        cv2.rectangle(mask, (x, top_y), (x + bw, base_y), 1.0, -1)
        if r.random() < 0.55:
            sw = int(bw * r.uniform(0.45, 0.8)); sh = int(bh * r.uniform(0.06, 0.16))
            sx = x + (bw - sw) // 2
            cv2.rectangle(layer, (sx, top_y - sh), (sx + sw, top_y), (col * 0.95).tolist(), -1)
            cv2.rectangle(mask, (sx, top_y - sh), (sx + sw, top_y), 1.0, -1)
            top_y2 = top_y - sh
        else:
            top_y2 = top_y
        if r.random() < 0.4:
            ax = x + int(bw * r.uniform(0.3, 0.7)); ah = int(r.integers(50, 150) * (0.6 + depth))
            lw = max(1, int(2 * depth + 1))
            cv2.line(layer, (ax, top_y2), (ax, top_y2 - ah), (col * 1.2).tolist(), lw)
            cv2.line(mask, (ax, top_y2), (ax, top_y2 - ah), 1.0, lw)
            cv2.circle(blinks[int(r.integers(0, 2))], (ax, top_y2 - ah), int(3 + 4 * depth), (1.0, 0.1, 0.08), -1)
        cell_w, cell_h = int(lerp(10, 22, depth)), int(lerp(14, 30, depth))
        pad_x, pad_y = int(cell_w * 0.28), int(cell_h * 0.3)
        for wy in range(top_y2 + cell_h, base_y - cell_h, cell_h):
            for wx in range(x + cell_w // 2, x + bw - cell_w, cell_w):
                if r.random() < win_p:
                    warm = r.random()
                    c = lerp(np.array([1.0, 0.78, 0.40], F), np.array([0.65, 0.82, 1.0], F), warm ** 2 * 0.8)
                    c = c * r.uniform(0.45, 1.0) * win_energy
                    tgt = groups[int(r.integers(0, WIN_G))] if r.random() < 0.26 else wstat
                    cv2.rectangle(tgt, (wx, wy), (wx + cell_w - pad_x, wy + cell_h - pad_y), c.tolist(), -1)
        x += bw + int(r.integers(0, int(14 + 24 * (1 - depth))))
    mk3 = mask[..., None]
    grad = np.clip(1 - (np.arange(SH, dtype=F)[:, None] - (HORIZON - 900)) / 900, 0, 1)[..., None]
    rim = np.clip(mask - np.roll(mask, 3, axis=0), 0, 1)[..., None]
    rim_col = np.array([0.55, 0.42, 0.65], F) * (0.35 + 0.35 * (1 - depth))
    lit = layer * (0.7 + 0.5 * (1 - grad)) + rim * rim_col
    fog_amt = lerp(0.62, 0.0, depth)
    hz = np.clip((np.arange(SH, dtype=F)[:, None] - (HORIZON - 700)) / 700, 0, 1)[..., None]
    lit = lit * (1 - fog_amt * (0.5 + 0.5 * hz)) + FOG * fog_amt * (0.5 + 0.5 * hz) * 0.9
    mk = down(mask)[..., None]
    sig = lerp(4, 7, depth)
    gk = lerp(0.35, 0.6, depth)
    D = dict(depth=depth, mk=mk, litm=down(lit * mk3))
    D['wstat_m'] = down(wstat) * mk
    D['glow_s'] = cv2.GaussianBlur(D['wstat_m'], (0, 0), sig) * gk
    D['groups'] = []
    for g in groups:
        gm = down(g) * mk
        D['groups'].append((gm + cv2.GaussianBlur(gm, (0, 0), sig) * gk).astype(np.float16))
    D['blinks'] = []
    for b in blinks:
        bb = down(b)
        D['blinks'].append((bb + cv2.GaussianBlur(bb, (0, 0), 5) * 2.0).astype(np.float16))
    return D


CFG = [
    (0.0, 110, 330, 90, 190, np.array([0.17, 0.12, 0.28], F), 0.10, 0.45, 11),
    (0.33, 150, 460, 110, 230, np.array([0.105, 0.085, 0.19], F), 0.14, 0.55, 12),
    (0.66, 190, 600, 130, 280, np.array([0.06, 0.055, 0.115], F), 0.16, 0.65, 13),
    (1.0, 200, 520, 170, 340, np.array([0.028, 0.03, 0.062], F), 0.18, 0.75, 14),
]
LAYERS = [build_layer(*c) for c in CFG]


def comp(base):
    city = base.copy()
    for L in LAYERS:
        city = city * (1 - L['mk']) + L['litm'] + L['wstat_m'] + L['glow_s']
        if L['depth'] < 0.66:
            city = city * (1 - FBMAP) + FOG * FBMAP
    return city


B = comp(np.zeros((VH, VW, 3), F))
A = (comp(np.ones((VH, VW, 3), F)) - B)[..., :1]
# fenêtres animées & feux clignotants : propagés à travers les plans devant eux
DYN = [np.zeros((VH, VW, 3), F) for _ in range(WIN_G)]
BLK = [np.zeros((VH, VW, 3), F) for _ in range(2)]
for k, L in enumerate(LAYERS):
    P = np.ones((VH, VW, 1), F)
    for j in range(k, len(LAYERS)):
        if j > k:
            P *= (1 - LAYERS[j]['mk'])
        if LAYERS[j]['depth'] < 0.66:
            P *= (1 - FBMAP)
    for g in range(WIN_G):
        DYN[g] += L['groups'][g].astype(F) * P
    for b in range(2):
        BLK[b] += L['blinks'][b].astype(F) * P
del LAYERS

# ================================================================ STATIQUE : avenue
print('avenue…', flush=True)
road_top_s = HORIZON + 8
VPX_S = int(SW * 0.5)
ry_s = ((np.arange(SH, dtype=F)[:, None] - road_top_s) / (SH - road_top_s))
extra = np.zeros((SH, SW, 3), F)
cv2.line(extra, (0, road_top_s), (SW, road_top_s), (0.30, 0.22, 0.38), 3)
for k in range(-4, 6):
    cv2.line(extra, (VPX_S, HORIZON), (VPX_S + k * 420, SH), (0.10, 0.09, 0.15), 3 if k % 2 else 5, cv2.LINE_AA)
pud = smooth_noise(SW, SH, 90, 4, seed=33)
pud = np.clip((pud - 0.60) * 6, 0, 1) * np.clip(ry_s, 0, 1) * (np.arange(SH)[:, None] > road_top_s)
pud = cv2.GaussianBlur(pud.astype(F), (0, 0), 3)
extra += pud[..., None] * np.array([0.22, 0.18, 0.32], F)
lights = np.zeros((SH, SW, 3), F)
for side in (-1, 1):
    for i in range(7):
        tt = (i / 7) ** 1.7
        x = VPX_S + side * lerp(260, 1500, tt)
        y = HORIZON - lerp(40, 340, tt)
        s = lerp(3, 12, tt)
        cv2.circle(lights, (int(x), int(y)), int(s), (1.0, 0.82, 0.52), -1, cv2.LINE_AA)
        cv2.line(lights, (int(x), int(y)), (int(x), int(HORIZON + lerp(2, 14, tt))), (0.10, 0.09, 0.16), max(1, int(s / 3)))
        for j in range(60):
            yy_ = int(HORIZON + 12 + j * lerp(1.5, 7, tt))
            if yy_ >= SH:
                break
            cv2.circle(lights, (int(x + rng.normal(0, 2 + tt * 5)), yy_), max(1, int(s * 0.45)),
                       tuple(float(v) for v in np.array((1.0, 0.7, 0.4)) * (1 - j / 60) * 0.5), -1)
extra += cv2.GaussianBlur(lights, (0, 0), 14) * 1.5 + lights * 0.8
EXTRA = down(extra)
del extra, lights, pud

ry = np.clip((np.arange(ROAD_TOP, VH, dtype=F)[:, None] - ROAD_TOP) / RH, 0, 1)
ROAD_BASE = (lerp(np.array([0.06, 0.05, 0.10], F), np.array([0.02, 0.02, 0.04], F), ry))[:, None, :]
FRES = np.clip(0.55 - 0.45 * ry, 0.08, 0.6)[..., None]
RIP1 = (smooth_noise(VW, RH, 12, 3, seed=21) - 0.5) * 18
RIP2 = (smooth_noise(VW, RH, 12, 3, seed=22) - 0.5) * 18
GX, GY = np.meshgrid(np.arange(VW, dtype=F), np.arange(RH, dtype=F))

# voitures : s(t) = (s0 + k t/T) mod 1  -> boucle parfaite
VPX = VW * 0.5
CARS = []
for _ in range(36):
    side = int(rng.choice([-1, 1]))
    CARS.append(dict(side=side, lane=float(rng.uniform(0.05, 1.0)), s0=float(rng.random()), k=int(rng.choice([1, 1, 2])),
                     tail=float(rng.uniform(0.05, 0.16)),
                     col=np.array((1.0, 0.12, 0.10)) if side > 0 else np.array((1.0, 0.92, 0.72))))


def trails_at(t):
    buf = np.zeros((VH, VW, 3), F)
    for c in CARS:
        s = (c['s0'] + c['k'] * t / T) % 1.0
        ang = VPX + c['side'] * c['lane'] * 850
        for q in range(14):
            ss = s - c['tail'] * q / 13
            if ss <= 0.01:
                break
            px = VPX + (ang - VPX) * ss
            py = (HZ + 3) + (VH - HZ - 3) * ss ** 1.35
            rad = max(1, int(0.5 + 3 * ss) - (1 if q > 3 else 0))
            col = c['col'] * (0.3 + 0.7 * ss) * (1 - 0.8 * q / 13)
            cv2.circle(buf, (int(px), int(py)), rad, col.tolist(), -1, cv2.LINE_AA)
    return buf


# ================================================================ TITRE
print('titre…', flush=True)


def tracked(draw, text, font, cx, cy, tracking):
    ws = [font.getlength(ch) for ch in text]
    total = sum(ws) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, w in zip(text, ws):
        draw.text((x, cy), ch, font=font, fill=255, anchor='lm')
        x += w + tracking
    return total


def build_title():
    cx = SW // 2
    m1 = Image.new('L', (SW, SH), 0)
    w1 = tracked(ImageDraw.Draw(m1), 'C.A.D.I.S', ImageFont.truetype(FONTS + 'Poppins-Bold.ttf', 236), cx, 250, 26)
    m2 = Image.new('L', (SW, SH), 0)
    w2 = tracked(ImageDraw.Draw(m2), 'WARS', ImageFont.truetype(FONTS + 'Poppins-Medium.ttf', 98), cx, 436, 62)
    gold = np.array(m1, F) / 255
    white = np.array(m2, F) / 255
    ys = np.nonzero(gold.max(1) > 0.5)[0]
    y0, y1 = ys.min(), ys.max()
    tg = np.clip((np.arange(SH, dtype=F) - y0) / max(1, y1 - y0), 0, 1)[:, None]
    stops_t = [0.0, 0.42, 0.52, 1.0]
    stops_c = np.array([(255, 246, 180), (255, 208, 72), (232, 164, 36), (150, 92, 16)], F) / 255
    grad = np.stack([np.interp(tg[:, 0], stops_t, stops_c[:, c]) for c in range(3)], 1)[:, None, :]
    streak = 0.93 + 0.07 * np.sin(np.arange(SW, dtype=F) * 0.018)[None, :, None]
    k7 = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    dil = cv2.dilate(gold, k7)
    outline = np.clip(dil - gold, 0, 1)
    hl = np.clip(gold - np.roll(gold, 6, axis=0), 0, 1)
    sh = np.clip(gold - np.roll(gold, -6, axis=0), 0, 1)
    rgb = grad * streak * gold[..., None]
    rgb = rgb * (1 - 0.45 * sh[..., None]) + hl[..., None] * np.array([1.0, 1.0, 0.9], F) * 0.55
    rgb += outline[..., None] * np.array([0.26, 0.15, 0.03], F)
    alpha = np.clip(np.maximum(dil, gold), 0, 1)
    # WARS : blanc légèrement bleuté, ombre portée douce
    wrgb = white[..., None] * np.array([0.96, 0.97, 1.0], F) * (0.9 + 0.1 * np.clip(1 - tg, 0, 1))[..., None]
    rgb = rgb * (1 - white[..., None]) + wrgb
    alpha = np.maximum(alpha, white)
    # filets dorés + losanges de part et d'autre de WARS
    ln = np.zeros((SH, SW), F)
    for sgn in (-1, 1):
        xa = cx + sgn * (w2 / 2 + 70)
        xb = cx + sgn * (w2 / 2 + 70 + 330)
        for xx_ in range(int(min(xa, xb)), int(max(xa, xb))):
            f = max(0.0, 1 - abs(xx_ - xa) / 330)
            ln[436 - 2:436 + 2, xx_] = np.maximum(ln[436 - 2:436 + 2, xx_], f ** 1.3)
        cv2.fillConvexPoly(ln, np.array([[xa - sgn * 4, 436], [xa - sgn * 4 + 12, 424], [xa - sgn * 4 + 24, 436], [xa - sgn * 4 + 12, 448]], np.int32) if sgn > 0 else
                           np.array([[xa + 4, 436], [xa + 4 - 12, 424], [xa + 4 - 24, 436], [xa + 4 - 12, 448]], np.int32), 1.0)
    rgb = rgb * (1 - ln[..., None]) + ln[..., None] * np.array([1.0, 0.82, 0.30], F)
    alpha = np.maximum(alpha, ln)
    pm = rgb * np.clip(alpha, 0, 1)[..., None] * 1.0
    return down(pm.astype(F)), down(alpha.astype(F))[..., None], down(gold + white)[..., None]


TITLE_PM, TITLE_A, TITLE_CORE = build_title()
TITLE_ROWS = 270
TA = TITLE_A[:, :, 0]
TITLE_SHADOW = cv2.GaussianBlur(TA, (0, 0), 14)[..., None]
TITLE_GLOW = cv2.GaussianBlur(TA, (0, 0), 9)[..., None] * np.array([1.0, 0.72, 0.25], F)
TITLE_GLOW2 = cv2.GaussianBlur(TA, (0, 0), 38)[..., None] * np.array([1.0, 0.6, 0.2], F)
SHX = np.arange(VW, dtype=F)[None, :]
SHY = np.arange(TITLE_ROWS, dtype=F)[:, None]

# ================================================================ IMAGE
VIG = (1 - 0.42 * np.clip((np.linspace(-1, 1, VW, dtype=F)[None, :] ** 2) * 0.55 + (np.linspace(-1, 1, VH, dtype=F)[:, None] ** 2) * 0.75, 0, 1) ** 1.2)[..., None]
FOGG = (np.exp(-((np.arange(VH, dtype=F)[:, None] - HZ) / 45.0) ** 2) * 0.28)[..., None]
FOGG_COL = np.array([0.42, 0.28, 0.46], F)
DITH = ((np.random.default_rng(5).random((VH, VW, 1)) - 0.5) * (1.5 / 255)).astype(F)
HY = np.arange(VH, dtype=F)[:, None]


def wave(m, ph, t, gain=1.5, off=0.5):
    return float(np.clip(off + gain * np.sin(2 * np.pi * (m * t / T + ph)), 0, 1))


def frame(t):
    # --- ciel animé
    img = sky_base.copy()
    for g in range(4):
        img += STAR_G[g] * F(0.55 + 0.45 * np.sin(2 * np.pi * (STAR_M[g] * t / T + g / 4.0)))
    sh = int(round(CP * (t / T)))
    ca = CLOUD[:, 160 + sh:160 + sh + VW, None]
    img = img * (1 - ca * 0.5) + ca * CLOUD_COL
    img += MOON_HALO * F(1.0 + 0.06 * np.sin(2 * np.pi * t / T))
    img = img * (1 - MOON_A) + MOON_C * MOON_A
    img += beams_at(t)
    # --- ville (affine en le ciel) + fenêtres/feux animés
    img = img * A + B
    for g in range(WIN_G):
        img += DYN[g] * wave(WIN_M[g], WIN_PH[g], t, 1.6, 0.45)
    for b in range(2):
        img += BLK[b] * wave(2, b * 0.5, t, 3.0, 0.15)
    # --- avenue : reflets ondulants de la ville
    src = img[ROAD_TOP - RH:ROAD_TOP][::-1]
    dx = (RIP1 * F(np.cos(2 * np.pi * t / T)) + RIP2 * F(np.sin(2 * np.pi * t / T))).astype(F)
    mir = cv2.remap(np.ascontiguousarray(src, dtype=F), (GX + dx).astype(F), GY, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REPLICATE)
    mir = cv2.GaussianBlur(mir, (0, 0), sigmaX=2.5, sigmaY=11)
    img[ROAD_TOP:] = ROAD_BASE + mir * FRES * 0.75
    img += EXTRA
    tr = trails_at(t)
    img += cv2.GaussianBlur(tr, (0, 0), 2.5) * 1.5 + tr * 0.7
    # --- bloom (demi-résolution)
    small = cv2.resize(img, (VW // 2, VH // 2), interpolation=cv2.INTER_AREA)
    br = np.clip(small - 0.62, 0, None)
    bl = cv2.GaussianBlur(br, (0, 0), 7) + cv2.GaussianBlur(br, (0, 0), 17.5) * 0.8
    img += cv2.resize(bl, (VW, VH), interpolation=cv2.INTER_LINEAR)
    img = img * (1 - FOGG) + FOGG_COL * FOGG
    # --- étalonnage
    img = np.clip(img, 0, 1.6)
    img = 1 - np.exp(-img * 1.35)
    img += (1 - np.clip(img.mean(2, keepdims=True) * 3, 0, 1)) * np.array([0.010, 0.012, 0.035], F)
    img = np.clip(img, 0, 1) ** 0.95
    img *= VIG
    # --- titre : ombre douce, halo doré qui respire, texte, reflet qui balaie une fois par boucle
    pulse = F(0.85 + 0.15 * np.sin(2 * np.pi * t / T))
    img *= 1 - 0.40 * TITLE_SHADOW
    img += (TITLE_GLOW * 0.35 + TITLE_GLOW2 * 0.22) * pulse
    tpm = TITLE_PM.copy()
    u = (t / T - 0.08) / 0.45
    if 0.0 <= u <= 1.0:
        pos = lerp(-120.0, VW + 120.0, u)
        band_ = np.exp(-(((SHX + F(0.9) * SHY) - F(pos)) / F(36.0)) ** 2).astype(F)[..., None]
        tpm[:TITLE_ROWS] += band_ * TITLE_CORE[:TITLE_ROWS] * np.array([1.0, 0.93, 0.75], F) * 0.9
    img = img * (1 - TITLE_A) + tpm
    img = np.clip(img + DITH, 0, 1)
    return img


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    print('statique prêt en %.0f s' % (time.time() - t0), flush=True)
    if '--preview' in sys.argv:
        ts = [0.0, 0.2, 0.35, 0.7]
        fr = [frame(x * T) for x in ts]
        t1 = time.time(); frame(1.0); print('1 image : %.2f s' % (time.time() - t1))
        cv2.imwrite('/tmp/preview_sheet.png', (np.vstack([np.hstack(fr[:2]), np.hstack(fr[2:])])[..., ::-1] * 255).astype(np.uint8))
        cv2.imwrite(os.path.join(OUT, 'menu_bg.png'), (frame(0.7 * T)[..., ::-1] * 255).astype(np.uint8))
        sys.exit(0)
    outp = os.path.join(OUT, 'menu_bg.ogv')
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (VW, VH), '-r', str(FPS),
           '-i', '-', '-an', '-c:v', 'libtheora', '-q:v', '7', '-g', '48', '-pix_fmt', 'yuv420p', outp]
    pr = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for i in range(N):
        pr.stdin.write((frame(i / FPS) * 255 + 0.5).astype(np.uint8).tobytes())
        if i % 24 == 0:
            print('image %d/%d' % (i, N), flush=True)
    pr.stdin.close()
    pr.wait()
    cv2.imwrite(os.path.join(OUT, 'menu_bg.png'), (frame(0.7 * T)[..., ::-1] * 255).astype(np.uint8))
    print('terminé : %s (%d Ko) en %.0f s' % (outp, os.path.getsize(outp) // 1024, time.time() - t0))
