"""Animations procédurales pour le rig Mixamo (34 joints).

Convention : on spécifie pour chaque os une rotation MONDE ABSOLUE A_j (delta par rapport à la pose de bind,
exprimé en axes monde). Un os non spécifié hérite de A de son parent.
Rotation locale glTF : lrot_j = (A_p Wr[p])^T (A_j Wr[j]).   A = I partout -> pose de bind (T).
Axes : +x = gauche du perso, +y haut, +z devant.
  rx(+a) : le haut bascule vers l'avant ; une jambe/bras pendant « balance vers l'avant » avec rx(-a).
  ry(+a) : tourne vers la gauche du perso.
"""
import numpy as np
from rig import rx, ry, rz

I3 = np.eye(3)
FPS = 30

# ---- paramètres (vecteur plat) ------------------------------------------------------------
NAMES = (['hx', 'hy', 'hz', 'hpitch', 'hyaw', 'hroll', 'lean', 'twist', 'side', 'hdp', 'hdy', 'hds']
         + [f'{s}{k}' for s in ('aL_', 'aR_') for k in ('fwd', 'out', 'elb', 'cross')]
         + [f'{s}{k}' for s in ('lL_', 'lR_') for k in ('fwd', 'out', 'knee', 'foot')]
         + ['lift'])
IDX = {n: i for i, n in enumerate(NAMES)}
DEF = np.zeros(len(NAMES))
for s in ('aL_', 'aR_'): DEF[IDX[s + 'out']] = 5; DEF[IDX[s + 'elb']] = 12      # bras relâchés
for s in ('lL_', 'lR_'): DEF[IDX[s + 'out']] = 2

def P(**kw):
    v = DEF.copy()
    for k, x in kw.items(): v[IDX[k]] = x
    return v

def keys(*ks, loop=False):
    """ks = [(u, P(...)), ...] -> fonction u -> vecteur (interpolation cosinus)."""
    ks = sorted(ks, key=lambda k: k[0])
    if loop: ks = ks + [(ks[0][0] + 1.0, ks[0][1])]
    us = np.array([k[0] for k in ks]); vs = np.array([k[1] for k in ks])
    def f(u):
        if loop: u = u % 1.0
        if u <= us[0]: return vs[0]
        if u >= us[-1]: return vs[-1]
        i = np.searchsorted(us, u) - 1; t = (u - us[i]) / (us[i + 1] - us[i]); t = 0.5 - 0.5 * np.cos(np.pi * t)
        return vs[i] * (1 - t) + vs[i + 1] * t
    return f

