import sys; sys.path.insert(0,'.')
import numpy as np, cv2
from rig import *; from char import Char; from cast import CAST, label
base = Base(); rows=[]
for n in sys.argv[1].split(','):
    c = Char(base, CAST[n]); imgs=[]
    for v,a in (('front',0),('front',40),('back',0),('side',0)):
        imgs.append(label(c.render(view=v,size=300,center=np.array([0.0,0.82,0]),scale=300/0.5,cy=0.5,yaw=a),f'{n[:10]} {v}{a}'))
    rows.append(np.hstack(imgs))
cv2.imwrite(sys.argv[2], np.vstack(rows))
