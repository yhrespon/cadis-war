"""Contrôle des têtes : face / 3/4 / profil / dos pour des personnages donnés."""
import numpy as np, cv2, sys
from rig import *
from char import Char
from cast import CAST
from zoom import zoom
if __name__ == '__main__':
    base = Base(); rows = []
    for n in sys.argv[1].split(','):
        c = Char(base, CAST[n]); H = c.mesh['pos'][:, 1].max(); cy = H - 0.115
        rows.append(zoom(c, [(n + ' face', 0, cy, 0.14, 'front'), ('3/4', 0, cy, 0.14, 'front'), ('profil', 0, cy, 0.14, 'side'), ('dos', 0, cy, 0.14, 'back')], size=300, yaw=0)[:, :])
    cv2.imwrite(sys.argv[2], np.vstack(rows))
