"""Mesure le glissement des pieds : frames où le point le plus bas d'un pied (sommets pondérés Foot/ToeBase) touche le sol (<1 cm)
et où le pied avance en monde à plus de 0,3 m/s. Usage: python3 slide_check.py perso"""
import sys, numpy as np, anim
from rig import *; from char import Char; from cast import CAST
c = Char(Base(), CAST[sys.argv[1]]); sh = c.base.short
grp = [[sh.index(n) for n in ('LeftFoot', 'LeftToeBase', 'LeftToe_End')], [sh.index(n) for n in ('RightFoot', 'RightToeBase', 'RightToe_End')]]
m = c.mesh; dom = m['joints'][np.arange(len(m['pos'])), m['weights'].argmax(1)]
for n in ('walk', 'run', 'sprint'):
    ts, LR, LT = anim.sample(c, n); sole = c.sole; out = []
    low = np.zeros((len(ts), 2)); pz = np.zeros((len(ts), 2))
    for k in range(len(ts)):
        R, Pp = anim.fk(c, LR[k], LT[k]); pos = c.posed(R, Pp)[0]
        for f in (0, 1):
            sel = np.isin(dom, grp[f]); q = pos[sel]; i = q[:, 1].argmin(); low[k, f] = q[i, 1] - sole; pz[k, f] = Pp[grp[f][0], 2]   # cheville
    skate = []; ncont = 0
    for f in (0, 1):
        for k in range(len(ts) - 1):
            if low[k, f] < 0.01 and low[k + 1, f] < 0.01:
                ncont += 1; v = abs(pz[k + 1, f] - pz[k, f]) * 30
                if v > 0.5: skate.append(v)
    print(f'{sys.argv[1]} {n}: contacts {ncont} images, cheville >0,5 m/s en contact sur {len(skate)} ({100*len(skate)/max(ncont,1):.0f} %), max {max(skate) if skate else 0:.2f} m/s')
