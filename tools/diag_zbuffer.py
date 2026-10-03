"""Diagnostic A bis : painter vs z-buffer sur trois zones (ceinture, bas de jean, tête)."""
import numpy as np, cv2, sys
from rig import *
from char import Char
from cast import CAST, label

def zones(c, size=420, painter=False):
    zs = [('torse/ceinture', [0, 1.15, 0], 4.0), ('bas jeans/bottes', [0, 0.30, 0], 5.0), ('tete', [0, 1.50, 0], 6.0)]
    out = []
    for name, ctr, k in zs:
        img = c.render(view='front', size=size, center=np.array(ctr), scale=size * k * 0.5 / 1.0 * 0.01 * 100 / 2.0 if False else size / (0.5 if k == 4 else 0.38 if k == 5 else 0.32), painter=painter)
        out.append(label(img, ('painter ' if painter else 'z-buffer ') + name))
    return np.hstack(out)

if __name__ == '__main__':
    base = Base(); c = Char(base, CAST['homme_barbu'])
    img = np.vstack([zones(c, painter=True), zones(c, painter=False)])
    cv2.imwrite('../previews/diag_zbuffer_v1.png', img); print(img.shape)
