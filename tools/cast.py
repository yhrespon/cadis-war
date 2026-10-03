"""Distribution de test : 8 personnages (hommes, femmes, ado, enfants) + planche de rendu."""
import numpy as np, cv2, sys, time
from rig import *
from char import Char

CAST = {
 'homme_barbu': dict(gender='m', skin='mate', top=('tshirt', (190, 40, 40)), bottom=('jean', (50, 70, 120)), hair='court',
                     hair_color=(35, 25, 20), beard='complete', shoes=(50, 40, 35), build=(1.06, 1.06, 1.06, 1.0)),
 'femme_jupe':   dict(gender='f', skin='clair', top=('debardeur', (235, 235, 235)), bottom=('jupe', (30, 30, 60)), hair='longs',
                     hair_color=(190, 140, 70), shoes=(130, 30, 50)),
 'punk':         dict(gender='f', skin='beige', top=('veste', (25, 25, 28)), bottom=('cargo', (70, 85, 50)), hair='crete',
                     hair_color=(210, 40, 140), shoes=(30, 30, 30), gloves=True),
 'garcon_enfant':dict(gender='m', skin='ebene', top=('tshirt', (240, 200, 30)), bottom=('short', (50, 90, 160)), hair='coupe',
                     hair_color=(15, 12, 10), build=(0.62, 0.62, 0.62, 1.22)),
 'ado_casquette':dict(gender='m', skin='fonce', top=('manches', (70, 90, 70)), bottom=('jean', (35, 35, 45)), hair='court',
                     hair_color=(20, 15, 12), hat=('casquette', (200, 200, 205)), build=(0.93, 0.93, 0.93, 1.04)),
 'fille_queue':  dict(gender='f', skin='brun', top=('tshirt', (60, 150, 200)), bottom=('short', (240, 240, 240)), hair='queue',
                     hair_color=(25, 18, 14), build=(0.72, 0.72, 0.72, 1.15)),
 'femme_chignon':dict(gender='f', skin='beige', top=('veste', (120, 30, 40)), bottom=('jupe_longue', (40, 40, 48)), hair='chignon',
                     hair_color=(60, 35, 20), shoes=(35, 30, 30)),
 'homme_afro':   dict(gender='m', skin='ebene', top=('veste', (40, 60, 110)), bottom=('jean', (25, 25, 30)), hair='afro',
                     hair_color=(18, 14, 12), shoes=(60, 45, 30), build=(1.04, 1.05, 1.04, 1.0)),
 'ado_fille_longs':dict(gender='f', skin='mate', top=('manches', (225, 120, 40)), bottom=('jean', (70, 100, 150)), hair='longs',
                     hair_color=(45, 28, 20), shoes=(230, 230, 230), build=(0.94, 0.94, 0.94, 1.03)),
 'chauve_costume':dict(gender='m', skin='clair', top=('veste', (35, 35, 45)), bottom=('cargo', (45, 45, 55)), hair='chauve',
                     beard='complete', hair_color=(80, 60, 45), gloves=True, build=(1.1, 1.04, 1.1, 1.0)),
}

def label(img, t):
    cv2.putText(img, t, (6, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (30, 30, 30), 1, cv2.LINE_AA); return img

def sheet(chars, views=('front', 'back'), size=330, path='../previews/sheet.png', ncol=5):
    tiles = []
    H = max(c.mesh['pos'][:, 1].max() for c in chars.values())
    for name, c in chars.items():
        row = [label(c.render(view=v, size=size, scale=size * 0.86 / H, center=np.array([0, H / 2, 0])), name if v == views[0] else v) for v in views]
        tiles.append(np.hstack(row) if len(views) > 1 else row[0])
    rows = [np.hstack(tiles[i:i + ncol]) for i in range(0, len(tiles), ncol)]
    img = np.vstack([r if r.shape[1] == rows[0].shape[1] else np.pad(r, ((0, 0), (0, rows[0].shape[1] - r.shape[1]), (0, 0)), constant_values=235) for r in rows])
    cv2.imwrite(path, img); return img

if __name__ == '__main__':
    base = Base(); out = {}
    for n, s in CAST.items():
        t = time.time(); out[n] = Char(base, s); print(n, len(out[n].mesh['pos']), 'sommets', round(time.time() - t, 2), 's')
    sheet(out, views=('front',), path='../previews/sheet_front.png')
    sheet(out, views=('back',), path='../previews/sheet_back.png')
