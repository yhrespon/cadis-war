#!/usr/bin/env python3
"""Ajoute l'animation « stab » (double coup de poignard) aux GLB Mixamo (mx_*.glb) + manifest.json.

POURQUOI : Double_Dagger_Stab.fbx avait été exporté sur le mannequin gris « Beta » (autre squelette/proportions) et n'était donc pas
utilisé ; ce fichier n'est de toute façon pas dans l'archive. Cette animation est donc CONSTRUITE PAR CODE (visée os par os :
épaule -> coude -> main orientés vers des directions cibles, torsion du buste, garde de la main gauche), pas copiée de Mixamo.
Si vous refournissez le FBX d'origine avec squelette « mixamorig » (export Mixamo « With Skin » sur Remy), l'animation pourra être
retargetée à l'identique (mêmes noms d'os) : elle remplacera alors simplement le clip « stab ».

Usage : python3 tools/add_stab_anim.py            (depuis la racine du projet ; idempotent : remplace un « stab » existant)
        python3 tools/add_stab_anim.py --render   (écrit aussi des PNG de contrôle dans /tmp/stab_*.png via verify_new_glb)
"""
import sys, os, json, math, struct
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fbx2glb import read_glb, read_acc, write_glb, quat_to_mat, mat_to_quat, qmul

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot_project', 'characters')
FPS = 30.0
DURATION = 1.2
N = int(round(DURATION * FPS)) + 1


def norm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3.0 - 2.0 * x)


def seg(t, a, b):
    """0 avant a, 1 après b, lissé entre les deux."""
    return smooth((t - a) / max(b - a, 1e-6))


def extension(t):
    """0 = poignard armé près du corps, 1 = bras tendu. Deux coups : 0,15-0,27 s et 0,58-0,68 s."""
    e = seg(t, 0.00, 0.15) * 0.35                    # armement (35 %)
    e += seg(t, 0.15, 0.27) * 0.65                   # 1er coup, rapide
    e -= seg(t, 0.33, 0.50) * 0.65                   # retour
    e += seg(t, 0.50, 0.58) * 0.0
    e += seg(t, 0.58, 0.68) * 0.65                   # 2e coup
    e -= seg(t, 0.72, 0.92) * 0.65
    e -= seg(t, 0.92, 1.20) * 0.35                   # retour au repos
    return min(max(e, 0.0), 1.0)


def guard(t):
    """Garde de la main gauche : monte au début, retombe à la fin."""
    return seg(t, 0.0, 0.14) * (1.0 - seg(t, 0.95, 1.2))


def rot_axis(axis, ang):
    axis = norm(axis)
    x, y, z = axis
    c, s = math.cos(ang), math.sin(ang)
    C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


def arc(a, b):
    """Rotation (matrice) de plus court chemin qui amène la direction a sur la direction b."""
    a, b = norm(a), norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        perp = np.cross(a, [1, 0, 0])
        if np.linalg.norm(perp) < 1e-6:
            perp = np.cross(a, [0, 1, 0])
        return rot_axis(perp, math.pi)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


