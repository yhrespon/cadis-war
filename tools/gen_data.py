"""Génère les ressources .tres de godot_project/data/ (armes, objets, véhicules, villes, missions).
Usage : python3 gen_data.py   (écrase data/**/*.tres). Source unique des valeurs de jeu."""
import os, json
R = '../godot_project/data/'
def tv(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, tuple) and len(v) == 4 and v[0] == 'V3': return 'Vector3(%s, %s, %s)' % v[1:]
    if isinstance(v, tuple) and len(v) == 4 and v[0] == 'C': return 'Color(%s, %s, %s, 1)' % tuple(round(x / 255, 4) for x in v[1:])
    if isinstance(v, tuple) and len(v) == 3 and v[0] == 'V2i': return 'Vector2i(%d, %d)' % v[1:]
    if isinstance(v, list): return '[' + ', '.join(tv(x) for x in v) + ']'
    if isinstance(v, dict): return '{' + ', '.join('%s: %s' % (tv(k), tv(x)) for k, x in v.items()) + '}'
    raise ValueError(v)
def C(r, g, b): return ('C', r, g, b)
def V3(x, y, z): return ('V3', x, y, z)
def V2i(x, z): return ('V2i', x, z)
def write(folder, name, cls, script, props):
    os.makedirs(R + folder, exist_ok=True)
    s = '[gd_resource type="Resource" script_class="%s" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/defs/%s" id="1"]\n\n[resource]\nscript = ExtResource("1")\n' % (cls, script)
    for k, v in props.items(): s += '%s = %s\n' % (k, tv(v))
    open(R + folder + '/' + name + '.tres', 'w').write(s)

# ---------- ARMES ----------
W = [
 dict(id='pistol', display_name='Pistolet', model='pistol', damage=26.0, rate=3.5, range_m=55.0, spread_deg=1.0, spread_move=1.6, recoil_deg=1.4, mag_size=12, ammo_type='9mm', noise_radius=40.0, price=350, fov_aim=50.0),
 dict(id='smg', display_name='Pistolet-mitrailleur', model='smg', damage=14.0, rate=11.0, auto_fire=True, range_m=45.0, spread_deg=2.2, spread_move=2.4, recoil_deg=0.9, mag_size=30, ammo_type='9mm', noise_radius=55.0, price=1400, fov_aim=52.0),
 dict(id='shotgun', display_name='Fusil à pompe', model='shotgun', damage=11.0, pellets=8, rate=1.1, range_m=28.0, spread_deg=5.5, spread_move=2.0, recoil_deg=4.5, mag_size=6, ammo_type='shells', noise_radius=70.0, price=2200, fov_aim=55.0),
 dict(id='bat', display_name='Batte', model='bat', melee=True, damage=35.0, rate=1.2, range_m=1.6, mag_size=0, ammo_type='', noise_radius=8.0, price=0),
]
for w in W: write('weapons', w['id'], 'WeaponDef', 'weapon_def.gd', w)

# ---------- OBJETS (magasin) ----------
items = []
for w in W:
    if w['id'] != 'bat': items.append(dict(id='w_' + w['id'], display_name=w['display_name'], category='weapon', price=w['price'], ref_id=w['id'], description='Arme. Chargeur %d.' % w['mag_size']))