# ---- solveur de pose ---------------------------------------------------------------------
def solve(c, v):
    """vecteur de paramètres -> (lrot (J,3,3), lt (J,3) en mètres, sans grounding)."""
    g = lambda n: v[IDX[n]]
    sh = c.base.short; J = len(sh); ix = {n: i for i, n in enumerate(sh)}
    A = [None] * J
    H = rx(g('hpitch')) @ ry(g('hyaw')) @ rz(g('hroll'))
    sp = lambda w: rx(g('lean') * w) @ ry(g('twist') * w) @ rz(g('side') * w)
    A[0] = I3; A[1] = H
    A[ix['Spine']] = H @ sp(0.30)
    A[ix['Spine1']] = H @ sp(0.60)
    S2 = H @ sp(1.0); A[ix['Spine2']] = S2
    N = S2 @ rx(g('hdp') * .4) @ ry(g('hdy') * .4) @ rz(g('hds') * .4)
    A[ix['Neck']] = N
    Hd = S2 @ rx(g('hdp')) @ ry(g('hdy')) @ rz(g('hds'))
    for n in ('Head', 'HeadTop_End'): A[ix[n]] = Hd
    for side, sg in (('L', -1), ('R', 1)):
        pre = 'a' + side + '_'
        fwd, out, elb, cr = g(pre + 'fwd'), g(pre + 'out'), g(pre + 'elb'), g(pre + 'cross')
        base = S2 @ ry(cr if side == 'R' else -cr)   # cross : vers la ligne médiane
        zz = rz(sg * (80 - out))
        full = 'Left' if side == 'L' else 'Right'
        for n in (full + 'Shoulder',): A[ix[n]] = S2
        A[ix[full + 'Arm']] = base @ rx(-fwd) @ zz
        fa = base @ rx(-(fwd + elb)) @ zz
        for n in (full + 'ForeArm', full + 'Hand') + tuple(f'{full}HandIndex{k}' for k in range(1, 5)):
            A[ix[n]] = fa
        # jambes (axe retourné : pendantes vers -y dans le bind)
        pre = 'l' + side + '_'
        lf, lo, kn, ft = g(pre + 'fwd'), g(pre + 'out'), g(pre + 'knee'), g(pre + 'foot')
        zl = rz(lo if side == 'L' else -lo)   # abduction (jambe pendante vers -y)
        up = H @ rx(-lf) @ zl
        sk = H @ rx(-(lf - kn)) @ zl
        ff = H @ rx(ft) @ zl
        A[ix[full + 'UpLeg']] = up; A[ix[full + 'Leg']] = sk
        for n in (full + 'Foot', full + 'ToeBase', full + 'Toe_End'): A[ix[n]] = ff
    lrot = np.zeros((J, 3, 3)); Wr = c.Wr; par = c.parent
    for j in range(J):
        Rj = A[j] @ Wr[j]
        if par[j] < 0: lrot[j] = Rj
        else: lrot[j] = (A[par[j]] @ Wr[par[j]]).T @ Rj
    lt = c.lt.copy(); lt[1] = lt[1] + np.array([g('hx'), g('hy'), g('hz')])
    return lrot, lt

def fk(c, lrot, lt):
    J = len(c.parent); R = np.zeros((J, 3, 3)); Pp = np.zeros((J, 3))
    for j in range(J):
        p = c.parent[j]
        if p < 0: R[j] = lrot[j]; Pp[j] = lt[j]
        else: R[j] = R[p] @ lrot[j]; Pp[j] = Pp[p] + R[p] @ lt[j]
    return R, Pp

def frame(c, v, ground='mesh', sole=None):
    """Retourne (lrot, lt) avec grounding : le point le plus bas du maillage est posé à y=sole (+ lift)."""
    lrot, lt = solve(c, v)
    if ground == 'mesh':
        if sole is None: sole = _init_sole(c)
        R, Pp = fk(c, lrot, lt)
        lo = c.posed(R, Pp)[0][:, 1].min()
        lt[1, 1] += sole - lo
    lt[1, 1] += v[IDX['lift']] * 0.01
    return lrot, lt

# ---- bibliothèque d'animations ------------------------------------------------------------
S = np.sin; C = np.cos; D2R = np.pi / 180

def cyc_walk(A, K, arm, elb, lean, bob_roll=3, twist=5):
    def f(u):
        ph = 2 * np.pi * u; sL = S(ph); sR = -sL
        legs = {}
        for s, sn in (('L', sL), ('R', sR)):
            cs = C(ph) if s == 'L' else -C(ph)
            legs['l' + s + '_fwd'] = A * sn
            legs['l' + s + '_knee'] = K * max(0, cs) ** 0.5 + 6   # genou plié plus longtemps : le pied ne touche qu'en fin de bascule
            legs['l' + s + '_foot'] = 28 * max(0, -sn) * (K / 60) - 10 * max(0, sn) * min(1, 60 / K)   # attaque talon, puis pied à plat, puis décollage
        return P(hy=0, hz=0, lean=lean, twist=twist * C(ph), hyaw=-twist * .8 * C(ph), hroll=bob_roll * S(ph) * 0.5,
                 aL_fwd=-arm * sL, aR_fwd=-arm * sR, aL_elb=elb + arm * .3 * max(0, -sL), aR_elb=elb + arm * .3 * max(0, -sR),
                 hdy=twist * .6 * -C(ph), lift=0, **legs)
    return f

def _ss(x): x = min(max(x, 0.0), 1.0); return x * x * (3 - 2 * x)

