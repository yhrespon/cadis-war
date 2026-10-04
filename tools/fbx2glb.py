#!/usr/bin/env python3
"""FBX binaire Mixamo (« With Skin », T-pose) -> GLB pour C.A.D.I.S WARS, sans Blender.

Étapes : lecture FBX (fbxparse) -> géométrie triangulée + normales/UV/poids -> décimation (decimate) -> textures (<=1024 px)
-> squelette (noeud _rootJoint + mixamorig:*) -> 17 animations recollées depuis un GLB de référence (retarget local)
-> doigts au repos « main détendue » -> GLB + entrée de manifest (height_m, animations, weapon_grip, drive_seat).

Usage : python3 fbx2glb.py <fbx> <id> <hauteur_m> <genre m|f> <out_dir> [budget_tris] [--skip NomMesh ...]
[NON TESTÉ DANS GODOT] : le GLB est vérifié par tools/verify_new_glb.py (structure + rendu logiciel), pas par l'import Godot.
"""
import io, json, struct, sys, os, math
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbxparse as F
import decimate as D

Image.MAX_IMAGE_PIXELS = None
REF_GLB = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot_project', 'characters', 'homme_barbu.glb')
REF_MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot_project', 'characters', 'manifest.json')

# ---------------------------------------------------------------- maths
def rot_x(a): c, s = math.cos(a), math.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def rot_y(a): c, s = math.cos(a), math.sin(a); return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def rot_z(a): c, s = math.cos(a), math.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def euler_xyz(deg):  # ordre FBX par défaut eEulerXYZ : R = Rz Ry Rx
    x, y, z = [math.radians(v) for v in deg]
    return rot_z(z) @ rot_y(y) @ rot_x(x)

def mat_to_quat(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = math.sqrt(t + 1) * 2; w = s / 4; x = (m[2, 1] - m[1, 2]) / s; y = (m[0, 2] - m[2, 0]) / s; z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1 + m[0, 0] - m[1, 1] - m[2, 2]) * 2; w = (m[2, 1] - m[1, 2]) / s; x = s / 4; y = (m[0, 1] + m[1, 0]) / s; z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1 + m[1, 1] - m[0, 0] - m[2, 2]) * 2; w = (m[0, 2] - m[2, 0]) / s; x = (m[0, 1] + m[1, 0]) / s; y = s / 4; z = (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1 + m[2, 2] - m[0, 0] - m[1, 1]) * 2; w = (m[1, 0] - m[0, 1]) / s; x = (m[0, 2] + m[2, 0]) / s; y = (m[1, 2] + m[2, 1]) / s; z = s / 4
    q = np.array([x, y, z, w]); return q / np.linalg.norm(q)

def quat_to_mat(q):
    x, y, z, w = q
    return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                     [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                     [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])

def qmul(a, b):  # (x,y,z,w) ; a*b ; vectorisable sur le dernier axe
    ax, ay, az, aw = np.moveaxis(a, -1, 0); bx, by, bz, bw = np.moveaxis(b, -1, 0)
    return np.stack([aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
                     aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz], -1)

def qinv(q): return q * np.array([-1, -1, -1, 1.0])

def axis_angle(axis, ang):
    axis = axis / np.linalg.norm(axis); s = math.sin(ang / 2)
    return np.array([axis[0] * s, axis[1] * s, axis[2] * s, math.cos(ang / 2)])

def trs(t, q):
    m = np.eye(4); m[:3, :3] = quat_to_mat(q); m[:3, 3] = t; return m

# ---------------------------------------------------------------- lecture FBX
def props70(node):
    out = {}
    p = node.get('Properties70')
    if p:
        for c in p.children:
            out[c.props[0]] = c.props[4:]
    return out