items += [
 dict(id='ammo_9mm', display_name='Munitions 9 mm (x36)', category='ammo', price=90, ref_id='9mm', amount=36, description='Pistolet et pistolet-mitrailleur.'),
 dict(id='ammo_shells', display_name='Cartouches (x12)', category='ammo', price=110, ref_id='shells', amount=12, description='Fusil à pompe.'),
 dict(id='heal_kit', display_name='Trousse de soin (+50 PV)', category='heal', price=120, amount=50, description='Utilisable depuis le sac (touche H / bouton soin).'),
 dict(id='armor_vest', display_name='Gilet pare-balles (+50)', category='armor', price=300, amount=50, description='Absorbe 60 % des dégâts tant qu il reste des points.'),
]
tops = [('rouge', (190, 40, 40)), ('noir', (25, 25, 28)), ('bleu_nuit', (30, 45, 100)), ('vert_armee', (70, 90, 55)), ('blanc', (235, 235, 235)), ('orange', (225, 120, 40))]
bottoms = [('jean_bleu', (50, 70, 120)), ('noir', (25, 25, 30)), ('kaki', (110, 100, 70)), ('gris', (90, 90, 95)), ('bordeaux', (95, 30, 40))]
hairs = [('noir', (15, 12, 10)), ('brun', (60, 35, 20)), ('blond', (210, 170, 90)), ('roux', (150, 60, 30)), ('rose', (210, 40, 140))]
for n, c in tops: items.append(dict(id='top_' + n, display_name='Haut ' + n.replace('_', ' '), category='top', price=60, color=C(*c), description='Change la couleur du haut.'))
for n, c in bottoms: items.append(dict(id='bottom_' + n, display_name='Bas ' + n.replace('_', ' '), category='bottom', price=60, color=C(*c), description='Change la couleur du bas.'))
for n, c in hairs: items.append(dict(id='hair_' + n, display_name='Cheveux ' + n, category='hair', price=40, color=C(*c), description='Teinture (sans effet sur un personnage chauve).'))
for it in items: write('items', it['id'], 'ItemDef', 'item_def.gd', it)

# ---------- VEHICULES ----------
V = [
 dict(id='sedan', display_name='Berline', size=V3(1.8, 0.62, 4.2), body_color=C(178, 28, 28), max_speed=22.0, accel=9.0, max_hp=220.0, price=0),
 dict(id='van', display_name='Fourgon', size=V3(2.0, 1.05, 4.8), body_color=C(220, 220, 225), cabin_height=0.9, max_speed=17.0, accel=6.5, steer_rate=1.4, max_hp=320.0, seat_y=0.78, price=0),
 dict(id='sport', display_name='Coupé sport', size=V3(1.85, 0.5, 4.0), body_color=C(240, 190, 20), cabin_height=0.45, max_speed=30.0, accel=13.0, steer_rate=2.0, max_hp=160.0, seat_y=0.5, price=0),
 dict(id='moto', display_name='Moto', kind='moto', size=V3(0.6, 0.6, 2.0), body_color=C(25, 25, 35), max_speed=30.0, accel=14.0, steer_rate=2.4, max_hp=90.0, seat_x=0.0, seat_y=0.72, seat_z=-0.15, price=0),
 dict(id='truck', display_name='Camion', kind='truck', size=V3(2.4, 1.1, 7.0), body_color=C(50, 90, 160), cabin_height=0.9, max_speed=15.0, accel=5.0, brake_force=20.0, steer_rate=1.1, max_hp=520.0, seat_x=0.6, seat_y=1.25, seat_z=-0.5, price=0),
 dict(id='heli', display_name='Hélicoptère', kind='heli', size=V3(1.8, 1.4, 3.6), body_color=C(45, 95, 60), max_speed=28.0, max_reverse=6.0, accel=7.0, brake_force=14.0, steer_rate=1.6, max_hp=260.0, seat_x=0.4, seat_y=0.85, seat_z=0.35, climb_rate=7.0, price=0),
 dict(id='plane', display_name='Avion', kind='plane', size=V3(9.0, 1.2, 6.0), body_color=C(230, 230, 235), max_speed=44.0, max_reverse=3.0, accel=8.0, brake_force=14.0, steer_rate=1.0, max_hp=200.0, seat_x=0.0, seat_y=0.95, seat_z=0.3, lift_speed=20.0, climb_rate=7.0, price=0),
]
for v in V: write('vehicles', v['id'], 'VehicleDef', 'vehicle_def.gd', v)

