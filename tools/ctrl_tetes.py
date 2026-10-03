import sys; sys.path.insert(0,'.')
import numpy as np, cv2
from rig import *; from char import Char; from cast import CAST, label
base = Base(); rows=[]
extra = {'test_rase': dict(CAST['garcon_enfant'], hair='rase')}
CAST.update(extra)
for n in sys.argv[1].split(','):
    c = Char(base, CAST[n]); H = c.mesh['pos'][:,1].max(); cy = H - 0.12; imgs=[]
    for v,a in (('front',0),('front',40),('side',0),('back',0),('back',35)):
        imgs.append(label(c.render(view=v,size=260,center=np.array([0.0,cy,0]),scale=260/0.40,cy=0.5,yaw=a),f'{n[:12]} {v}{a}'))
    rows.append(np.hstack(imgs))
cv2.imwrite(sys.argv[2], np.vstack(rows))
