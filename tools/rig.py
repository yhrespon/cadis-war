"""Chargement du modèle Fuse (glTF + skin Mixamo) et utilitaires de rig/rendu logiciel."""
import json, numpy as np, os
from PIL import Image

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'source_model')
CT = {5126: np.float32, 5123: np.uint16, 5121: np.uint8, 5125: np.uint32, 5122: np.int16, 5120: np.int8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

def read_acc(g, buf, i):
    a = g['accessors'][i]; bv = g['bufferViews'][a['bufferView']]
    dt = np.dtype(CT[a['componentType']]); n = NC[a['type']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', dt.itemsize * n)
    cnt = a['count']
    raw = np.frombuffer(buf, dtype=np.uint8, count=stride * (cnt - 1) + dt.itemsize * n, offset=off)
    out = np.lib.stride_tricks.as_strided(raw, shape=(cnt, dt.itemsize * n), strides=(stride, 1)).copy()
    out = out.view(dt).reshape(cnt, n)
    return out[:, 0] if n == 1 else out

def qmat(q):
    x, y, z, w = q
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                     [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                     [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])

def mat_to_q(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1) * 2; w = s / 4
        x = (m[2,1]-m[1,2])/s; y = (m[0,2]-m[2,0])/s; z = (m[1,0]-m[0,1])/s
    elif m[0,0] > m[1,1] and m[0,0] > m[2,2]:
        s = np.sqrt(1 + m[0,0]-m[1,1]-m[2,2]) * 2
        w = (m[2,1]-m[1,2])/s; x = s/4; y = (m[0,1]+m[1,0])/s; z = (m[0,2]+m[2,0])/s
    elif m[1,1] > m[2,2]:
        s = np.sqrt(1 + m[1,1]-m[0,0]-m[2,2]) * 2
        w = (m[0,2]-m[2,0])/s; x = (m[0,1]+m[1,0])/s; y = s/4; z = (m[1,2]+m[2,1])/s
    else:
        s = np.sqrt(1 + m[2,2]-m[0,0]-m[1,1]) * 2
        w = (m[1,0]-m[0,1])/s; x = (m[0,2]+m[2,0])/s; y = (m[1,2]+m[2,1])/s; z = s/4
    q = np.array([x, y, z, w]); return q / np.linalg.norm(q)

def rx(a):
    a = np.radians(a); c, s = np.cos(a), np.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def ry(a):
    a = np.radians(a); c, s = np.cos(a), np.sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def rz(a):
    a = np.radians(a); c, s = np.cos(a), np.sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])

class Base:
    MESH_NAMES = ['Eyelashes', 'default', 'Body', 'Tops', 'Bottoms', 'Shoes', 'Hair', 'Gloves']
    def __init__(self):
        g = json.load(open(f'{SRC}/scene.gltf')); buf = open(f'{SRC}/scene.bin', 'rb').read()
        self.g = g
        self.meshes = []
        for m in g['meshes']:
            p = m['primitives'][0]; at = p['attributes']
            self.meshes.append(dict(
                name=m['name'].split('_')[0],
                pos=read_acc(g, buf, at['POSITION']).astype(np.float64),
                nrm=read_acc(g, buf, at['NORMAL']).astype(np.float64),
                uv=read_acc(g, buf, at['TEXCOORD_0']).astype(np.float64),
                joints=read_acc(g, buf, at['JOINTS_0']).astype(np.int64),
                weights=read_acc(g, buf, at['WEIGHTS_0']).astype(np.float64),
                idx=read_acc(g, buf, p['indices']).astype(np.int64).reshape(-1, 3)))
        s = g['skins'][0]
        self.jnodes = s['joints']                       # index nœud de chaque joint
        self.jname = [g['nodes'][n]['name'] for n in self.jnodes]
        nid = {n: i for i, n in enumerate(self.jnodes)}
        self.parent = np.full(len(self.jnodes), -1)
        for i, n in enumerate(self.jnodes):
            for c in g['nodes'][n].get('children', []):
                if c in nid: self.parent[nid[c]] = i
        # TRS local de chaque joint
        self.lt = np.array([g['nodes'][n].get('translation', [0, 0, 0]) for n in self.jnodes], dtype=np.float64)
        self.lr = np.array([g['nodes'][n].get('rotation', [0, 0, 0, 1]) for n in self.jnodes], dtype=np.float64)
        self.ibm = read_acc(g, buf, s['inverseBindMatrices']).reshape(-1, 4, 4).astype(np.float64)  # colonne-major aplati
        self.short = [n.split(':')[1].rsplit('_', 1)[0] if ':' in n else n for n in self.jname]
        self.tex = Image.open(f'{SRC}/textures/PackedMaterial0mat_baseColor.png')
        self.compute_bind()

    def compute_bind(self):
        J = len(self.jnodes); self.Wr = np.zeros((J, 3, 3)); self.Wp = np.zeros((J, 3))
        for j in range(J):
            R = qmat(self.lr[j]); p = self.parent[j]
            if p < 0: self.Wr[j] = R; self.Wp[j] = self.lt[j]
            else:
                self.Wr[j] = self.Wr[p] @ R; self.Wp[j] = self.Wp[p] + self.Wr[p] @ self.lt[j]

    def ibm_mats(self):
        # les IBM glTF sont stockées en colonne-major : reshape donne la transposée
        return np.transpose(self.ibm, (0, 2, 1))

def pose_world(Wr, Wp, parent, lt, lrot, root_off=None):
    """FK : rotations locales (J,3,3) + translations locales lt -> world R,P"""
    J = len(parent); R = np.zeros((J, 3, 3)); P = np.zeros((J, 3))
    for j in range(J):
        p = parent[j]
        t = lt[j] + (root_off if (root_off is not None and p == 1 - 1 and False) else 0)
        if p < 0: R[j] = lrot[j]; P[j] = t
        else: R[j] = R[p] @ lrot[j]; P[j] = P[p] + R[p] @ t
    return R, P
