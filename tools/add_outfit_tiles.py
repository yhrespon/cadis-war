"""Ajoute au manifest.json, pour chaque personnage, les rectangles UV (pastilles de l'atlas) du haut, du bas, des chaussures et des cheveux.
Méthode : relit l'atlas embarqué dans chaque .glb, retrouve les pastilles 64x64 par couleur (appearance du manifest), puis
vérifie qu'au moins un sommet du maillage a son UV dans la pastille. Usage : python3 add_outfit_tiles.py"""
import json, struct, io, sys, numpy as np
from PIL import Image
from rig import read_acc
D = '../godot_project/characters/'
def load(p):
    d = open(p, 'rb').read(); jl, _ = struct.unpack('<II', d[12:20]); g = json.loads(d[20:20 + jl]); o = 20 + jl
    bl, _ = struct.unpack('<II', d[o:o + 8]); return g, d[o + 8:o + 8 + bl]
man = json.load(open(D + 'manifest.json')); rep = []
for c in man['characters']:
    g, b = load(D + c['file']); bv = g['bufferViews'][g['images'][0]['bufferView']]
    img = np.array(Image.open(io.BytesIO(b[bv['byteOffset']:][:bv['byteLength']])).convert('RGB')); H, W = img.shape[:2]
    uv = read_acc(g, b, g['meshes'][0]['primitives'][0]['attributes']['TEXCOORD_0']).astype(float)
    ap = c['appearance']; want = {'top': ap['top'][1], 'bottom': ap['bottom'][1], 'shoes': ap.get('shoes', [-1, -1, -1]), 'hair': ap['hair_color']}
    tiles = {}
    for i in range(32):
        x0 = 1280 + 64 * (i % 4); y0 = 64 * (i // 4)
        if y0 + 64 > H: break
        t = img[y0:y0 + 64, x0:x0 + 64].reshape(-1, 3)
        if (t == t[0]).all():
            for k, col in want.items():
                if tuple(int(v) for v in t[0]) == tuple(int(v) for v in col) and k not in tiles:
                    r = [(x0 + 2) / W, (y0 + 2) / H, (x0 + 62) / W, (y0 + 62) / H]
                    n = int(((uv[:, 0] >= r[0]) & (uv[:, 0] <= r[2]) & (uv[:, 1] >= r[1]) & (uv[:, 1] <= r[3])).sum())
                    tiles[k] = {'rect': [round(v, 5) for v in r], 'vertices': n}
    c['outfit_tiles'] = tiles; rep.append((c['id'], {k: v['vertices'] for k, v in tiles.items()}, [k for k in want if k not in tiles]))
json.dump(man, open(D + 'manifest.json', 'w'), indent=1, ensure_ascii=False)
for r in rep: print(r)