def cyc_walk2(A, K, arm, elb, lean, bob_roll=3, twist=5, duty=0.62):
    """Marche à appui quasi linéaire : pendant l'appui, l'angle de hanche décroît à vitesse ~constante (le pied recule au sol
    à la vitesse du bassin -> pas de patinage), le pied oscillant ne se pose qu'en fin de ralentissement (attaque talon douce)."""
    def leg(p):
        p %= 1.0
        if p < duty:                                   # appui
            s_ = p / duty
            fwd = A * (1 - 2 * (0.9 * s_ + 0.1 * (1 - np.cos(np.pi * s_)) / 2))
            knee = 6 + 9 * S(np.pi * min(1, s_ / 0.45)) * (s_ < 0.45)
            foot = -10 * (1 - _ss(s_ / 0.2)) * min(1, 60 / K) + 28 * (K / 60) * _ss((s_ - 0.72) / 0.28)
        else:                                          # phase oscillante
            q = (p - duty) / (1 - duty)
            e = 0.25 * _ss(q) + 0.75 * (1 - (1 - q) ** 3)
            fwd = A * (-1 + 2 * e)
            knee = 6 + K * S(np.pi * min(1.0, q / 0.78) ** 0.7)   # genou redressé avant la pose : plus de balayage du pied à l'atterrissage
            foot = 28 * (K / 60) * (1 - _ss(q / 0.35)) - 10 * _ss((q - 0.6) / 0.4) * min(1, 60 / K)
        return fwd, knee, foot
    def f(u):
        ph = 2 * np.pi * u; sL = S(ph); sR = -sL; legs = {}
        for s, off in (('L', 0.2), ('R', 0.7)):        # appui gauche [0.2, 0.82], droit [0.7, 1.32]
            fw, kn, ft = leg(u - off)
            legs['l' + s + '_fwd'] = fw; legs['l' + s + '_knee'] = kn; legs['l' + s + '_foot'] = ft
        return P(hy=0, hz=0, lean=lean, twist=twist * C(ph), hyaw=-twist * .8 * C(ph), hroll=bob_roll * S(ph) * 0.5,
                 aL_fwd=-arm * sL, aR_fwd=-arm * sR, aL_elb=elb + arm * .3 * max(0, -sL), aR_elb=elb + arm * .3 * max(0, -sR),
                 hdy=twist * .6 * -C(ph), lift=0, **legs)
    return f

def _idle(u):
    b = S(2 * np.pi * u)
    return P(hy=0.004 * b, lean=1.2 * b, hdp=-1.0 * b, hroll=1.2 * S(2 * np.pi * u + 1), hx=0.01 * S(2 * np.pi * u + 1),
             aL_fwd=2 * b, aR_fwd=2 * b, aL_out=7, aR_out=7, lL_fwd=0, lR_fwd=2, lL_knee=3 + b, lR_knee=5)

def _crouch():
    st = P(hz=-0.10, lean=28, hdp=-14, aL_fwd=30, aR_fwd=30, aL_elb=60, aR_elb=60,
           lL_fwd=78, lR_fwd=78, lL_knee=132, lR_knee=132, lL_foot=0, lR_foot=0, lL_out=6, lR_out=6)
    return keys((0.0, P()), (0.30, st), (0.70, st), (1.0, P()))

def _jump():
    crouch = P(hz=-0.05, lean=22, aL_fwd=-35, aR_fwd=-35, aL_elb=20, aR_elb=20, lL_fwd=55, lR_fwd=55, lL_knee=100, lR_knee=100)
    push = P(lean=6, aL_fwd=50, aR_fwd=50, aL_out=15, aR_out=15, lL_fwd=5, lR_fwd=5, lL_knee=5, lR_knee=5, lL_foot=40, lR_foot=40, lift=0)
    air = P(lean=8, aL_fwd=60, aR_fwd=60, aL_out=30, aR_out=30, aL_elb=20, aR_elb=20, lL_fwd=35, lR_fwd=10, lL_knee=70, lR_knee=40,
            lL_foot=10, lR_foot=15, lift=0)
    land = P(hz=-0.05, lean=20, aL_fwd=20, aR_fwd=20, lL_fwd=60, lR_fwd=60, lL_knee=105, lR_knee=105)
    f = keys((0, P()), (0.18, crouch), (0.30, push), (0.40, air), (0.68, air), (0.82, land), (1.0, P()))
    def g(u):
        v = f(u)
        h = 0.0
        if 0.30 <= u <= 0.76: t = (u - 0.30) / 0.46; h = 4 * t * (1 - t) * 75      # cm : saut ~0.75 m de pied
        v = v.copy(); v[IDX['lift']] = h; return v
    return g

