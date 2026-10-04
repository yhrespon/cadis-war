#!/usr/bin/env python3
"""Vérifie un GLB de personnage (structure + rendu logiciel d'une pose d'animation, sans Godot).
Usage : verify_new_glb.py <glb> <sortie.png> [anim=idle] [t=0] [vue=front|side|hand]"""
import sys, os, math, io
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fbx2glb import read_glb, read_acc, quat_to_mat, qmul

def comp(j, b, i, dt, n):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    return np.frombuffer(b, dtype=dt, count=a['count'] * n, offset=bv.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], n)

def sample(times, vals, t, quat):
    t = min(max(t, times[0]), times[-1])
    k = int(np.searchsorted(times, t, side='right') - 1); k = min(max(k, 0), len(times) - 2)
    u = (t - times[k]) / max(times[k + 1] - times[k], 1e-9)
    a, b = vals[k], vals[k + 1]
    if quat:
        if (a * b).sum() < 0: b = -b
        q = a * (1 - u) + b * u; return q / np.linalg.norm(q)
    return a * (1 - u) + b * u

def posed(j, b, anim, t):
    nodes = j['nodes']; par = {c: p for p, n in enumerate(nodes) for c in n.get('children', [])}
    T = [np.array(n.get('translation', [0, 0, 0]), float) for n in nodes]; Q = [np.array(n.get('rotation', [0, 0, 0, 1]), float) for n in nodes]
    if anim:
        a = [x for x in j['animations'] if x['name'] == anim][0]
        for c in a['channels']:
            s = a['samplers'][c['sampler']]; tm = read_acc(j, b, s['input'])[:, 0]; v = read_acc(j, b, s['output'])
            k = c['target']['node']
            if c['target']['path'] == 'rotation': Q[k] = sample(tm, v, t, True)
            else: T[k] = sample(tm, v, t, False)
    Gm = {}
    def g(i):
        if i in Gm: return Gm[i]
        L = np.eye(4); L[:3, :3] = quat_to_mat(Q[i]); L[:3, 3] = T[i]
        Gm[i] = (g(par[i]) if i in par else np.eye(4)) @ L; return Gm[i]
    return g

def skinned(j, b, g):
    sk = j['skins'][0]; ibm = read_acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
    M = np.stack([g(n) @ ibm[k] for k, n in enumerate(sk['joints'])])
    tris = []; cols = []
    imgs = {}
    def tex_img(mi):
        mat = j['materials'][mi]; bt = mat['pbrMetallicRoughness'].get('baseColorTexture')
        if bt is None: return None
        if mi not in imgs:
            im = j['images'][j['textures'][bt['index']]['source']]; bv = j['bufferViews'][im['bufferView']]
            imgs[mi] = np.array(Image.open(io.BytesIO(b[bv['byteOffset']:bv['byteOffset'] + bv['byteLength']])).convert('RGBA'))
        return imgs[mi]
    for p in j['meshes'][0]['primitives']:
        at = p['attributes']; P = read_acc(j, b, at['POSITION']); UV = read_acc(j, b, at['TEXCOORD_0'])
        J = comp(j, b, at['JOINTS_0'], '<u2', 4).astype(int); W = read_acc(j, b, at['WEIGHTS_0'])
        Ph = np.concatenate([P, np.ones((len(P), 1))], 1)
        out = np.zeros((len(P), 3))
        for k in range(4): out += W[:, k:k + 1] * np.einsum('nij,nj->ni', M[J[:, k]], Ph)[:, :3]
        idx = comp(j, b, p['indices'], '<u4', 1).reshape(-1, 3)
        im = tex_img(p['material'])
        for f in idx:
            if im is not None:
                uv = UV[f].mean(0); h, w = im.shape[:2]
                c = im[int(np.clip((uv[1] % 1) * h, 0, h - 1)), int(np.clip((uv[0] % 1) * w, 0, w - 1))]
                if c[3] < 128: continue
                cols.append(tuple(int(x) for x in c[:3]))
            else: cols.append((90, 90, 90))
            tris.append(out[f])
    return np.array(tris), cols

def render(tris, cols, path, view, size=700):
    pts = tris.reshape(-1, 3)
    if view == 'side': pts2 = np.stack([pts[:, 2], pts[:, 1]], 1); dep = tris[:, :, 0].mean(1)
    else: pts2 = np.stack([-pts[:, 0], pts[:, 1]], 1); dep = -tris[:, :, 2].mean(1)
    lo = pts2.min(0); hi = pts2.max(0); sc = (size - 40) / max(hi[1] - lo[1], 1e-6)
    xy = ((pts2 - lo) * sc + 20); xy[:, 1] = size - xy[:, 1]
    xy = xy.reshape(-1, 3, 2)
    n = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]); n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    light = np.clip(0.55 + 0.45 * (n @ np.array([0.3, 0.5, 0.8])), 0.3, 1.0)
    im = Image.new('RGB', (size, size), (205, 210, 215)); d = ImageDraw.Draw(im)
    for k in np.argsort(dep)[::-1]:
        c = tuple(int(x * light[k]) for x in cols[k]); d.polygon([tuple(p) for p in xy[k]], fill=c)
    im.save(path)

if __name__ == '__main__':
    glbp, outp = sys.argv[1], sys.argv[2]
    anim = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] != 'bind' else None
    t = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
    view = sys.argv[5] if len(sys.argv) > 5 else 'front'
    j, b = read_glb(glbp)
    print('nodes', len(j['nodes']), 'skins', len(j['skins']), 'prims', len(j['meshes'][0]['primitives']), 'anims', [a['name'] for a in j.get('animations', [])])
    g = posed(j, b, anim, t); tris, cols = skinned(j, b, g)
    print('tris', len(tris), 'bbox y', tris[:, :, 1].min(), tris[:, :, 1].max())
    render(tris, cols, outp, view)