# ---------- VILLES ----------
CITIES = [
 dict(id='port_alpha', display_name='Port-Alpha', seed_value=11, blocks_x=6, blocks_z=6, floors_min=2, floors_max=4, wall_color=C(158, 148, 132), wall_color_b=C(135, 124, 112), sky_color=C(140, 166, 200), civilians=30, traffic=4,
      pois={'spawn': V2i(2, 3), 'shop': V2i(2, 2), 'contact_a': V2i(3, 3), 'hideout_a': V2i(5, 1), 'hideout_b': V2i(0, 4), 'hideout_c': V2i(5, 5), 'drop_a': V2i(1, 0), 'safehouse': V2i(0, 1), 'depot': V2i(3, 0), 'vault': V2i(4, 4), 'car_a': V2i(2, 4), 'travel': V2i(3, 2), 'hospital': V2i(1, 3), 'far_a': V2i(5, 3), 'search_a': V2i(1, 5), 'search_b': V2i(4, 2), 'search_c': V2i(0, 2)}),
 dict(id='nova_district', display_name='Nova District', seed_value=23, blocks_x=7, blocks_z=5, floors_min=4, floors_max=8, wall_color=C(120, 135, 150), wall_color_b=C(95, 108, 124), roof_color=C(60, 64, 70), road_color=C(0.12*255, 0.12*255, 0.15*255), sky_color=C(110, 130, 175), civilians=34, traffic=6,
      pois={'spawn': V2i(3, 2), 'shop': V2i(2, 2), 'contact_a': V2i(4, 2), 'hideout_a': V2i(6, 0), 'hideout_b': V2i(0, 4), 'hideout_c': V2i(6, 4), 'drop_a': V2i(1, 0), 'safehouse': V2i(0, 1), 'depot': V2i(3, 0), 'vault': V2i(5, 3), 'car_a': V2i(3, 3), 'travel': V2i(4, 3), 'hospital': V2i(2, 4), 'far_a': V2i(6, 2), 'search_a': V2i(1, 3), 'search_b': V2i(5, 1), 'search_c': V2i(0, 2)}),
 dict(id='ironworks', display_name='Ironworks', seed_value=37, blocks_x=6, blocks_z=6, floors_min=1, floors_max=3, industrial=True, wall_color=C(130, 110, 90), wall_color_b=C(100, 88, 78), roof_color=C(70, 60, 55), ground_color=C(0.33*255, 0.32*255, 0.29*255), sky_color=C(170, 150, 130), civilians=20, traffic=5,
      pois={'spawn': V2i(2, 2), 'shop': V2i(1, 2), 'contact_a': V2i(3, 2), 'hideout_a': V2i(5, 0), 'hideout_b': V2i(0, 5), 'hideout_c': V2i(5, 5), 'drop_a': V2i(0, 0), 'safehouse': V2i(1, 0), 'depot': V2i(3, 5), 'vault': V2i(4, 3), 'car_a': V2i(2, 3), 'travel': V2i(3, 3), 'hospital': V2i(1, 4), 'far_a': V2i(5, 2), 'search_a': V2i(0, 3), 'search_b': V2i(4, 1), 'search_c': V2i(2, 5)}),
 dict(id='sunset_bay', display_name='Sunset Bay', seed_value=51, blocks_x=7, blocks_z=6, floors_min=1, floors_max=3, wall_color=C(232, 214, 186), wall_color_b=C(220, 170, 140), roof_color=C(170, 80, 60), ground_color=C(0.55*255, 0.52*255, 0.4*255), sky_color=C(250, 190, 140), civilians=32, traffic=4,
      pois={'spawn': V2i(3, 3), 'shop': V2i(3, 2), 'contact_a': V2i(4, 3), 'hideout_a': V2i(6, 1), 'hideout_b': V2i(0, 5), 'hideout_c': V2i(6, 5), 'drop_a': V2i(1, 0), 'safehouse': V2i(0, 2), 'depot': V2i(5, 0), 'vault': V2i(5, 4), 'car_a': V2i(2, 3), 'travel': V2i(4, 2), 'hospital': V2i(2, 5), 'far_a': V2i(6, 3), 'search_a': V2i(1, 4), 'search_b': V2i(4, 5), 'search_c': V2i(0, 1)}),
]
# Site de la Mission secrète (jamais listé dans le voyage ni dans registry['cities']) : 3x3 blocs, aucun civil.
CITIES.append(dict(id='secret_site', display_name='Site secret', seed_value=73, blocks_x=3, blocks_z=3, floors_min=1, floors_max=2, industrial=True, wall_color=C(96, 100, 108), wall_color_b=C(78, 82, 90), roof_color=C(50, 52, 58), ground_color=C(0.28*255, 0.3*255, 0.3*255), sky_color=C(40, 50, 75), civilians=0, traffic=0,
      pois={'spawn': V2i(0, 2), 'depot': V2i(1, 1), 'hideout_a': V2i(1, 0), 'hideout_b': V2i(2, 1), 'hideout_c': V2i(1, 2), 'far_a': V2i(2, 0)}))
