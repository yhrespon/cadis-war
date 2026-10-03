"""Rendu logiciel simple (painter + ombrage plat) pour vérifier modèles et animations."""
import numpy as np, cv2
from rig import *

def skin_mats(R, P, ibm_inv_pos, ibm_rot):
    """matrices de skinning (J,4,4) = World * IBM ; IBM donnée par (rot bind^T, pos bind)"""
    J = len(R); S = np.zeros((J, 4, 4)); S[:, 3, 3] = 1
    # M = W_pose * inverse(W_bind)
    Rm = np.einsum('jab,jcb->jac', R, ibm_rot)       # R_pose * R_bind^T
    S[:, :3, :3] = Rm
    S[:, :3, 3] = P - np.einsum('jab,jb->ja', Rm, ibm_inv_pos)
    return S

def skin_vertices(pos, nrm, joints, weights, S):
    out = np.zeros_like(pos); on = np.zeros_like(nrm)
    for k in range(4):
        w = weights[:, k:k+1]
        if not w.any(): continue
        Sk = S[joints[:, k]]
        out += w * (np.einsum('nab,nb->na', Sk[:, :3, :3], pos) + Sk[:, :3, 3])
        on += w * np.einsum('nab,nb->na', Sk[:, :3, :3], nrm)
    return out, on

def render_tris(items, view='front', size=360, center=None, scale=None, bg=(235, 235, 240), yaw=0.0):
    """items: liste de (pos, nrm, idx, colors_per_tri(N,3)) -> image BGR"""
    img = np.full((size, size, 3), bg, np.uint8)
    allp = np.concatenate([it[0] for it in items])
    if center is None: center = (allp.min(0) + allp.max(0)) / 2
    if scale is None: scale = size * 0.9 / max(allp[:, 1].max() - allp[:, 1].min(), 1e-6)
    c, s = np.cos(np.radians(yaw)), np.sin(np.radians(yaw))
    Ry = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    if view == 'side': Ry = np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]]) @ Ry
    if view == 'back': Ry = np.array([[-1, 0, 0], [0, 1, 0], [0, 0, -1]]) @ Ry
    polys = []
    for pos, nrm, idx, col in items:
        p = (pos - center) @ Ry.T; n = nrm @ Ry.T
        tri = p[idx]; tn = n[idx].mean(1)
        tn /= np.linalg.norm(tn, axis=1, keepdims=True) + 1e-9
        light = np.array([0.3, 0.5, 0.8]); light /= np.linalg.norm(light)
        sh = 0.45 + 0.55 * np.clip(tn @ light, 0, 1)
        z = tri[:, :, 2].mean(1)
        xy = np.stack([size / 2 + tri[:, :, 0] * scale, size * 0.52 - tri[:, :, 1] * scale], -1)
        polys.append((z, xy, (col * sh[:, None]).clip(0, 255)))
    z = np.concatenate([q[0] for q in polys]); xy = np.concatenate([q[1] for q in polys]); col = np.concatenate([q[2] for q in polys])
    order = np.argsort(z)
    for i in order:
        cv2.fillConvexPoly(img, xy[i].astype(np.int32), tuple(int(v) for v in col[i][::-1]), cv2.LINE_8)
    return img

_texcache = {}
def tri_colors(mesh, tex_arr, tint=(1, 1, 1)):
    u = mesh['uv']; h, w = tex_arr.shape[:2]
    px = np.clip((u[:, 0] * w).astype(int), 0, w - 1); py = np.clip((u[:, 1] * h).astype(int), 0, h - 1)
    vc = tex_arr[py, px, :3].astype(np.float64) * np.array(tint)
    return vc[mesh['idx']].mean(1)


# ---------------------------------------------------------------- v3 : vrai z-buffer (C, ctypes)
import ctypes, subprocess
_HERE = os.path.dirname(os.path.abspath(__file__))
_LIB = None
def _lib():
    global _LIB
    if _LIB is None:
        so = os.path.join(_HERE, 'libzraster.so')
        src = os.path.join(_HERE, 'zraster.c')
        if not os.path.exists(so) or os.path.getmtime(so) < os.path.getmtime(src):
            subprocess.check_call(['gcc', '-O3', '-shared', '-fPIC', '-o', so, src, '-lm'])
        _LIB = ctypes.CDLL(so)
    return _LIB

def _view_matrix(view, yaw):
    c, s = np.cos(np.radians(yaw)), np.sin(np.radians(yaw))
    Ry = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    if view == 'side': Ry = np.array([[0, 0, 1], [0, 1, 0], [-1, 0, 0]]) @ Ry
    if view == 'back': Ry = np.array([[-1, 0, 0], [0, 1, 0], [0, 0, -1]]) @ Ry
    return Ry

def render_z(pos, nrm, uv, idx, tex, view='front', size=360, center=None, scale=None, yaw=0.0,
             bg=(235, 235, 240), ss=2, return_ids=False, cx_off=0.0, cy=0.52, pitch=0.0):
    """Rendu z-buffer orthographique avec texture réelle (atlas) ; ss = suréchantillonnage (antialiasing)."""
    lib = _lib(); S = size * ss
    if center is None: center = (pos.min(0) + pos.max(0)) / 2
    if scale is None: scale = size * 0.9 / max(pos[:, 1].max() - pos[:, 1].min(), 1e-6)
    Ry = _view_matrix(view, yaw)
    if pitch: Ry = rx(pitch) @ Ry
    p = (pos - center) @ Ry.T; n = nrm @ Ry.T
    sx = (S / 2 + cx_off * S + p[:, 0] * scale * ss).astype(np.float32); sy = (S * cy - p[:, 1] * scale * ss).astype(np.float32)
    sz = p[:, 2].astype(np.float32)
    f32 = lambda a: np.ascontiguousarray(a, np.float32)
    zb = np.full(S * S, -1e30, np.float32); img = np.zeros((S, S, 3), np.uint8); ids = np.full(S * S, -1, np.int32)
    img[:] = np.array(bg, np.uint8)[::-1]
    light = f32(np.array([0.3, 0.5, 0.8]) / np.linalg.norm([0.3, 0.5, 0.8]))
    tex = np.ascontiguousarray(tex[:, :, :3], np.uint8); th, tw = tex.shape[:2]
    ip = lambda a: a.ctypes.data_as(ctypes.c_void_p)
    arrs = [np.ascontiguousarray(idx.reshape(-1), np.int32), sx, sy, sz, f32(uv[:, 0]), f32(uv[:, 1]), f32(n[:, 0]), f32(n[:, 1]), f32(n[:, 2])]
    # la texture est RGB ; l'image de sortie est écrite en RGB puis convertie en BGR
    imgrgb = np.zeros((S, S, 3), np.uint8); imgrgb[:] = np.array(bg, np.uint8)[::-1][::-1]
    lib.raster(ctypes.c_int(S), ctypes.c_int(S), ctypes.c_int(len(idx)), *[ip(a) for a in arrs], ip(tex), ctypes.c_int(tw), ctypes.c_int(th),
               ip(light), ctypes.c_float(0.45), ip(zb), ip(imgrgb), ip(ids), ctypes.c_int(0))
    bgm = (zb < -1e29).reshape(S, S)
    imgrgb[bgm] = np.array(bg, np.uint8)[::-1][::-1]   # bg est donné en (R,G,B)
    out = cv2.cvtColor(imgrgb, cv2.COLOR_RGB2BGR)
    out = cv2.resize(out, (size, size), interpolation=cv2.INTER_AREA) if ss > 1 else out
    if return_ids: return out, ids.reshape(S, S)
    return out