def _roll():
    stand = P(); pre = P(lean=30, aL_fwd=40, aR_fwd=40, aL_elb=60, aR_elb=60, lL_fwd=60, lR_fwd=60, lL_knee=110, lR_knee=110, hz=0.05)
    tuck = lambda p: P(hpitch=p, lean=60, hdp=40, aL_fwd=80, aR_fwd=80, aL_elb=80, aR_elb=80, lL_fwd=105, lR_fwd=105,
                       lL_knee=140, lR_knee=140, aL_out=20, aR_out=20)
    return keys((0, stand), (0.18, pre), (0.28, tuck(60)), (0.45, tuck(180)), (0.62, tuck(300)), (0.76, tuck(390)),
                (0.88, P(hpitch=360, lean=25, lL_fwd=60, lR_fwd=60, lL_knee=110, lR_knee=110, aL_fwd=30, aR_fwd=30)), (1.0, P(hpitch=360)))

def _punch():
    guard = P(lean=6, twist=-10, hyaw=-10, hdp=8, aL_fwd=55, aL_elb=105, aL_out=10, aL_cross=25, aR_fwd=50, aR_elb=115, aR_out=10, aR_cross=30,
              lL_fwd=22, lL_knee=22, lR_fwd=-18, lR_knee=14, lL_out=8, lR_out=10)
    wind = P(lean=6, twist=-30, hyaw=-14, hdp=8, aL_fwd=55, aL_elb=105, aL_cross=25, aR_fwd=40, aR_elb=130, aR_out=15, aR_cross=20,
             lL_fwd=22, lL_knee=22, lR_fwd=-20, lR_knee=14, lL_out=8, lR_out=10)
    hit = P(lean=10, twist=35, hyaw=18, hdp=8, aL_fwd=55, aL_elb=110, aL_cross=30, aR_fwd=90, aR_elb=0, aR_out=3, aR_cross=8,
            lL_fwd=25, lL_knee=30, lR_fwd=-12, lR_knee=26, lL_out=8, lR_out=10)
    return keys((0, guard), (0.2, wind), (0.38, hit), (0.52, hit), (0.8, guard), (1.0, guard))

def _kick():
    st = P(lean=4, aL_fwd=40, aL_elb=90, aL_out=25, aR_fwd=20, aR_elb=80, aR_out=35, lL_fwd=8, lL_knee=14, lR_fwd=-8, lR_knee=20)
    chamber = P(lean=-8, aL_fwd=40, aL_elb=90, aL_out=40, aR_fwd=20, aR_out=45, lL_fwd=0, lL_knee=12, lR_fwd=80, lR_knee=105, lR_foot=10, hroll=-3)
    hit = P(lean=-18, aL_fwd=50, aL_out=55, aR_fwd=-10, aR_out=50, lL_fwd=-4, lL_knee=14, lR_fwd=92, lR_knee=4, lR_foot=-30, hz=-0.03)
    return keys((0, st), (0.25, chamber), (0.40, hit), (0.55, hit), (0.75, chamber), (1.0, st))