for c in CITIES:
    c = dict(c)
    for k in ('road_color',):
        if k in c: c[k] = C(*[int(x) for x in c[k][1:]])
    for k in ('ground_color',):
        if k in c: c[k] = C(*[int(x) for x in c[k][1:]])
    write('cities', c['id'], 'CityDef', 'city_def.gd', c)

# ---------- MISSIONS ----------
# Étape = dict (un objectif) ou liste de dicts (objectifs parallèles). Types : goto, stealth_goto, vehicle_goto, kill, collect, interact, survive, protect, escort, chase
def M(**k): return k
MS = []
def mission(**k): MS.append(k)
mission(id='pa_01_contact', title='Premier contact', category='main', mission_type='contact', city='port_alpha', giver='Inspecteur Roux',
        briefing="Un contact vous attend au carrefour central. Allez le voir : il a une arme à vous confier.",
        reward_money=300, reward_item='w_pistol',
        objectives=[dict(type='interact', npc='Roux', poi='contact_a', text='Parlez à Roux', lines=['Tu es le nouveau ? Prends ça, tu en auras besoin.', 'Les hommes de Vance tiennent la zone nord-est. On commence par eux.'])])
mission(id='pa_02_nettoyage', title='Nettoyage au nord-est', category='main', mission_type='élimination', city='port_alpha', giver='Inspecteur Roux', requires=['pa_01_contact'],
        briefing="Trois hommes de Vance squattent un entrepôt au nord-est. Éliminez-les.",
        reward_money=700,
        objectives=[dict(type='kill', poi='hideout_a', count=3, tag='h_a', weapon='pistol', text='Éliminez les hommes de Vance')])
mission(id='pa_03_colis', title='Le colis volé', category='main', mission_type='récupération + livraison', city='port_alpha', giver='Inspecteur Roux', requires=['pa_02_nettoyage'],
        briefing="Un colis est caché dans la planque du sud-ouest, gardée par deux hommes. Récupérez-le puis livrez-le au point de dépôt.",
        reward_money=900,
        objectives=[[dict(type='kill', poi='hideout_b', count=2, tag='h_b', weapon='pistol', text='Neutralisez les gardes'), dict(type='collect', poi='hideout_b', items=1, item_name='Colis', spread=6.0, text='Récupérez le colis')],
                    dict(type='goto', poi='drop_a', radius=4.0, text='Livrez le colis au point de dépôt')])
mission(id='pa_04_escorte', title='L\'indic', category='main', mission_type='escorte', city='port_alpha', giver='Inspecteur Roux', requires=['pa_03_colis'],
        briefing="Un informateur doit rejoindre la planque sécurisée. Escortez-le à pied, sans qu'il se fasse tuer.",
        reward_money=1100,
        objectives=[dict(type='escort', npc='Informateur', from_poi='contact_a', poi='safehouse', radius=4.0, text='Escortez l\'informateur jusqu\'à la planque')])
