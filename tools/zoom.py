"""Rendus de contrôle zoomés : zoom(char, [(nom, cx, cy_m, demi_hauteur_m, vue)...]) -> image."""
import numpy as np, cv2
from rig import *
from char import Char
from cast import CAST, label

def zoom(c, zones, size=420, R=None, P=None, yaw=0):
    out = []
    for name, cx, cy, hh, view in zones:
        img = c.render(R, P, view=view, size=size, center=np.array([cx, cy, 0.0]), scale=size / (2 * hh), yaw=yaw, cy=0.5)
        out.append(label(img, name))
    return np.hstack(out)

if __name__ == '__main__':
    import sys
    base = Base()
    names = sys.argv[1].split(','); outp = sys.argv[2]
    zs = [('dos epaules', 0.0, 1.30, 0.28, 'back'), ('epaule g 3/4', 0.25, 1.30, 0.22, 'back'), ('dos taille', 0.0, 1.0, 0.28, 'back')]
    rows = [zoom(Char(base, CAST[n]), [(n + ' ' + z[0],) + z[1:] for z in zs]) for n in names]
    cv2.imwrite(outp, np.vstack(rows))