def _shoot():
    ready = P(lean=4, aR_fwd=60, aR_elb=70, aR_cross=8, aL_fwd=55, aL_elb=85, aL_cross=14, lL_fwd=16, lL_knee=14, lR_fwd=-14, lR_knee=12, hdp=-2)
    aim = P(lean=3, twist=-6, aR_fwd=88, aR_elb=6, aR_cross=7, aR_out=4, aL_fwd=84, aL_elb=34, aL_cross=14, lL_fwd=16, lL_knee=14, lR_fwd=-14, lR_knee=12)
    rec = P(lean=1, twist=-6, aR_fwd=98, aR_elb=16, aR_cross=7, aL_fwd=93, aL_elb=44, aL_cross=14, lL_fwd=16, lL_knee=15, lR_fwd=-14, lR_knee=14, hdp=-3, hz=-0.01)
    return keys((0, ready), (0.2, aim), (0.3, aim), (0.35, rec), (0.45, aim), (0.55, aim), (0.6, rec), (0.7, aim), (1.0, ready))

def _reload():
    ready = P(lean=4, aR_fwd=65, aR_elb=75, aR_cross=14, aL_fwd=60, aL_elb=80, aL_cross=14, lL_fwd=14, lL_knee=14, lR_fwd=-12, lR_knee=12, hdp=0)
    down = P(lean=6, aR_fwd=50, aR_elb=88, aR_cross=18, aL_fwd=20, aL_elb=100, aL_cross=8, aL_out=18, lL_fwd=14, lL_knee=14, lR_fwd=-12, lR_knee=12, hdp=14)
    mag = P(lean=6, aR_fwd=52, aR_elb=88, aR_cross=18, aL_fwd=45, aL_elb=120, aL_cross=20, aL_out=10, lL_fwd=14, lL_knee=14, lR_fwd=-12, lR_knee=12, hdp=16)
    slap = P(lean=6, aR_fwd=52, aR_elb=88, aR_cross=18, aL_fwd=52, aL_elb=95, aL_cross=22, lL_fwd=14, lL_knee=14, lR_fwd=-12, lR_knee=12, hdp=14)
    return keys((0, ready), (0.2, down), (0.4, mag), (0.55, down), (0.7, slap), (0.82, ready), (1.0, ready))

def _damage():
    hit = P(hz=-0.07, lean=-22, twist=14, hdp=-18, hdy=-12, aL_fwd=10, aL_out=45, aL_elb=40, aR_fwd=30, aR_out=60, aR_elb=35,
            lL_fwd=10, lL_knee=25, lR_fwd=-14, lR_knee=22)
    rec = P(hz=-0.03, lean=12, hdp=8, aL_fwd=18, aR_fwd=18, aL_elb=35, aR_elb=35, lL_fwd=12, lL_knee=22, lR_fwd=-10, lR_knee=18)
    return keys((0, P()), (0.18, hit), (0.45, hit), (0.75, rec), (1.0, P()))

def _death():
    s1 = P(hz=-0.06, lean=-16, hdp=-14, aL_fwd=10, aL_out=40, aR_fwd=20, aR_out=50, lL_fwd=6, lL_knee=30, lR_fwd=-8, lR_knee=28)
    s2 = P(hz=-0.45, hpitch=-55, lean=-8, hdp=-18, aL_fwd=-20, aL_out=60, aL_elb=20, aR_fwd=-10, aR_out=70, aR_elb=25,
           lL_fwd=25, lL_knee=75, lR_fwd=0, lR_knee=55)
    s3 = P(hz=-0.5, hpitch=-90, lean=-4, hdp=-6, hdy=12, aL_fwd=-30, aL_out=70, aL_elb=10, aR_fwd=-20, aR_out=95, aR_elb=15,
           lL_fwd=8, lL_knee=14, lR_fwd=4, lR_knee=6, lL_out=10, lR_out=14)
    return keys((0, P()), (0.12, s1), (0.45, s2), (0.7, s3), (1.0, s3))

def _drive():
    def f(u):
        st = 8 * S(2 * np.pi * u * 2); sh = 2 * S(2 * np.pi * u)
        return P(hy=-0.0, hz=-0.12, lean=-4, hdp=-4 + sh * 0.3, hdy=st * .5,
                 aL_fwd=50, aL_elb=75 + st * .5, aL_out=3, aL_cross=24, aR_fwd=50, aR_elb=75 - st * .5, aR_out=3, aR_cross=24,   # mains resserrées sur un volant de ~0,33 m (v6e)
                 lL_fwd=88, lL_knee=88, lL_foot=0, lR_fwd=84, lR_knee=82 - 3 * S(2 * np.pi * u * 3), lR_foot=-6, lL_out=4, lR_out=4)
    return f