def load_fbx(path, skip=()):
    s = F.Scene(path)
    # --- os
    bones = {}  # id -> dict
    for i, n, node in s.of('Model'):
        if node.props[2] == 'LimbNode':
            pr = props70(node)
            t = np.array(pr.get('Lcl Translation', [0, 0, 0]), float)
            pre = np.array(pr.get('PreRotation', [0, 0, 0]), float)
            rot = np.array(pr.get('Lcl Rotation', [0, 0, 0]), float)
            q = mat_to_quat(euler_xyz(pre) @ euler_xyz(rot))
            parent = None
            for p, _ in s.parents.get(i, []):
                if p in s.objs and s.objs[p][0] == 'Model' and s.objs[p][2].props[2] == 'LimbNode':
                    parent = p
            bones[i] = dict(name=n, t=t, q=q, parent=parent)
    # ordre topologique
    order = []; seen = set()
    def visit(i):
        if i in seen: return
        if bones[i]['parent'] is not None: visit(bones[i]['parent'])
        seen.add(i); order.append(i)
    for i in bones: visit(i)
    # globales par propriétés
    G = {}
    for i in order:
        L = trs(bones[i]['t'], bones[i]['q'])
        G[i] = (G[bones[i]['parent']] if bones[i]['parent'] is not None else np.eye(4)) @ L
    # TransformLink (vérité de la pose de liaison) et validation
    tl = {}
    for i, n, node in s.of('Deformer'):
        if node.props[2] == 'Cluster':
            link = [c for c, _ in s.kids.get(i, []) if c in bones]
            if link and node.get('TransformLink'):
                tl[link[0]] = np.array(node.get('TransformLink').props[0]).reshape(4, 4).T
    maxerr = max((np.abs(tl[i][:3, 3] - G[i][:3, 3]).max() for i in tl), default=0.0)
    # --- maillages
    meshes = []
    for i, n, node in s.of('Model'):
        if node.props[2] != 'Mesh' or any(k in n for k in skip): continue
        geo = [c for c, _ in s.kids.get(i, []) if c in s.objs and s.objs[c][0] == 'Geometry']
        if not geo: continue
        gnode = s.objs[geo[0]][2]
        mats = [c for c, _ in s.kids.get(i, []) if c in s.objs and s.objs[c][0] == 'Material']
        # clusters
        skin = [c for c, _ in s.kids.get(geo[0], []) if c in s.objs and s.objs[c][0] == 'Deformer']
        clusters = []
        for sk in skin:
            for c, _ in s.kids.get(sk, []):
                if c in s.objs and s.objs[c][0] == 'Deformer':
                    cn = s.objs[c][2]
                    link = [b for b, _ in s.kids.get(c, []) if b in bones]
                    if link and cn.get('Indexes') and cn.get('Weights'):
                        clusters.append((link[0], cn.get('Indexes').props[0], cn.get('Weights').props[0]))
        meshes.append(dict(name=n, geo=gnode, mats=mats, clusters=clusters, mid=i))
    return s, bones, order, G, tl, maxerr, meshes

def triangulate(g):
    pv = g.get('PolygonVertexIndex').props[0].astype(np.int64)
    ends = np.where(pv < 0)[0]
    starts = np.concatenate([[0], ends[:-1] + 1])
    idx = np.where(pv < 0, ~pv, pv)
    corner_tri = []  # (c0,c1,c2) indices de coins, poly index
    tris = []; poly = []
    for pi, (a, b) in enumerate(zip(starts, ends)):
        ln = b - a + 1
        for k in range(1, ln - 1):
            tris.append((a, a + k, a + k + 1)); poly.append(pi)
    return idx, np.array(tris, np.int64), np.array(poly, np.int64)

def layer(g, name, vals, idxname):
    le = g.get(name)
    if le is None: return None
    mp = le.get('MappingInformationType').props[0]; rf = le.get('ReferenceInformationType').props[0]
    arr = le.get(vals).props[0]
    ix = le.get(idxname).props[0] if (idxname and le.get(idxname)) else None
    return mp, rf, arr, ix

