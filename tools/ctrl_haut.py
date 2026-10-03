import sys; sys.path.insert(0,'.')
import numpy as np, cv2
from rig import *; from char import Char; from cast import CAST, label; from zoom import zoom
base = Base()
rows=[]
for n in sys.argv[1].split(','):
    c = Char(base, CAST[n])
    rows.append(zoom(c,[(n[:12]+' face',0,1.28,0.22,'front'),('dos',0,1.28,0.22,'back'),('3/4',0,1.28,0.22,'front'),('profil',0,1.28,0.22,'side')],size=300,yaw=0)) if False else None
    imgs=[label(c.render(view='front',size=300,center=np.array([0.12,1.27,0]),scale=300/0.5,cy=0.5,yaw=a),f'{n[:10]} {a}') for a in (0,35)]
    imgs.append(label(c.render(view='back',size=300,center=np.array([0.12,1.27,0]),scale=300/0.5,cy=0.5),'dos'))
    imgs.append(label(c.render(view='side',size=300,center=np.array([0.0,1.27,0]),scale=300/0.5,cy=0.5),'profil'))
    rows.append(np.hstack(imgs))
cv2.imwrite(sys.argv[2], np.vstack(rows))
