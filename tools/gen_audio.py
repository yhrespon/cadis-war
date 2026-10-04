#!/usr/bin/env python3
"""Génère les effets sonores et musiques SYNTHÉTISÉS (numpy) dans godot_project/audio/.
Sons procéduraux d'origine libre (aucun échantillon tiers). Remplaçables par de vrais .ogg/.wav de même nom.
Usage : python3 tools/gen_audio.py"""
import numpy as np, struct, os
SR = 22050
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "godot_project", "audio")

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.002, dec=0.1):
    x = np.arange(n) / SR
    return np.minimum(1, x / a) * np.exp(-x / dec)
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def lp(x, k):  # passe-bas simple (moyenne glissante)
    k = max(1, int(k)); return np.convolve(x, np.ones(k) / k, mode="same")
def hp(x, k): return x - lp(x, k)
def sweep(d, f0, f1):
    tt = t(d); f = f0 * (f1 / f0) ** (tt / d); return np.sin(2 * np.pi * np.cumsum(f) / SR)
def tone(f, d, wave="sin"):
    ph = 2 * np.pi * f * t(d)
    if wave == "saw": return 2 * ((f * t(d)) % 1) - 1
    if wave == "sq": return np.sign(np.sin(ph))
    if wave == "tri": return 2 * np.abs(2 * ((f * t(d)) % 1) - 1) - 1
    return np.sin(ph)
def mix(n, parts):
    o = np.zeros(n)
    for off, x in parts:
        i = int(off * SR); m = min(len(x), n - i)
        if m > 0: o[i:i + m] += x[:m]
    return o

def write(name, x, loop=False, peak=0.85):
    x = np.asarray(x, dtype=np.float64); m = np.max(np.abs(x)) or 1
    pcm = (x / m * peak * 32767).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    body = b"fmt " + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(pcm)) + pcm
    if len(pcm) % 2: body += b"\0"
    if loop:  # bloc 'smpl' : boucle complète (lue par l'import WAV de Godot)
        n = len(x)
        sm = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0) + struct.pack("<IIIIII", 0, 0, 0, n - 1, 0, 0)
        body += b"smpl" + struct.pack("<I", len(sm)) + sm
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WAVE" + body)

def gun(d, dec, thump_f, bright, thump=0.9):
    n = int(SR * d); nz = noise(d) * env(n, 0.001, dec)
    nz = hp(nz, bright) if bright else nz
    return nz * 0.9 + sweep(d, thump_f, thump_f * 0.3) * env(n, 0.001, dec * 1.3) * thump

def click(f=2500, d=0.05): return hp(noise(d), 4) * env(int(SR * d), 0.0005, 0.012) * (1 + 0 * tone(f, d))