mission(id='pa_05_poursuite', title='Le fuyard', category='main', mission_type='poursuite', city='port_alpha', giver='Inspecteur Roux', requires=['pa_04_escorte'],
        briefing="Un revendeur de Vance a pris la fuite vers l'est. Rattrapez-le et neutralisez-le avant qu'il ne disparaisse.",
        reward_money=1200, time_limit=150.0,
        objectives=[dict(type='chase', poi='depot', flee_to='far_a', tag='dealer', weapon='pistol', text='Neutralisez le fuyard')])
mission(id='pa_06_defense', title='Tenir le dépôt', category='main', mission_type='défense', city='port_alpha', giver='Inspecteur Roux', requires=['pa_05_poursuite'],
        briefing="Vance envoie des renforts au dépôt du nord. Tenez la position pendant que l'équipe évacue.",
        reward_money=1500,
        objectives=[dict(type='goto', poi='depot', radius=5.0, text='Rejoignez le dépôt'), dict(type='survive', poi='depot', seconds=60.0, waves=3, per_wave=2, weapon='smg', text='Tenez la position')])
mission(id='pa_07_transport', title='Livraison express', category='main', mission_type='transport + chronométrée', city='port_alpha', giver='Inspecteur Roux', requires=['pa_06_defense'],
        briefing="Prenez la berline garée au sud et conduisez-la jusqu'au point de livraison avant la fin du temps imparti.",
        reward_money=1600, time_limit=120.0,
        objectives=[dict(type='vehicle_goto', vehicle='sedan', car_poi='car_a', poi='far_a', radius=7.0, text='Conduisez jusqu\'au point de livraison')])
mission(id='pa_08_repaire', title='Assaut sur le repaire', category='main', mission_type='attaque de repaire', city='port_alpha', giver='Inspecteur Roux', requires=['pa_07_transport'],
        briefing="Le repaire de Vance est au sud-est. Éliminez tous ses hommes et récupérez le registre.",
        reward_money=2500, unlocks_city='nova_district',
        objectives=[[dict(type='kill', poi='hideout_c', count=5, tag='h_c', weapon='smg', text='Éliminez les hommes de Vance'), dict(type='collect', poi='hideout_c', items=1, item_name='Registre', spread=5.0, text='Récupérez le registre')]])
mission(id='pa_c1_contrat', title='Contrat : racketteurs', category='contract', mission_type='élimination', city='port_alpha', giver='Panneau de contrats', requires=['pa_01_contact'],
        briefing="Contrat répétable : deux racketteurs sévissent au sud-ouest.", reward_money=450,
        objectives=[dict(type='kill', poi='hideout_b', count=2, tag='c1', weapon='pistol', text='Éliminez les racketteurs')])
mission(id='pa_s1_recherche', title='Cachettes', category='side', mission_type='recherche', city='port_alpha', giver='Gamin des rues', requires=['pa_01_contact'],
        briefing="Un gamin dit avoir caché trois sacs d'argent dans le quartier. Retrouvez-les.", reward_money=600,
        objectives=[dict(type='collect', pois=['search_a', 'search_b', 'search_c'], item_name='Sac', text='Retrouvez les sacs cachés')])
mission(id='pa_s2_infiltration', title='Coffre de la banque', category='side', mission_type='infiltration', city='port_alpha', giver='Inconnu', requires=['pa_03_colis'],
        briefing="Rejoignez le coffre sans déclencher l'alerte. Si on vous repère, c'est un échec.", reward_money=1000,
        objectives=[dict(type='stealth_goto', poi='vault', radius=3.5, guards=2, text='Atteignez le coffre sans être repéré')])