def build_mesh(mesh, nverts_total=None):
    g = mesh['geo']
    pos = g.get('Vertices').props[0].reshape(-1, 3).astype(np.float64)
    idx, tris, poly = triangulate(g)
    ncorner = len(idx)
    # normales
    nrm = None
    L = layer(g, 'LayerElementNormal', 'Normals', 'NormalsIndex')
    if L:
        mp, rf, arr, ix = L; arr = arr.reshape(-1, 3)
        if mp == 'ByPolygonVertex': nrm = arr[ix] if (rf == 'IndexToDirect' and ix is not None) else arr[:ncorner]
        elif mp == 'ByVertice' or mp == 'ByVertex': nrm = (arr[ix] if ix is not None else arr)[idx]
    if nrm is None: nrm = np.zeros((ncorner, 3)); nrm[:, 1] = 1
    uv = None
    L = layer(g, 'LayerElementUV', 'UV', 'UVIndex')
    if L:
        mp, rf, arr, ix = L; arr = arr.reshape(-1, 2)
        uv = arr[ix] if (rf == 'IndexToDirect' and ix is not None) else arr[:ncorner]
    if uv is None: uv = np.zeros((ncorner, 2))
    # matériaux par polygone
    L = layer(g, 'LayerElementMaterial', 'Materials', None)
    if L and L[0] == 'ByPolygon': pm = L[2].astype(np.int64)
    else: pm = np.zeros(int(poly.max()) + 1, np.int64)
    # poids par sommet
    nv = len(pos)
    W = np.zeros((nv, 4)); J = np.zeros((nv, 4), np.int64)
    acc = [[] for _ in range(nv)]
    for bone_id, ids, ws in mesh['clusters']:
        for v, w in zip(ids, ws):
            if w > 1e-5: acc[int(v)].append((float(w), bone_id))
    for v in range(nv):
        a = sorted(acc[v], reverse=True)[:4]
        tot = sum(w for w, _ in a) or 1.0
        for k, (w, b) in enumerate(a): W[v, k] = w / tot; J[v, k] = b
    # sommets uniques (pos, normale, uv) par matériau
    out = {}
    for m in np.unique(pm[poly]):
        tsel = tris[pm[poly] == m]
        corners = tsel.reshape(-1)
        key = np.concatenate([idx[corners][:, None].astype(np.float64), np.round(nrm[corners], 4), np.round(uv[corners], 5)], 1)
        uk, inv = np.unique(key, axis=0, return_inverse=True)
        inv = inv.reshape(-1)
        pidx = uk[:, 0].astype(np.int64)
        out[int(m)] = dict(P=pos[pidx], N=uk[:, 1:4], UV=uk[:, 4:6], J=J[pidx], W=W[pidx], F=inv.reshape(-1, 3).astype(np.int64))
    return out

# ---------------------------------------------------------------- textures / matériaux
def material_textures(s, mat_id):
    """propriété -> (nom, octets image). Repli : image sans contenu -> autre Video de même nom de fichier avec contenu."""
    def content(v):
        c = s.objs[v][2].get('Content')
        return c.props[0] if (c is not None and c.props and c.props[0]) else None
    def fname(v):
        r = s.objs[v][2].get('RelativeFilename') or s.objs[v][2].get('Filename')
        return r.props[0].replace('\\', '/').split('/')[-1] if (r is not None and r.props) else ''
    byfile = {}
    for i, v in s.objs.items():
        if v[0] == 'Video' and content(i): byfile.setdefault(fname(i), i)
    out = {}
    for t, ch, pa, pr in s.conn:
        if pa == mat_id and ch in s.objs and s.objs[ch][0] == 'Texture':
            vids = [c for c, _ in s.kids.get(ch, []) if c in s.objs and s.objs[c][0] == 'Video']
            if not vids: continue
            data = content(vids[0])
            if data is None and fname(vids[0]) in byfile: data = content(byfile[fname(vids[0])])
            if data is None: continue
            out[pr] = (s.objs[ch][1], data)
    return out

def material_color(s, mat_id):
    pr = props70(s.objs[mat_id][2])
    v = pr.get('DiffuseColor') or pr.get('Diffuse')
    return [float(x) for x in v[:3]] if v else None

def to_image(data, max_px, kind):
    im = Image.open(io.BytesIO(data)); im.load()
    if im.mode in ('P', 'LA'): im = im.convert('RGBA')
    if im.mode not in ('RGB', 'RGBA', 'L'): im = im.convert('RGB')
    w, h = im.size
    sc = min(1.0, max_px / max(w, h))
    if sc < 1.0: im = im.resize((max(1, int(w * sc)), max(1, int(h * sc))), Image.LANCZOS)
    return im

def encode(im, jpeg):
    b = io.BytesIO()
    if jpeg:
        im.convert('RGB').save(b, 'JPEG', quality=86, optimize=True)
        return b.getvalue(), 'image/jpeg'
    im.save(b, 'PNG', optimize=True)
    return b.getvalue(), 'image/png'