def main():
    os.makedirs(OUT, exist_ok=True)
    write("shot_pistol", gun(0.28, 0.07, 190, 0))
    write("shot_enemy", gun(0.28, 0.08, 150, 0) * 0.9)
    write("shot_smg", gun(0.16, 0.04, 220, 3))
    write("shot_shotgun", gun(0.6, 0.18, 110, 0, 1.2))
    n = int(SR * 0.9)
    write("reload", mix(n, [(0.0, click() * 0.7), (0.30, lp(noise(0.25), 3) * env(int(SR * .25), .01, .08) * 0.5), (0.55, click() * 1.0), (0.62, click(1800) * 0.6)]))
    nn = int(SR * 0.3); s = np.sin(np.pi * np.arange(nn) / nn) ** 2
    write("melee_swing", lp(noise(0.3), 6) * s * 0.9 + hp(noise(0.3), 12) * s * 0.2)
    write("melee_hit", sweep(0.22, 140, 45) * env(int(SR * .22), .001, .07) + lp(noise(0.22), 4) * env(int(SR * .22), .001, .04) * 0.8)
    write("impact_flesh", sweep(0.16, 120, 55) * env(int(SR * .16), .001, .05) + lp(noise(0.16), 5) * env(int(SR * .16), .001, .03) * 0.5)
    write("impact_world", hp(noise(0.12), 3) * env(int(SR * .12), .0005, .025) + tone(1700, 0.12) * env(int(SR * .12), .0005, .02) * 0.3)
    write("step", lp(noise(0.12), 12) * env(int(SR * .12), .004, .03) + sweep(0.12, 90, 60) * env(int(SR * .12), .002, .03) * 0.5)
    # moteur : harmoniques de 50 Hz => 1,0 s = 50 cycles entiers, boucle sans clic
    tt = t(1.0); e = sum(a * np.sin(2 * np.pi * 50 * h * tt + h) for h, a in [(1, 1), (2, .7), (3, .4), (4, .3), (6, .15)])
    write("engine_loop", e * (1 + 0.15 * np.sin(2 * np.pi * 5 * tt)), loop=True, peak=0.6)
    n = int(SR * 0.9)
    write("car_crash", lp(noise(0.9), 5) * env(n, .001, .22) + sweep(0.9, 110, 35) * env(n, .001, .25) + hp(noise(.9), 8) * env(n, .001, .05) * .6)
    h = (tone(440, 0.55, "sq") + tone(554, 0.55, "sq")) * 0.4 * np.minimum(1, np.minimum(t(.55) / .01, (.55 - t(.55)) / .05))
    write("car_horn", lp(h, 2))
    def blip(fs, d, wave="tri", dec=0.08):
        return np.concatenate([tone(f, d, wave) * env(int(SR * d), .003, dec) for f in fs])
    write("ui_move", blip([900], .05), peak=0.5)
    write("ui_select", blip([600, 900], .07), peak=0.6)
    write("ui_back", blip([500, 330], .07), peak=0.6)
    write("ui_buy", blip([1200, 1600], .12, "sin", .12), peak=0.6)
    write("ui_mission", blip([440, 554, 659, 880], .11, "tri", .1), peak=0.6)
    # musiques (boucles de mesures entières)
    def music(bpm, bars, chords, bass_pat, kick, hat, lead_scale, seed, vol_pad):
        r = np.random.default_rng(seed); beat = 60 / bpm; total = bars * 4 * beat; n = int(SR * total); o = np.zeros(n)
        def hz(m): return 440 * 2 ** ((m - 69) / 12)
        for b in range(bars):
            ch = chords[b % len(chords)]; t0 = b * 4 * beat
            for m in ch:   # nappe
                x = (tone(hz(m), 4 * beat, "saw") * 0.5 + tone(hz(m + .1), 4 * beat, "tri") * .5) * vol_pad
                x = lp(x, 3) * np.minimum(1, np.minimum(t(4 * beat) / .6, (4 * beat - t(4 * beat)) / .8))
                o += mix(n, [(t0, x)])
            for i, st in enumerate(bass_pat):  # basse
                if st: o += mix(n, [(t0 + i * beat / 2, tone(hz(ch[0] - 24), beat / 2, "sq") * env(int(SR * beat / 2), .004, .18) * .22)])
            for i in range(8):  # arpège / mélodie
                if r.random() < .7:
                    m = ch[0] + 12 + lead_scale[r.integers(len(lead_scale))]
                    o += mix(n, [(t0 + i * beat / 2, tone(hz(m), beat, "tri") * env(int(SR * beat), .005, .25) * .13)])
            for i in range(4 if kick else 0):
                o += mix(n, [(t0 + i * beat, sweep(.2, 120, 40) * env(int(SR * .2), .001, .09) * .7)])
            if hat:
                for i in range(8):
                    o += mix(n, [(t0 + i * beat / 2 + beat / 4 * 0, hp(noise(.05), 3) * env(int(SR * .05), .001, .015) * .18)])
        return o
    am = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    write("music_menu", music(84, 8, am, [1, 0, 0, 0, 1, 0, 0, 0], False, False, [0, 3, 7, 10, 12], 1, .35), loop=True, peak=.6)
    write("music_explore", music(100, 8, am, [1, 0, 1, 0, 1, 0, 1, 1], True, True, [0, 3, 5, 7, 10], 2, .25), loop=True, peak=.6)
    dm = [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]]
    write("music_combat", music(138, 8, dm, [1, 1, 1, 1, 1, 1, 1, 1], True, True, [0, 1, 3, 7, 8], 3, .22), loop=True, peak=.62)

    # --- v17 : ambiance (pluie, tonnerre) et sirène de police
    rn = noise(4.0)
    rain = hp(lp(rn, 2), 14) * 0.9 + lp(rn, 6) * 0.3
    write("rain_loop", rain, loop=True, peak=0.5)
    n = int(SR * 3.2)
    thunder = lp(noise(3.2), 40) * env(n, 0.02, 0.9) + sweep(3.2, 70, 28) * env(n, 0.02, 1.1) * 0.8 + lp(noise(3.2), 14) * env(n, 0.05, 0.4) * 0.5
    write("thunder", thunder, peak=0.8)
    ts = t(2.0)
    fs = 780 + 220 * np.sin(2 * np.pi * ts / 1.0 - np.pi / 2)
    siren = np.sign(np.sin(2 * np.pi * np.cumsum(fs) / SR)) * 0.25 + np.sin(2 * np.pi * np.cumsum(fs) / SR) * 0.6
    write("siren_loop", lp(siren, 2), loop=True, peak=0.5)
    write("police_whistle", tone(2900, 0.5) * (1 + 0.5 * np.sin(2 * np.pi * 38 * t(0.5))) * np.minimum(1, t(0.5) / 0.02) * np.exp(-t(0.5) / 0.5), peak=0.5)

if __name__ == "__main__":
    main()