mission(id='pa_s3_fuite', title='Sur le fil', category='side', mission_type='fuite', city='port_alpha', giver='Inconnu', requires=['pa_05_poursuite'],
        briefing="Une équipe vous traque : gagnez la planque avant qu'elle ne vous rattrape.", reward_money=800,
        objectives=[[dict(type='goto', poi='safehouse', radius=4.0, text='Atteignez la planque'), dict(type='survive', poi='spawn', seconds=45.0, waves=2, per_wave=2, weapon='pistol', chase=True, text='Survivez à la traque')]])
mission(id='pa_s4_protection', title='Protégez le témoin', category='side', mission_type='protection', city='port_alpha', giver='Inspecteur Roux', requires=['pa_04_escorte'],
        briefing="Un témoin attend à la planque. Protégez-le pendant 40 secondes.", reward_money=900,
        objectives=[dict(type='protect', npc='Témoin', poi='safehouse', seconds=40.0, per_wave=2, weapon='pistol', text='Protégez le témoin')])
# --- villes suivantes : une chaîne courte chacune (même moteur d'objectifs) ---
def chain(cid, tag, giver, unlock, prev):
    mission(id=cid + '_01', title='Arrivée en ville', category='main', mission_type='contact', city=tag, giver=giver, requires=[prev] if prev else [],
            briefing="Retrouvez votre contact local.", reward_money=500,
            objectives=[dict(type='interact', npc=giver, poi='contact_a', text='Parlez à ' + giver, lines=['Bienvenue. Ici, on règle les problèmes vite.', 'Un groupe armé nous gêne : occupons-nous d\'eux.'])])
    mission(id=cid + '_02', title='Zone à nettoyer', category='main', mission_type='élimination', city=tag, giver=giver, requires=[cid + '_01'],
            briefing="Éliminez l'équipe retranchée.", reward_money=1200,
            objectives=[dict(type='kill', poi='hideout_a', count=4, tag=cid + 'a', weapon='smg', text='Éliminez l\'équipe')])
    mission(id=cid + '_03', title='Récupération et livraison', category='main', mission_type='récupération + livraison', city=tag, giver=giver, requires=[cid + '_02'],
            briefing="Récupérez le matériel dans la planque, livrez-le au point de dépôt, dans les temps.", reward_money=1800, time_limit=240.0,
            objectives=[[dict(type='kill', poi='hideout_b', count=3, tag=cid + 'b', weapon='smg', text='Neutralisez les gardes'), dict(type='collect', poi='hideout_b', items=1, item_name='Matériel', spread=6.0, text='Récupérez le matériel')], dict(type='goto', poi='drop_a', radius=4.0, text='Livrez le matériel')])
    mission(id=cid + '_04', title='Dernier assaut', category='main', mission_type='attaque de repaire', city=tag, giver=giver, requires=[cid + '_03'],
            briefing="Prenez d'assaut le repaire et éliminez le chef.", reward_money=3000, unlocks_city=unlock,
            objectives=[dict(type='kill', poi='hideout_c', count=6, tag=cid + 'c', weapon='shotgun', text='Éliminez les occupants')])
chain('nd', 'nova_district', 'Mme Kessler', 'ironworks', 'pa_08_repaire')
chain('iw', 'ironworks', 'Contremaître Dubois', 'sunset_bay', 'nd_04')
chain('sb', 'sunset_bay', 'Capitaine Moreau', '', 'iw_04')
for m in MS: write('missions', m['id'], 'MissionDef', 'mission_def.gd', m)
print(len(W), 'armes,', len(items), 'objets,', len(V), 'vehicules,', len(CITIES), 'villes,', len(MS), 'missions')
open(R + 'registry.json', 'w').write(json.dumps({
  'weapons': [w['id'] for w in W], 'items': [i['id'] for i in items], 'vehicles': [v['id'] for v in V],
  'cities': [c['id'] for c in CITIES if c['id'] != 'secret_site'], 'missions': [m['id'] for m in MS]}, indent=1))