# ---------------------------------------------------------------- GLB
class GLB:
    def __init__(self): self.bin = bytearray(); self.bv = []; self.acc = []
    def view(self, data, target=None):
        while len(self.bin) % 4: self.bin.append(0)
        o = len(self.bin); self.bin += data
        d = dict(buffer=0, byteOffset=o, byteLength=len(data))
        if target: d['target'] = target
        self.bv.append(d); return len(self.bv) - 1
    def accessor(self, arr, ctype, typ, target=None, minmax=False):
        v = self.view(arr.tobytes(), target)
        a = dict(bufferView=v, componentType=ctype, count=len(arr), type=typ)
        if minmax: a['min'] = arr.min(0).tolist() if arr.ndim > 1 else [float(arr.min())]; a['max'] = arr.max(0).tolist() if arr.ndim > 1 else [float(arr.max())]
        self.acc.append(a); return len(self.acc) - 1

def write_glb(path, js, binary):
    jb = json.dumps(js, separators=(',', ':')).encode()
    jb += b' ' * ((4 - len(jb) % 4) % 4)
    binary = bytes(binary) + b'\0' * ((4 - len(binary) % 4) % 4)
    with open(path, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(jb) + 8 + len(binary)))
        f.write(struct.pack('<II', len(jb), 0x4E4F534A)); f.write(jb)
        f.write(struct.pack('<II', len(binary), 0x004E4942)); f.write(binary)

def read_glb(path):
    d = open(path, 'rb').read()
    l, = struct.unpack('<I', d[12:16]); j = json.loads(d[20:20 + l]); b = d[20 + l + 8:]
    return j, b

