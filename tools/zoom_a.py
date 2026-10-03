import sys, numpy as np, cv2
from rig import *; from char import Char; from cast import CAST, label; from zoom import zoom
base = Base()
names = sys.argv[1].split(','); out = sys.argv[2]
zs = [('epaule face', 0.22, 1.30, 0.16, 'front'), ('epaule dos', 0.22, 1.30, 0.16, 'back'), ('entrejambe cote', 0.0, 0.85, 0.20, 'side'), ('entrejambe dos', 0.0, 0.85, 0.20, 'back')]
rows = [zoom(Char(base, CAST[n]), [(n[:10] + ' ' + z[0],) + z[1:] for z in zs], size=300) for n in names]
cv2.imwrite(out, np.vstack(rows))
