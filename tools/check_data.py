#!/usr/bin/env python3
"""Vérification STATIQUE des données (villes, missions) — ne remplace pas un test dans Godot.
Contrôle : POI dans les limites et sur des blocs distincts, POI référencés par les missions présents dans la ville de la mission,
prérequis existants, chaîne de déblocage des villes atteignable depuis Port-Alpha, registre cohérent.
Usage : python3 tools/check_data.py  (depuis la racine du projet)"""
import re, glob, json, os
D = 'godot_project/data/'
bad = 0
def err(*a):
    global bad; bad += 1; print('ERREUR', *a)
cities = {}
for f in glob.glob(D + 'cities/*.tres'):
    t = open(f).read()
    cid = re.search(r'^id = "(\w+)"', t, re.M).group(1)
    bx = int(re.search(r'^blocks_x = (\d+)', t, re.M).group(1)) if re.search(r'^blocks_x', t, re.M) else 6
    bz = int(re.search(r'^blocks_z = (\d+)', t, re.M).group(1)) if re.search(r'^blocks_z', t, re.M) else 6
    pois = {k: (int(x), int(z)) for k, x, z in re.findall(r'"(\w+)": Vector2i\((\d+), (\d+)\)', t)}
    cities[cid] = dict(bx=bx, bz=bz, pois=pois)
for cid, c in cities.items():
    seen = {}
    for k, (x, z) in c['pois'].items():
        if not (0 <= x < c['bx'] and 0 <= z < c['bz']): err(cid, 'POI hors limites', k, (x, z))
        if (x, z) in seen: err(cid, 'POI sur le même bloc', k, seen[(x, z)], (x, z))
        seen[(x, z)] = k
    for need in (('spawn', 'depot', 'far_a', 'hideout_a', 'hideout_b', 'hideout_c') if cid == 'secret_site' else ('spawn', 'hospital', 'travel', 'shop')):
        if need not in c['pois']: err(cid, 'POI obligatoire manquant', need)
missions = {}
for f in glob.glob(D + 'missions/*.tres'):
    t = open(f).read()
    mid = re.search(r'^id = "(\w+)"', t, re.M).group(1)
    city = re.search(r'^city = "(\w+)"', t, re.M).group(1)
    req = re.search(r'^requires = \[(.*?)\]', t, re.M)
    req = re.findall(r'"(\w+)"', req.group(1)) if req else []
    unl = re.search(r'^unlocks_city = "(\w*)"', t, re.M)
    cat = re.search(r'^category = "(\w+)"', t, re.M)
    refs = set(re.findall(r'"(?:poi|from_poi|car_poi|flee_to)": "(\w+)"', t))
    for lst in re.findall(r'"pois": \[(.*?)\]', t): refs |= set(re.findall(r'"(\w+)"', lst))
    missions[mid] = dict(city=city, req=req, unl=unl.group(1) if unl else '', cat=cat.group(1) if cat else 'main', refs=refs)
reg = json.load(open(D + 'registry.json'))
for mid, m in missions.items():
    if m['city'] not in cities: err(mid, 'ville inconnue', m['city']); continue
    for r in m['refs']:
        if r not in cities[m['city']]['pois']: err(mid, 'POI absent de', m['city'], r)
    for r in m['req']:
        if r not in missions: err(mid, 'prérequis inconnu', r)
        elif missions[r]['city'] != m['city'] and not (missions[r]['unl'] == m['city']): print('  note:', mid, 'dépend de', r, '(autre ville)')
    if mid not in reg['missions']: err(mid, 'absent de registry.json')
for mid in reg['missions']:
    if mid not in missions: err('registry référence une mission absente', mid)
for cid in reg['cities']:
    if cid not in cities: err('registry référence une ville absente', cid)
# simulation : toutes les missions sont-elles terminables en partant de Port-Alpha ?
done, unlocked, changed = set(), {'port_alpha'}, True
while changed:
    changed = False
    for mid, m in missions.items():
        if mid in done or m['city'] not in unlocked or not all(r in done for r in m['req']): continue
        done.add(mid); changed = True
        if m['unl']: unlocked.add(m['unl'])
for mid in missions:
    if mid not in done: err('mission jamais atteignable', mid)
print('villes :', sorted(cities), '| missions :', len(missions), '| atteignables :', len(done), '| villes débloquables :', sorted(unlocked))
print('problèmes :', bad)