def read_acc(j, b, i):
    a = j['accessors'][i]; bv = j['bufferViews'][a['bufferView']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    return np.frombuffer(b, dtype='<f4', count=a['count'] * n, offset=bv.get('byteOffset', 0) + a.get('byteOffset', 0)).reshape(a['count'], n).astype(np.float64)

# ---------------------------------------------------------------- squelette cible
FINGERS = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky']
CURL = {'Thumb': (8, 12, 12), 'Index': (22, 30, 24), 'Middle': (24, 32, 26), 'Ring': (26, 34, 28), 'Pinky': (28, 36, 30)}

def convert(fbx, cid, height, gender, out_dir, budget=22000, skip=(), age='adulte'):
    s, bones, order, G, tl, maxerr, meshes = load_fbx(fbx, skip)
    byname = {bones[i]['name']: i for i in bones}
    hips = byname['mixamorig:Hips']
    # --- construire les maillages en espace monde (bind), poids -> ids os
    built = []
    for m in meshes:
        bm = build_mesh(m)
        for slot, d in bm.items():
            mat = m['mats'][slot] if slot < len(m['mats']) else None
            built.append(dict(mesh=m['name'], slot=slot, mat=mat, **d))
    allp = np.concatenate([b['P'] for b in built])
    ymin, ymax = allp[:, 1].min(), allp[:, 1].max()
    sc = height / (ymax - ymin)                       # FBX Mixamo : unités maison -> mètres réels
    shift = -ymin * sc
    # budget de triangles : réparti au prorata, plancher par pièce
    tot = sum(len(b['F']) for b in built)
    ratio = min(1.0, budget / tot)
    for b in built:
        b['P'] = b['P'] * sc; b['P'][:, 1] += shift
        tgt = len(b['F']) if ratio >= 1.0 else max(120, int(len(b['F']) * ratio)) if len(b['F']) > 600 else len(b['F'])
        if tgt < len(b['F']):
            Fn = D.decimate(b['P'], b['F'], tgt)
            used = np.unique(Fn); remap = -np.ones(len(b['P']), np.int64); remap[used] = np.arange(len(used))
            for k in ('P', 'N', 'UV', 'J', 'W'): b[k] = b[k][used]
            b['F'] = remap[Fn]
    # --- os : globales mises à l'échelle / décalées
    bone_ids = [i for i in order]
    names = [bones[i]['name'] for i in bone_ids]
    gl = {}
    for i in order:
        Gi = G[i].copy(); Gi[:3, 3] = Gi[:3, 3] * sc; Gi[1, 3] += shift
        gl[i] = Gi
    # IBM : inverse de la pose de liaison monde (maillage Mixamo déjà en espace monde, Transform = inverse(TransformLink))
    ibm = {}
    for i in order:
        L = tl.get(i, G[i]).copy(); L[:3, 3] = L[:3, 3] * sc; L[1, 3] += shift
        ibm[i] = np.linalg.inv(L)
    # --- glTF
    glb = GLB(); js = dict(asset=dict(version='2.0', generator='cadis fbx2glb v16'), scene=0, scenes=[dict(nodes=[0, len(order) + 1])])
    nodes = [dict(name='_rootJoint', translation=[0, 0, 0], rotation=[0, 0, 0, 1], children=[1])]
    nid = {i: k + 1 for k, i in enumerate(order)}
    kids = {i: [] for i in order}
    for i in order:
        if bones[i]['parent'] is not None: kids[bones[i]['parent']].append(nid[i])
    for i in order:
        p = bones[i]['parent']
        loc_t = (bones[i]['t'] * sc).tolist()
        if p is None: loc_t = [float(gl[i][0, 3]), float(gl[i][1, 3]), float(gl[i][2, 3])]
        nd = dict(name=bones[i]['name'], translation=[float(v) for v in loc_t], rotation=[float(v) for v in bones[i]['q']])
        if kids[i]: nd['children'] = kids[i]
        nodes.append(nd)
    # racine : _rootJoint -> Hips seulement ; autres racines os (rare) rattachées à _rootJoint
    roots = [nid[i] for i in order if bones[i]['parent'] is None]
    nodes[0]['children'] = roots
    # --- matériaux / textures
    images = []; textures = []; materials = []; matkey = {}
    def add_img(data, mime):
        images.append(dict(bufferView=glb.view(data), mimeType=mime)); textures.append(dict(source=len(images) - 1)); return len(textures) - 1
    material_info = {}
    img_cache = {}
    users = {}
    for b in built: users.setdefault(b['mat'], set()).add(b['mesh'])
    for b in built:
        key = (b['mat'], b['mesh'])
        if key in matkey: b['mi'] = matkey[key]; continue
        mid = b['mat']
        tx = material_textures(s, mid) if mid else {}
        mname = s.objs[mid][1] if mid else 'mat'
        if len(users[mid]) > 1: mname = mname + '.' + b['mesh']      # une matière par pièce -> teinte séparée dans Godot
        pm = dict(baseColorFactor=[1, 1, 1, 1], metallicFactor=0.0, roughnessFactor=0.85)
        mc = material_color(s, mid) if mid else None
        mat = dict(name=mname, pbrMetallicRoughness=pm, doubleSided=True)
        diff = tx.get('DiffuseColor'); nrm = tx.get('NormalMap') or tx.get('Bump')
        opa = tx.get('TransparentColor') or tx.get('Opacity')
        if diff:
            ck = ('d', diff[0], opa[0] if opa else None)
            if ck not in img_cache:
                im = to_image(diff[1], 1024, 'd')
                if opa and not (im.mode == 'RGBA'):
                    om = to_image(opa[1], 1024, 'o').convert('L').resize(im.size)
                    im = im.convert('RGB'); im.putalpha(om)
                has_alpha = im.mode == 'RGBA' and np.array(im.getchannel('A')).min() < 250
                if im.mode == 'RGBA' and not has_alpha: im = im.convert('RGB')
                data, mime = encode(im, jpeg=not has_alpha)
                img_cache[ck] = (add_img(data, mime), has_alpha)
            ti, has_alpha = img_cache[ck]
            if has_alpha: mat['alphaMode'] = 'MASK'; mat['alphaCutoff'] = 0.5
            pm['baseColorTexture'] = dict(index=ti)
        if nrm:
            ck = ('n', nrm[0])
            if ck not in img_cache:
                data, mime = encode(to_image(nrm[1], 1024, 'n').convert('RGB'), jpeg=True)
                img_cache[ck] = (add_img(data, mime), False)
            mat['normalTexture'] = dict(index=img_cache[ck][0])
        if not diff and mc: pm['baseColorFactor'] = [max(0.05, c) for c in mc] + [1]
        matkey[key] = len(materials); b['mi'] = matkey[key]; materials.append(mat)
        material_info[mname] = dict(has_albedo=bool(diff), has_normal=bool(nrm), alpha=mat.get('alphaMode', 'OPAQUE'), mesh=b['mesh'])
    # --- primitives
    prims = []
    for b in built:
        N = b['N'].astype(np.float32)
        N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
        # os (id FBX) -> indice de joint
        jidx = {i: k + 1 for k, i in enumerate(order)}
        Jm = np.vectorize(lambda x: jidx.get(int(x), 0))(b['J']).astype(np.uint16)
        Wf = b['W'].astype(np.float32)
        Wf[(Wf.sum(1) == 0), 0] = 1.0
        attr = dict(POSITION=glb.accessor(b['P'].astype(np.float32), 5126, 'VEC3', 34962, True),
                    NORMAL=glb.accessor(N, 5126, 'VEC3', 34962),
                    TEXCOORD_0=glb.accessor(np.stack([b['UV'][:, 0], 1 - b['UV'][:, 1]], 1).astype(np.float32), 5126, 'VEC2', 34962),
                    JOINTS_0=glb.accessor(Jm, 5123, 'VEC4', 34962),
                    WEIGHTS_0=glb.accessor(Wf, 5126, 'VEC4', 34962))
        ind = b['F'].astype(np.uint32).reshape(-1)
        prims.append(dict(attributes=attr, indices=glb.accessor(ind, 5125, 'SCALAR', 34963), material=b['mi'], mode=4))
    ibm_arr = np.stack([np.eye(4)] + [ibm[i].T for i in order]).astype(np.float32)   # _rootJoint (identité) est un joint du skin, comme dans les GLB d'origine
    ibm_acc = glb.accessor(ibm_arr.reshape(-1, 16), 5126, 'MAT4')
    js['accessors'] = glb.acc
    skin = dict(name=cid, joints=[0] + [nid[i] for i in order], inverseBindMatrices=ibm_acc, skeleton=0)
    nodes.append(dict(name=cid, mesh=0, skin=0))
    js.update(nodes=nodes, skins=[skin], meshes=[dict(name=cid, primitives=prims)], materials=materials, textures=textures, images=images,
              samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)])
    for t in textures: t['sampler'] = 0
    # --- animations retargetées
    anims, am = retarget(glb, js, bones, order, nid, gl, sc, hips)
    js['animations'] = anims
    js['accessors'] = glb.acc; js['bufferViews'] = glb.bv
    js['buffers'] = [dict(byteLength=len(glb.bin))]
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, cid + '.glb')
    write_glb(out, js, glb.bin)
    # --- manifest
    entry = manifest_entry(cid, gender, age, height, bones, order, gl, sc, am, hips, material_info)
    ntri = sum(len(b['F']) for b in built)
    info = dict(id=cid, file=out, tris_before=int(tot), tris_after=int(ntri), bones=len(order), scale=float(sc), fbx_height_units=float(ymax - ymin),
                bind_err_units=float(maxerr), size_mb=round(os.path.getsize(out) / 1e6, 2), materials=material_info, textures=len(textures))
    return entry, info

