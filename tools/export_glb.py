"""Export .glb par personnage : maillage skinné + squelette mixamorig:* (sans suffixes) + animations + atlas embarqués.
Usage : python3 export_glb.py [perso1,perso2,...]   -> ../godot_project/characters/<id>.glb + manifest.json"""
import json, struct, io, os, sys, numpy as np
from PIL import Image
from rig import *; from char import Char; from cast import CAST
import anim

AGE = {'garcon_enfant': 'enfant', 'fille_queue': 'enfant', 'ado_casquette': 'ado', 'ado_fille_longs': 'ado'}
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot_project', 'characters')   # source unique des GLB
CREDIT = ('Modèle de base « Fuse personnage » (Sketchfab, auteur 1831251), licence CC-BY-4.0 ; '
          'personnages dérivés générés par code (voir source_model/license.txt). Crédit obligatoire dans le jeu.')

class Buf:
    def __init__(self): self.b = bytearray(); self.views = []; self.acc = []
    def view(self, data, target=None, stride=None):
        while len(self.b) % 4: self.b.append(0)
        v = dict(buffer=0, byteOffset=len(self.b), byteLength=len(data))
        if stride: v['byteStride'] = stride   # attributs de sommets : stride explicite (multiple de 4)
        if target: v['target'] = target
        self.b += data; self.views.append(v); return len(self.views) - 1
    def accessor(self, arr, ctype, typ, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        stride = int(arr.strides[0]) if target == 34962 else None
        a = dict(bufferView=self.view(arr.tobytes(), target, stride), componentType=ctype, count=int(arr.shape[0]), type=typ)
        if minmax:
            a['min'] = [float(x) for x in np.atleast_1d(arr.min(0))]; a['max'] = [float(x) for x in np.atleast_1d(arr.max(0))]
        self.acc.append(a); return len(self.acc) - 1

def png_bytes(arr):
    bio = io.BytesIO(); Image.fromarray(arr).save(bio, 'PNG'); return bio.getvalue()

def build_glb(c, name, anims):
    base = c.base; J = len(c.parent); B = Buf(); m = c.mesh
    g = dict(asset=dict(version='2.0', generator='crime_game tools/export_glb.py', copyright=CREDIT))
    # nœuds : 0..J-1 = joints, J = maillage
    nodes = []
    ch = [[] for _ in range(J)]
    for j in range(J):
        if c.parent[j] >= 0: ch[c.parent[j]].append(j)
    for j in range(J):
        n = dict(name=base.short[j] if j == 0 else 'mixamorig:' + base.short[j],
                 translation=[float(x) for x in c.lt[j]], rotation=[float(x) for x in c.lr[j]])
        if ch[j]: n['children'] = ch[j]
        nodes.append(n)
    nodes.append(dict(name=name, mesh=0, skin=0))
    ibm = np.array([c.ibm[j].T for j in range(J)], np.float32)              # colonne-major
    pos = m['pos'].astype(np.float32); nrm = m['nrm'].astype(np.float32)
    prim = dict(attributes=dict(
        POSITION=B.accessor(pos, 5126, 'VEC3', 34962, True), NORMAL=B.accessor(nrm, 5126, 'VEC3', 34962),
        TEXCOORD_0=B.accessor(m['uv'].astype(np.float32), 5126, 'VEC2', 34962),
        JOINTS_0=B.accessor(m['joints'].astype(np.uint16), 5123, 'VEC4', 34962),
        WEIGHTS_0=B.accessor((m['weights'] / m['weights'].sum(1, keepdims=True)).astype(np.float32), 5126, 'VEC4', 34962)),
        indices=B.accessor(m['idx'].reshape(-1).astype(np.uint16 if len(pos) < 65535 else np.uint32), 5123 if len(pos) < 65535 else 5125, 'SCALAR', 34963),
        material=0, mode=4)
    g['meshes'] = [dict(name=name, primitives=[prim])]
    g['skins'] = [dict(name='skin', joints=list(range(J)), skeleton=0, inverseBindMatrices=B.accessor(ibm.reshape(J, 16), 5126, 'MAT4'))]
    # images / matériau (OPAQUE : alpha mesuré à 255 partout)
    imgs = []
    for arr in (c.A.color, c.A.normal):
        imgs.append(dict(bufferView=B.view(png_bytes(arr)), mimeType='image/png'))
    g['images'] = imgs; g['samplers'] = [dict(magFilter=9729, minFilter=9987, wrapS=33071, wrapT=33071)]
    g['textures'] = [dict(source=0, sampler=0), dict(source=1, sampler=0)]
    g['materials'] = [dict(name='atlas', alphaMode='OPAQUE', doubleSided=True,
                           pbrMetallicRoughness=dict(baseColorTexture=dict(index=0), metallicFactor=0.0, roughnessFactor=0.9),
                           normalTexture=dict(index=1))]
    # animations
    ga = []
    for an in anims:
        ts, LR, LT = anim.sample(c, an)
        Q = np.array([[mat_to_q(LR[k, j]) for j in range(J)] for k in range(len(ts))])   # (n,J,4)
        for k in range(1, len(ts)):                                                      # chemin le plus court
            s = (Q[k] * Q[k - 1]).sum(-1) < 0; Q[k][s] *= -1
        tin = B.accessor(ts.astype(np.float32), 5126, 'SCALAR', None, True)
        samplers, channels = [], []
        for j in range(J):
            samplers.append(dict(input=tin, output=B.accessor(Q[:, j].astype(np.float32), 5126, 'VEC4'), interpolation='LINEAR'))
            channels.append(dict(sampler=len(samplers) - 1, target=dict(node=j, path='rotation')))
        for jt in (1, 0):   # Hips (rebond) puis _rootJoint (déplacement / root motion)
            samplers.append(dict(input=tin, output=B.accessor(LT[:, jt].astype(np.float32), 5126, 'VEC3'), interpolation='LINEAR'))
            channels.append(dict(sampler=len(samplers) - 1, target=dict(node=jt, path='translation')))
        ga.append(dict(name=an, samplers=samplers, channels=channels))
    g['animations'] = ga
    g['nodes'] = nodes; g['scenes'] = [dict(nodes=[0, J])]; g['scene'] = 0
    g['accessors'] = B.acc; g['bufferViews'] = B.views
    while len(B.b) % 4: B.b.append(0)
    g['buffers'] = [dict(byteLength=len(B.b))]
    js = json.dumps(g, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    return struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(B.b)) + struct.pack('<II', len(js), 0x4E4F534A) + js + \
        struct.pack('<II', len(B.b), 0x004E4942) + bytes(B.b)

def gameplay_anchors(c):
    """Valeurs MESUREES sur le rig : assise (pose 'drive') et prise d'arme (pose 'shoot', visée) -> manifest."""
    sh = c.base.short; ix = {n: i for i, n in enumerate(sh)}
    ts, LR, LT = anim.sample(c, 'drive'); R, P = anim.fk(c, LR[0], LT[0]); pos = c.posed(R, P)[0]
    hips = P[ix['Hips']]; sel = (np.abs(pos[:, 1] - hips[1]) < 0.14) & (np.abs(pos[:, 2] - hips[2]) < 0.2)
    seat = dict(butt_y=round(float(pos[sel][:, 1].min()), 4), hips_z=round(float(hips[2]), 4))
    ts, LR, LT = anim.sample(c, 'shoot'); k = int(0.25 * (len(ts) - 1)); R, P = anim.fk(c, LR[k], LT[k])
    Rh = R[ix['RightHand']]; L = float(np.linalg.norm(c.lt[ix['RightHandIndex1']]))
    yc = np.array([0, 0, 1.0]); zc = np.array([0, 1.0, 0]); xc = np.cross(yc, zc)
    Rw = Rh.T @ np.stack([xc, yc, zc], 1)       # base arme -> main : canon (+Y arme) vers l'avant, dessus (+Z arme) vers le haut
    grip = dict(hand_len_m=round(L, 4), basis_cols=[[round(float(x), 5) for x in Rw[:, j]] for j in range(3)])
    return seat, grip

def main(names):
    os.makedirs(OUT, exist_ok=True); base = Base(); man = dict(credit=CREDIT, units='m', up='+Y', forward='+Z', fps=anim.FPS, characters=[])
    for n in names:
        c = Char(base, CAST[n]); data = build_glb(c, n, list(anim.ANIMS))
        open(f'{OUT}/{n}.glb', 'wb').write(data)
        s = CAST[n]
        man['characters'].append(dict(id=n, file=f'{n}.glb', gender=s['gender'], age=AGE.get(n, 'adulte'),
            height_m=round(float(c.mesh['pos'][:, 1].max() - c.mesh['pos'][:, 1].min()), 3),
            appearance={k: (list(v) if isinstance(v, tuple) else v) for k, v in s.items() if k not in ('gender',)},
            drive_seat=gameplay_anchors(c)[0], weapon_grip=gameplay_anchors(c)[1],
            animations={a: dict(duration=anim.ANIMS[a][1], loop=anim.ANIMS[a][2], root_motion=anim.motion_info(c, a)) for a in anim.ANIMS}))
        print(n, round(len(data) / 1e6, 2), 'Mo')
    json.dump(man, open(f'{OUT}/manifest.json', 'w'), ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main(sys.argv[1].split(',') if len(sys.argv) > 1 else list(CAST))
