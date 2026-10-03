"""Relit un .glb SANS passer par Char (parseur indépendant), applique animation + skinning selon la sémantique glTF,
compare au pipeline interne et rend une image. Usage: python3 verify_glb.py perso anim frame_idx sortie.png"""
import json, struct, io, sys, numpy as np, cv2
from PIL import Image
from rig import read_acc, qmat
from render import render_z
import anim

def load(path):
    d = open(path, 'rb').read(); assert d[:4] == b'glTF'
    jl, _ = struct.unpack('<II', d[12:20]); g = json.loads(d[20:20 + jl]); off = 20 + jl
    bl, _ = struct.unpack('<II', d[off:off + 8]); return g, d[off + 8:off + 8 + bl]

def evaluate(g, buf, an, k):
    nodes = g['nodes']; N = len(nodes)
    T = [np.array(n.get('translation', [0, 0, 0]), float) for n in nodes]; Rq = [np.array(n.get('rotation', [0, 0, 0, 1]), float) for n in nodes]
    a = next(x for x in g['animations'] if x['name'] == an)
    for ch in a['channels']:
        s = a['samplers'][ch['sampler']]; out = read_acc(g, buf, s['output'])[k].astype(float)
        if ch['target']['path'] == 'rotation': Rq[ch['target']['node']] = out
        else: T[ch['target']['node']] = out
    par = {c: i for i, n in enumerate(nodes) for c in n.get('children', [])}
    W = [None] * N
    def world(i):
        if W[i] is None:
            M = np.eye(4); M[:3, :3] = qmat(Rq[i] / np.linalg.norm(Rq[i])); M[:3, 3] = T[i]
            W[i] = (world(par[i]) @ M) if i in par else M
        return W[i]
    for i in range(N): world(i)
    return W

def skin(g, buf, W):
    p = g['meshes'][0]['primitives'][0]; at = p['attributes']; sk = g['skins'][0]
    pos = read_acc(g, buf, at['POSITION']).astype(float); nrm = read_acc(g, buf, at['NORMAL']).astype(float)
    jt = read_acc(g, buf, at['JOINTS_0']).astype(int); wt = read_acc(g, buf, at['WEIGHTS_0']).astype(float)
    ibm = read_acc(g, buf, sk['inverseBindMatrices']).astype(float).reshape(-1, 4, 4).transpose(0, 2, 1)  # col-major -> M
    S = np.array([W[n] @ ibm[i] for i, n in enumerate(sk['joints'])])
    op = np.zeros_like(pos); on = np.zeros_like(nrm)
    for q in range(4):
        Sk = S[jt[:, q]]; w = wt[:, q:q + 1]
        op += w * (np.einsum('nab,nb->na', Sk[:, :3, :3], pos) + Sk[:, :3, 3]); on += w * np.einsum('nab,nb->na', Sk[:, :3, :3], nrm)
    return op, on, read_acc(g, buf, p['indices']).astype(int).reshape(-1, 3), read_acc(g, buf, at['TEXCOORD_0']).astype(float)

if __name__ == '__main__':
    from rig import Base; from char import Char; from cast import CAST
    pers, an, k, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    g, buf = load(f'../godot_project/characters/{pers}.glb')
    op, on, idx, uv = skin(g, buf, evaluate(g, buf, an, k))
    tex = np.array(Image.open(io.BytesIO(buf[g['bufferViews'][g['images'][0]['bufferView']]['byteOffset']:][:g['bufferViews'][g['images'][0]['bufferView']]['byteLength']])).convert('RGB'))
    c = Char(Base(), CAST[pers]); ts, LR, LT = anim.sample(c, an); R, Pp = anim.fk(c, LR[k], LT[k]); ref = c.posed(R, Pp)[0]
    print('erreur max glb vs pipeline interne (m):', float(np.abs(op - ref).max()), '| animations:', len(g['animations']), '| frame', k, '/', len(ts) - 1)
    im = render_z(op, on, uv, idx, tex, 'front', 420, scale=420 * .8 / 1.9, center=np.array([0, .9, 0]), yaw=30, cy=.55)
    cv2.imwrite(out, im)
