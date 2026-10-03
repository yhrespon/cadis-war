"""Planche de contrôle : images clés d'animations. Usage: python3 sheet_anim.py perso anim1,anim2 sortie.png [view] [nframes]"""
import sys, numpy as np, cv2
from rig import *; from char import Char; from cast import CAST, label
import anim
def strip(c, name, n=6, size=200, view='side', yaw=0, H=1.9):
    ts, LR, LT = anim.sample(c, name); tiles = []
    for k in np.linspace(0, len(ts) - 1, n).astype(int):
        R, Pp = anim.fk(c, LR[k], LT[k])
        im = c.render(R, Pp, view=view, size=size, scale=size * 0.8 / H, center=np.array([0, 0.9, 0]), yaw=yaw, cy=0.55)
        tiles.append(label(im, f'{name} {k}/{len(ts)-1}'))
    return np.hstack(tiles)
if __name__ == '__main__':
    pers, names, out = sys.argv[1:4]; view = sys.argv[4] if len(sys.argv) > 4 else 'side'
    n = int(sys.argv[5]) if len(sys.argv) > 5 else 6
    c = Char(Base(), CAST[pers]); rows = [strip(c, a, n, view=view, yaw=(25 if view == 'front' else 0)) for a in names.split(',')]
    cv2.imwrite(out, np.vstack(rows))