class Rig:
    def __init__(self, j, b):
        self.j, self.b = j, b
        self.nodes = j['nodes']
        self.names = [n.get('name', '') for n in self.nodes]
        self.idx = {n: i for i, n in enumerate(self.names)}
        self.par = {c: p for p, n in enumerate(self.nodes) for c in n.get('children', [])}
        self.T = [np.array(n.get('translation', [0, 0, 0]), float) for n in self.nodes]
        self.Q = [np.array(n.get('rotation', [0, 0, 0, 1]), float) for n in self.nodes]
        idle = [a for a in j['animations'] if a['name'] == 'idle'][0]
        self.animated = {}
        for c in idle['channels']:
            s = idle['samplers'][c['sampler']]
            v = read_acc(j, b, s['output'])[0]
            k = c['target']['node']
            if c['target']['path'] == 'rotation':
                self.Q[k] = v / np.linalg.norm(v)
            else:
                self.T[k] = v
            self.animated[(k, c['target']['path'])] = True

    def grot(self, i, Q):
        r = np.eye(3)
        chain = []
        while i is not None:
            chain.append(i)
            i = self.par.get(i)
        for k in reversed(chain):
            r = r @ quat_to_mat(Q[k])
        return r

    def aim(self, bone, child, direction, Q):
        """Oriente l'os pour que (os -> enfant) pointe vers `direction` (monde)."""
        i, c = self.idx[bone], self.idx[child]
        rp = self.grot(self.par[i], Q) if i in self.par else np.eye(3)
        rb = rp @ quat_to_mat(Q[i])
        cur = rb @ self.T[c]
        d = arc(cur, direction)
        Q[i] = mat_to_quat(rp.T @ (d @ rb))

    def twist(self, bone, axis, ang, Q):
        """Applique une rotation d'axe MONDE sur un os (en gardant l'orientation du parent)."""
        i = self.idx[bone]
        rp = self.grot(self.par[i], Q) if i in self.par else np.eye(3)
        rb = rp @ quat_to_mat(Q[i])
        Q[i] = mat_to_quat(rp.T @ (rot_axis(axis, ang) @ rb))


# directions cibles (repère du modèle : +Z devant, +Y haut, -X = côté droit du personnage)
R_UP_CH, R_FO_CH = norm([-0.32, -0.80, -0.50]), norm([-0.05, 0.35, 0.94])      # armé
R_UP_EX, R_FO_EX = norm([-0.17, -0.22, 0.96]), norm([-0.04, 0.06, 1.0])        # tendu
L_UP, L_FO = norm([0.30, -0.78, 0.40]), norm([-0.40, 0.60, 0.70])              # garde gauche


def nlerp(a, b, u):
    return norm(a * (1 - u) + b * u)


def pose_at(rig, t):
    Q = [q.copy() for q in rig.Q]
    e, g = extension(t), guard(t)
    twist = math.radians(13.0) * e + math.radians(5.0) * g
    lean = math.radians(7.0) * e
    rig.twist('mixamorig:Spine1', [0, 1, 0], twist * 0.55, Q)
    rig.twist('mixamorig:Spine2', [0, 1, 0], twist * 0.55, Q)
    rig.twist('mixamorig:Spine1', [1, 0, 0], lean * 0.5, Q)
    rig.twist('mixamorig:Spine2', [1, 0, 0], lean * 0.5, Q)
    rig.twist('mixamorig:Head', [0, 1, 0], -twist * 0.9, Q)       # le regard reste sur la cible
    # bras droit : du chambrage à l'extension
    r_up = nlerp(R_UP_CH, R_UP_EX, e)
    r_fo = nlerp(R_FO_CH, R_FO_EX, e)
    k = seg(t, 0.0, 0.10) * (1.0 - seg(t, 0.98, 1.2))             # fondu repos <-> action
    cur_up = norm(rig.grot(rig.idx['mixamorig:RightArm'], Q) @ rig.T[rig.idx['mixamorig:RightForeArm']])
    rig.aim('mixamorig:RightArm', 'mixamorig:RightForeArm', nlerp(cur_up, r_up, k), Q)
    cur_fo = norm(rig.grot(rig.idx['mixamorig:RightForeArm'], Q) @ rig.T[rig.idx['mixamorig:RightHand']])
    rig.aim('mixamorig:RightForeArm', 'mixamorig:RightHand', nlerp(cur_fo, r_fo, k), Q)
    cur_h = norm(rig.grot(rig.idx['mixamorig:RightHand'], Q) @ rig.T[rig.idx['mixamorig:RightHandMiddle1']])
    rig.aim('mixamorig:RightHand', 'mixamorig:RightHandMiddle1', nlerp(cur_h, norm(r_fo + np.array([0.0, 0.16, 0.0])), k), Q)   # poignet légèrement relevé
    # bras gauche : garde
    cur_up = norm(rig.grot(rig.idx['mixamorig:LeftArm'], Q) @ rig.T[rig.idx['mixamorig:LeftForeArm']])
    rig.aim('mixamorig:LeftArm', 'mixamorig:LeftForeArm', nlerp(cur_up, L_UP, g), Q)
    cur_fo = norm(rig.grot(rig.idx['mixamorig:LeftForeArm'], Q) @ rig.T[rig.idx['mixamorig:LeftHand']])
    rig.aim('mixamorig:LeftForeArm', 'mixamorig:LeftHand', nlerp(cur_fo, L_FO, g), Q)
    return Q