def _climb():
    def f(u):
        ph = 2 * np.pi * u; a = S(ph); b = -a
        # alternance bras/jambes : bras montent, jambe opposée monte
        return P(hy=0.0, hz=0.03, lean=4, twist=6 * C(ph), hdp=-18,
                 aL_fwd=150 + 20 * a, aL_out=10, aL_elb=45 - 40 * a, aL_cross=8,
                 aR_fwd=150 + 20 * b, aR_out=10, aR_elb=45 - 40 * b, aR_cross=8,
                 lL_fwd=35 + 30 * b, lL_knee=60 + 40 * b, lR_fwd=35 + 30 * a, lR_knee=60 + 40 * a, hx=0.015 * a,
                 lL_out=6, lR_out=6, lift=10 + 3 * S(2 * ph))
    return f

def _interact():
    reach = P(lean=14, twist=-8, hdp=10, aR_fwd=82, aR_elb=30, aR_cross=-4, aR_out=8, aL_fwd=10, aL_elb=25, lL_fwd=10, lL_knee=14, lR_fwd=-6, lR_knee=10)
    press = P(lean=17, twist=-10, hdp=12, aR_fwd=90, aR_elb=10, aR_cross=-4, aR_out=8, aL_fwd=12, aL_elb=25, lL_fwd=12, lL_knee=18, lR_fwd=-6, lR_knee=12)
    return keys((0, P()), (0.25, reach), (0.45, press), (0.6, reach), (1.0, P()))

def _dance():
    def f(u):
        ph = 2 * np.pi * u; b = S(2 * ph); s = S(ph)
        return P(hy=-0.015 * (1 - C(2 * ph)) / 2 * 0 + 0.0, hx=0.05 * s, hroll=6 * s, hyaw=12 * S(ph), twist=-10 * S(ph), side=-4 * s, hdp=-4, hds=5 * s,
                 aL_fwd=60 + 55 * max(0, S(ph)) + 8 * b, aL_out=35 + 30 * max(0, S(ph)), aL_elb=70 - 40 * max(0, S(ph)),
                 aR_fwd=60 + 55 * max(0, -S(ph)) - 8 * b, aR_out=35 + 30 * max(0, -S(ph)), aR_elb=70 - 40 * max(0, -S(ph)),
                 lL_fwd=10 + 8 * s, lR_fwd=10 - 8 * s, lL_knee=26 + 22 * max(0, -C(2 * ph)) + 10 * max(0, s), lR_knee=26 + 22 * max(0, -C(2 * ph)) + 10 * max(0, -s),
                 lL_out=10 + 8 * max(0, s), lR_out=10 + 8 * max(0, -s))
    return f

# nom -> (fonction u->P, durée s, boucle, grounding)
ANIMS = {
    'idle':   (_idle, 3.0, True, 'mesh'),
    'walk':   (cyc_walk2(26, 42, 24, 20, 4), 1.0, True, 'mesh'),
    'run':    (cyc_walk(52, 100, 52, 85, 13, bob_roll=5, twist=9), 0.66, True, 'mesh'),
    'sprint': (cyc_walk(62, 112, 66, 90, 22, bob_roll=6, twist=11), 0.52, True, 'mesh'),
    'jump':   (_jump(), 1.0, False, 'mesh'),
    'crouch': (_crouch(), 1.2, False, 'mesh'),
    'roll':   (_roll(), 1.1, False, 'mesh'),
    'punch':  (_punch(), 0.9, False, 'mesh'),
    'kick':   (_kick(), 1.1, False, 'mesh'),
    'shoot':  (_shoot(), 1.4, False, 'mesh'),
    'reload': (_reload(), 2.2, False, 'mesh'),
    'damage': (_damage(), 0.9, False, 'mesh'),
    'death':  (_death(), 2.0, False, 'mesh'),
    'drive':  (_drive(), 2.0, True, 'mesh'),
    'climb':  (_climb(), 1.2, True, 'none'),
    'interact': (_interact(), 1.4, False, 'mesh'),
    'dance':  (_dance(), 1.6, True, 'mesh'),
}