# ---------------------------------------------------------------- animations
def retarget(glb, js, bones, order, nid, gl, sc, hips):
    rj, rb = read_glb(REF_GLB)
    rnames = [n['name'] for n in rj['nodes']]
    # pose de liaison de référence (locale)
    rbind = {n['name']: (np.array(n.get('translation', [0, 0, 0])), np.array(n.get('rotation', [0, 0, 0, 1]))) for n in rj['nodes']}
    new_by = {bones[i]['name']: i for i in order}
    r_hips_y = rbind['mixamorig:Hips'][0][1]
    n_hips_y = gl[hips][1, 3]
    r = n_hips_y / r_hips_y                           # rapport de taille (bassin) : translations Hips/_rootJoint
    # doigts : axe de flexion (monde) -> local, relaxé
    finger_q = {}
    for side in ('Left', 'Right'):
        for f in FINGERS:
            for k in (1, 2, 3):
                nm = 'mixamorig:%sHand%s%d' % (side, f, k)
                if nm not in new_by: continue
                i = new_by[nm]
                child = new_by.get('mixamorig:%sHand%s%d' % (side, f, k + 1))
                if child is None: continue
                d = gl[child][:3, 3] - gl[i][:3, 3]; d /= np.linalg.norm(d)
                ax = np.cross(d, np.array([0, -1.0, 0]))
                if f == 'Thumb': ax = np.cross(d, np.array([0.0, -1.0, 0.0]))
                if np.linalg.norm(ax) < 1e-6: continue
                axl = gl[i][:3, :3].T @ (ax / np.linalg.norm(ax))
                # gl[i] = rotation monde de l'os en pose de liaison ; l'axe est exprimé dans le repère de l'os
                finger_q[i] = qmul(bones[i]['q'], axis_angle(axl, math.radians(CURL[f][k - 1])))
    anims = []; am = {}
    for a in rj['animations']:
        chans = []; samplers = []; tracks = {}
        for c in a['channels']:
            nm = rnames[c['target']['node']]; path = c['target']['path']
            smp = a['samplers'][c['sampler']]
            tracks[(nm, path)] = (read_acc(rj, rb, smp['input'])[:, 0], read_acc(rj, rb, smp['output']))
        tref = tracks[('mixamorig:Hips', 'rotation')][0]
        def add(node, path, times, vals):
            ti = glb.accessor(times.astype(np.float32), 5126, 'SCALAR', None, True)
            vi = glb.accessor(vals.astype(np.float32), 5126, 'VEC4' if path == 'rotation' else 'VEC3')
            samplers.append(dict(input=ti, output=vi, interpolation='LINEAR'))
            chans.append(dict(sampler=len(samplers) - 1, target=dict(node=node, path=path)))
        # _rootJoint
        for (nm, path), (tt, vv) in tracks.items():
            if nm == '_rootJoint':
                add(0, path, tt, vv * r if path == 'translation' else vv)
            elif nm in new_by and 'Hand' not in nm.replace('mixamorig:LeftHand', 'H').replace('mixamorig:RightHand', 'H')[:0] and not any(f in nm for f in FINGERS):
                i = new_by[nm]
                if path == 'translation':
                    add(nid[i], path, tt, vv * r)
                else:
                    qb_old = rbind[nm][1]
                    q = qmul(qmul(bones[i]['q'][None, :], qinv(qb_old)[None, :]), vv)
                    q /= np.linalg.norm(q, axis=1, keepdims=True)
                    # continuité du signe
                    for k in range(1, len(q)):
                        if (q[k] * q[k - 1]).sum() < 0: q[k] = -q[k]
                    add(nid[i], path, tt, q)
        # doigts relaxés : pose constante
        for i, q in finger_q.items():
            add(nid[i], 'rotation', np.array([tref[0], tref[-1]]), np.stack([q, q]))
        anims.append(dict(name=a['name'], channels=chans, samplers=samplers))
    return anims, r