def add_stab(path):
    j, b = read_glb(path)
    rig = Rig(j, b)
    binary = bytearray(b)
    times = np.arange(N, dtype=np.float32) / FPS

    def view(arr):
        while len(binary) % 4:
            binary.append(0)
        off = len(binary)
        binary.extend(arr.tobytes())
        j['bufferViews'].append(dict(buffer=0, byteOffset=off, byteLength=arr.nbytes))
        return len(j['bufferViews']) - 1

    def accessor(arr, typ, minmax=False):
        a = dict(bufferView=view(arr), componentType=5126, count=int(len(arr)), type=typ)
        if minmax:
            a['min'] = [float(arr.min())]
            a['max'] = [float(arr.max())]
        j['accessors'].append(a)
        return len(j['accessors']) - 1

    frames = [pose_at(rig, float(t)) for t in times]
    t_full = accessor(times, 'SCALAR', True)
    t_const = accessor(np.array([0.0, DURATION], dtype=np.float32), 'SCALAR', True)
    samplers, channels = [], []

    def add(node, path_, tacc, arr, typ):
        samplers.append(dict(input=tacc, output=accessor(arr.astype(np.float32), typ), interpolation='LINEAR'))
        channels.append(dict(sampler=len(samplers) - 1, target=dict(node=node, path=path_)))

    for (k, p) in sorted(rig.animated.keys()):
        if p == 'translation':
            add(k, p, t_const, np.stack([rig.T[k], rig.T[k]]), 'VEC3')
            continue
        arr = np.stack([f[k] for f in frames])
        for n in range(1, len(arr)):                                   # continuité de signe
            if float((arr[n] * arr[n - 1]).sum()) < 0:
                arr[n] = -arr[n]
        if np.abs(arr - arr[0]).max() < 1e-6:
            add(k, p, t_const, np.stack([arr[0], arr[0]]), 'VEC4')
        else:
            add(k, p, t_full, arr, 'VEC4')
    j['animations'] = [a for a in j['animations'] if a['name'] != 'stab']
    j['animations'].append(dict(name='stab', channels=channels, samplers=samplers))
    j['buffers'][0]['byteLength'] = len(binary)
    write_glb(path, j, binary)
    return len(channels)


def main():
    mpath = os.path.join(ROOT, 'manifest.json')
    man = json.load(open(mpath))
    for c in man['characters']:
        if not c['id'].startswith('mx_'):
            continue
        n = add_stab(os.path.join(ROOT, c['file']))
        c['animations']['stab'] = dict(duration=DURATION, loop=False, root_motion=dict(distance_m=[0.0, 0.0, 0.0]))
        print(c['id'], 'stab :', n, 'canaux')
    json.dump(man, open(mpath, 'w'), ensure_ascii=False, indent=1)
    if '--render' in sys.argv:
        import subprocess
        for t in (0.0, 0.14, 0.27, 0.45, 0.66):
            subprocess.run([sys.executable, os.path.join(os.path.dirname(__file__), 'verify_new_glb.py'),
                            os.path.join(ROOT, 'mx_remy.glb'), '/tmp/stab_%.2f.png' % t, 'stab', str(t), 'side'], check=False)


if __name__ == '__main__':
    main()
