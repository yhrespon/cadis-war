import numpy as np, cv2
from rig import *
from render import render_tris, render_z, skin_vertices
from chargen import *

class Char:
    def __init__(self, base, spec):
        self.spec = spec; self.base = base
        A, parts, M, names = build(base, spec)
        self.A = A
        self.mesh, self.Wp = finalize(base, A, parts, M, names, spec)
        self.parent = base.parent; self.Wr = base.Wr; self.lr = base.lr
        J = len(self.parent)
        self.lt = np.zeros((J, 3))
        for j in range(J):
            p = self.parent[j]
            self.lt[j] = self.Wp[j] if p < 0 else self.Wr[p].T @ (self.Wp[j] - self.Wp[p])
        # IBM (J,4,4) = inverse(bind world)
        self.ibm = np.zeros((J, 4, 4)); 
        for j in range(J):
            R = self.Wr[j]; self.ibm[j, :3, :3] = R.T; self.ibm[j, :3, 3] = -R.T @ self.Wp[j]; self.ibm[j, 3, 3] = 1
        u = self.mesh['uv']; h, w = A.color.shape[:2]
        px = np.clip((u[:, 0] * w).astype(int), 0, w - 1); py = np.clip((u[:, 1] * h).astype(int), 0, h - 1)
        self.vcol = A.color[py, px].astype(float)

    def skin_mats(self, R, P):
        J = len(R); S = np.zeros((J, 4, 4)); S[:, 3, 3] = 1
        W = np.zeros((J, 4, 4)); W[:, :3, :3] = R; W[:, :3, 3] = P; W[:, 3, 3] = 1
        return np.einsum('jab,jbc->jac', W, self.ibm)

    def posed(self, R=None, P=None):
        m = self.mesh
        if R is None: return m['pos'], m['nrm']
        S = self.skin_mats(R, P)
        return skin_vertices(m['pos'], m['nrm'], m['joints'], m['weights'], S)

    def render(self, R=None, P=None, view='front', size=360, center=None, scale=None, yaw=0, painter=False, **kw):
        pos, nrm = self.posed(R, P)
        idx = self.mesh['idx']
        if painter:   # ancien rendu (tri par profondeur moyenne), gardé pour comparaison
            return render_tris([(pos, nrm, idx, self.vcol[idx].mean(1))], view, size, center, scale, yaw=yaw)
        return render_z(pos, nrm, self.mesh['uv'], idx, self.A.color, view, size, center, scale, yaw=yaw, **kw)