def manifest_entry(cid, gender, age, height, bones, order, gl, sc, r, hips, material_info):
    ref = json.load(open(REF_MANIFEST))['characters'][0]
    new_by = {bones[i]['name']: i for i in order}
    ranim = {}
    for k, v in ref['animations'].items():
        e = json.loads(json.dumps(v))
        rm = e.get('root_motion', {})
        for key in ('distance_m', 'speed_mps'):
            if key in rm: rm[key] = [round(x * r, 3) for x in rm[key]]
        ranim[k] = e
    gk = ref['weapon_grip']
    hand = gl[new_by['mixamorig:RightHand']][:3, 3]; idx1 = gl[new_by['mixamorig:RightHandIndex1']][:3, 3]
    hand_len = float(np.linalg.norm(hand - idx1))
    n_hips_y = gl[hips][1, 3]
    # siège : même relation que la référence (bassin en pose « drive » - 0.14 m ; z du bassin), mise à l'échelle r
    seat = dict(butt_y=round(0.5551 * r - 0.1397 * r, 4), hips_z=round(-0.13254 * r + gl[hips][2, 3] - 0.0, 4))
    seat['hips_z'] = round(-0.13254 * r, 4)
    ent = dict(id=cid, file=cid + '.glb', gender=gender, age=age, height_m=round(float(height), 3),
               appearance=dict(source='mixamo', materials=sorted(material_info.keys())),
               drive_seat=seat, weapon_grip=dict(hand_len_m=round(max(hand_len, 0.115), 4), hand_len_measured_m=round(hand_len, 4), basis_cols=gk['basis_cols']),   # plancher 0.115 m : armes à >= 80 % de l'échelle de référence
               animations=ranim, outfit_tiles={}, source='mixamo', legacy=False,
               tint_materials={})
    return ent

if __name__ == '__main__':
    a = sys.argv[1:]
    skip = ()
    if '--skip' in a: k = a.index('--skip'); skip = tuple(a[k + 1:]); a = a[:k]
    fbx, cid, h, g, out = a[:5]
    budget = int(a[5]) if len(a) > 5 else 22000
    entry, info = convert(fbx, cid, float(h), g, out, budget, skip)
    json.dump(entry, open(os.path.join(out, cid + '.entry.json'), 'w'), indent=1)
    print(json.dumps(info, indent=1))