# ---- déplacement (root motion) -------------------------------------------------------------
def _sm(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
def _bump(u, a, b): return np.sin(np.pi * np.clip((u - a) / (b - a), 0, 1)) ** 2
# nom -> fonction u -> (x, y, z) en mètres, déplacement cumulé de la racine (hors 'lock')
MOTION = {
    'jump':   lambda u: (0, 0, 1.0 * _sm((u - 0.30) / 0.46)),
    'roll':   lambda u: (0, 0, 2.4 * _sm((u - 0.22) / 0.63)),
    'punch':  lambda u: (0, 0, 0.14 * _bump(u, 0.10, 0.62)),
    'kick':   lambda u: (0, 0, 0.18 * _bump(u, 0.10, 0.70)),
    'damage': lambda u: (0, 0, -0.30 * _sm((u - 0.05) / 0.35)),
    'death':  lambda u: (0, 0, -0.55 * _sm((u - 0.08) / 0.45)),
    'climb':  lambda u: (0, 0.60 * u, 0),     # 0,60 m par cycle (1,2 s) = 0,5 m/s ; échelons ~0,30 m
}
LOCK = ('walk', 'run', 'sprint')              # pieds verrouillés au sol : vitesse déduite de la marche

def _foot_lock_z(c, LR, LT, dt):
    """Déplacement z cumulé (n+1 valeurs, cycle fermé) tel que le pied d'appui ne glisse pas."""
    sh = c.base.short; fl, fr = sh.index('LeftFoot'), sh.index('RightFoot')
    n = len(LR) - 1                                    # dernière image = copie de la première
    zs = np.zeros((n, 2)); ys = np.zeros((n, 2))
    for k in range(n):
        _, Pp = fk(c, LR[k], LT[k]); zs[k] = (Pp[fl, 2], Pp[fr, 2]); ys[k] = (Pp[fl, 1], Pp[fr, 1])
    dz = (np.roll(zs, -1, 0) - zs); ymid = (ys + np.roll(ys, -1, 0)) / 2
    # appui = pied qui recule le plus vite par rapport au bassin (vitesse ~0 aux changements d'appui -> pas de saut)
    v = -dz.min(1) / dt
    v = (np.roll(v, 1) + 2 * v + np.roll(v, -1)) / 4                                       # lissage cyclique
    return np.concatenate([[0], np.cumsum(v * dt)])

def sample(c, name, fps=FPS):
    """-> (times (n,), lrot (n,J,3,3), lt (n,J,3)). lt[:,0] = déplacement de la racine (_rootJoint).
    Boucle : image finale (t = durée) = pose initiale + déplacement total du cycle."""
    f, dur, loop, gr = ANIMS[name]
    nf = int(round(dur * fps)); n = nf + 1
    ts, LR, LT = [], [], []
    for i in range(n):
        u = i / nf
        lrot, lt = frame(c, f(u), ground=gr)
        ts.append(u * dur); LR.append(lrot); LT.append(lt)
    LR = np.array(LR); LT = np.array(LT); ts = np.array(ts)
    if name in LOCK:
        z = _foot_lock_z(c, LR, LT, 1.0 / fps); LT[:, 0, 2] = z
    elif name in MOTION:
        for i in range(n): LT[i, 0] = np.array(MOTION[name](i / nf), float)
    return ts, LR, LT

def motion_info(c, name):
    ts, LR, LT = sample(c, name); d = LT[-1, 0] - LT[0, 0]; dur = ts[-1]
    info = dict(distance_m=[round(float(x), 3) for x in d])
    if ANIMS[name][2] and np.linalg.norm(d) > 1e-3: info['speed_mps'] = [round(float(x) / dur, 3) for x in d]
    return info

def _init_sole(c):
    """Hauteur du point le plus bas du maillage en pose de bind (semelle de référence)."""
    if not hasattr(c, 'sole'): c.sole = c.mesh['pos'][:, 1].min()
    return c.sole
