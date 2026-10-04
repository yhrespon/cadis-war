#!/usr/bin/env python3
"""Convertit les FBX Mixamo (humains) en GLB dans godot_project/characters/ et met à jour manifest.json.
Les 10 anciens personnages restent dans le manifest avec "legacy": true ; manifest["use_legacy"] (false par défaut) les réactive.
Usage : python3 tools/build_mixamo_characters.py <dossier_fbx>   (fichiers : Remy.fbx Brute.fbx Eve_By_J_Gonzales.fbx Ch21_nonPBR.fbx)"""
import json, os, sys, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fbx2glb as X

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot_project', 'characters')
CHARS = [
    # id, fbx, taille (m), genre, libellé, pièces à ignorer
    ('mx_remy', 'Remy.fbx', 1.80, 'm', 'Remy', ()),
    ('mx_brute', 'Brute.fbx', 1.92, 'm', 'Brute', ('BattleAxe',)),
    ('mx_eve', 'Eve_By_J_Gonzales.fbx', 1.68, 'f', 'Eve (pirate de l\'espace)', ()),
    ('mx_ch21', 'Ch21_nonPBR.fbx', 1.80, 'f', 'Ch21', ()),
]
TINT_RULES = {'top': ('Top', 'Shirt'), 'bottom': ('Bottom', 'Pants'), 'hair': ('Hair',)}

def tint_map(info):
    out = {'top': [], 'bottom': [], 'hair': []}
    for mname, mi in info['materials'].items():
        for k, keys in TINT_RULES.items():
            if any(x in mi['mesh'] or x in mname for x in keys): out[k].append(mname)
    return {k: v for k, v in out.items() if v}

def main(fbx_dir):
    mpath = os.path.join(ROOT, 'manifest.json')
    man = json.load(open(mpath))
    old = [c for c in man['characters'] if c.get('source') != 'mixamo']
    for c in old: c['legacy'] = True
    new = []
    for cid, fbx, h, g, label, skip in CHARS:
        entry, info = X.convert(os.path.join(fbx_dir, fbx), cid, h, g, ROOT, 22000, skip)
        entry['label'] = label
        entry['tint_materials'] = tint_map(info)
        entry['stats'] = dict(tris=info['tris_after'], tris_fbx=info['tris_before'], bones=info['bones'], size_mb=info['size_mb'])
        new.append(entry)
        print(cid, json.dumps(entry['stats']), 'tint', entry['tint_materials'])
    man['characters'] = new + old
    man['use_legacy'] = False
    man['credit_mixamo'] = "Personnages Mixamo (Adobe) : Remy, Brute, Eve By J. Gonzales, Ch21 — Adobe Mixamo, usage libre dans les jeux (voir conditions Adobe/Mixamo)."
    json.dump(man, open(mpath, 'w'), indent=1, ensure_ascii=False)

if __name__ == '__main__':
    main(sys.argv[1])
