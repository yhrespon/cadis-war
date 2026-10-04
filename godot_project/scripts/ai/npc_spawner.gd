class_name NPCSpawner
extends Node
## Fabrique des PNJ : sert de `MissionManager.spawner` (spawn_enemies / spawn_friendly) et maintient les civils ambiants autour du joueur
## (effectif max = CityDef.civilians × densité ; apparition sur le trottoir des blocs chargés, hors de vue proche ; retrait au-delà de 120 m).
## Les ennemis de mission ne sont PAS plafonnés (un objectif « tuer N » doit rester atteignable).
## Placement : test de capsule libre (intersect_shape) autour du point demandé, sinon repli sur l'anneau de trottoir du bloc.
## v13 : script chargé ; placement par requête physique et apparition sur secteur fraîchement chargé non testés.
## Risque connu : un secteur qui vient d'être chargé peut ne pas encore répondre aux requêtes physiques ; le repli « trottoir » limite l'effet.

const SIDEWALK_HALF := 1.05          # centre du trottoir par rapport au bord du bloc (trottoirs de 2,1 m)
const CIV_MIN_DIST := 10.0
const CIV_MAX_DIST := 55.0
const CIV_DESPAWN := 75.0

var _t := 0.0
var _probe: CapsuleShape3D = null
var _amb_t := 0.0

func _ready() -> void:
	_probe = CapsuleShape3D.new()
	_probe.radius = 0.35
	_probe.height = 1.6

# ---------------------------------------------------------------- API MissionManager
func spawn_enemies(count: int, pos: Vector3, weapon: String, tag: String, opts: Dictionary) -> Array:
	var out: Array = []
	if WorldManager.entities == null:
		return out
	var center := pos
	var is_wave := tag == "wave"
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_wave and player != null:
		center = player.global_position
	var flee_target := Vector3.INF
	if opts.has("flee_to"):
		var ft: Vector3 = opts["flee_to"]
		if ft != Vector3.ZERO:
			flee_target = ft
	for i in count:
		var p := _spawn_point(center, 24.0 if is_wave else 3.0, 36.0 if is_wave else 9.0)
		var e := EnemyController.new()
		e.weapon_id = weapon
		e.tag = tag
		e.chase = bool(opts.get("chase", false))
		e.stealth = bool(opts.get("stealth", false))
		e.flee_to = flee_target
		e.position = p
		WorldManager.entities.add_child(e)
		out.append(e)
	return out

func spawn_friendly(npc_name: String, pos: Vector3) -> Node:
	if WorldManager.entities == null:
		return null
	var a := AllyController.new()
	a.display_name = npc_name
	var ids: Array = []
	for id in GameManager.character_ids():
		if str(GameManager.character_entry(str(id)).get("age", "adulte")) == "adulte":
			ids.append(str(id))
	if not ids.is_empty():
		a.char_id = str(ids[absi(hash(npc_name)) % ids.size()])
	a.position = _spawn_point(pos, 1.5, 4.0)
	WorldManager.entities.add_child(a)
	return a

# ---------------------------------------------------------------- civils ambiants
func _physics_process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	if WorldManager.city == null or WorldManager.entities == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var pp := player.global_position
	for c in get_tree().get_nodes_in_group("civilian"):
		var c3 := c as Node3D
		if c3 != null and c3.global_position.distance_to(pp) > CIV_DESPAWN:
			c3.queue_free()
	var cap := NPCManager.max_civilians(WorldManager.city)
	var n := NPCManager.count_of("civilian")
	var made := 0
	while n + made < cap and made < 4:
		if not _spawn_civilian(pp):
			break
		made += 1
	_amb_t += 0.5
	if _amb_t >= 1.5:
		_amb_t = 0.0
		if GameManager.mode == "secret":
			_ambient_traffic(pp)
		else:
			_ambient(pp)

func _spawn_civilian(pp: Vector3) -> bool:
	var cb := WorldManager.block_of(pp)
	var h := WorldManager.city.block_size * 0.5 + SIDEWALK_HALF
	for k in 8:
		var b := Vector2i(cb.x + randi_range(-2, 2), cb.y + randi_range(-2, 2))
		if not WorldManager.in_bounds(b) or not WorldManager.sectors.has(b):
			continue
		var center := WorldManager.block_center(b)
		var t := randf() * 8.0 * h
		var p := CivilianController.ring_point(center, h, t)
		var d := Vector2(p.x - pp.x, p.z - pp.z).length()
		if d < CIV_MIN_DIST or d > CIV_MAX_DIST:
			continue
		var c := CivilianController.new()
		c.ring_center = center
		c.ring_half = h
		c.ring_t = t
		c.position = p
		WorldManager.entities.add_child(c)
		return true
	return false

# ---------------------------------------------------------------- placement
func _spawn_point(center: Vector3, rmin: float, rmax: float) -> Vector3:
	for k in 14:
		var a := randf() * TAU
		var r := randf_range(rmin, rmax)
		var c := center + Vector3(cos(a) * r, 0.1, sin(a) * r)
		c.y = 0.1
		if WorldManager.city_extent().has_point(Vector2(c.x, c.z)) and _is_free(c):
			return c
	var fallback := center + Vector3(randf_range(-rmax, rmax), 0.1, randf_range(-rmax, rmax))
	return _snap_to_ring(fallback)

func _is_free(p: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _probe
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.0, 0))
	q.collision_mask = 1 | 16
	q.collide_with_areas = false
	return get_viewport().world_3d.direct_space_state.intersect_shape(q, 1).is_empty()

## Ramène un point situé dans l'emprise d'un bloc sur le trottoir le plus proche (hors bâtiments).
func _snap_to_ring(p: Vector3) -> Vector3:
	var b := WorldManager.block_of(p)
	var c := WorldManager.block_center(b)
	var h := WorldManager.city.block_size * 0.5 + SIDEWALK_HALF
	var l := p - c
	if absf(l.x) < h and absf(l.z) < h:
		if absf(l.x) > absf(l.z):
			l.x = h * (1.0 if l.x >= 0.0 else -1.0)
		else:
			l.z = h * (1.0 if l.z >= 0.0 else -1.0)
	return Vector3(c.x + l.x, 0.1, c.z + l.z)

# ================================================================ v17 : monde vivant (police, gangs, trafiquants, trafic)
const DENSITY_POLICE := 2
const DENSITY_GANG := 4
const DENSITY_DEALER := 2

## Point d'anneau de trottoir d'un bloc chargé proche du joueur, à une distance [dmin, dmax] : {pos, center, h, t} ou {} si échec.
func _ring_spawn(pp: Vector3, dmin: float, dmax: float) -> Dictionary:
	var cb := WorldManager.block_of(pp)
	var h := WorldManager.city.block_size * 0.5 + SIDEWALK_HALF
	for k in 10:
		var b := Vector2i(cb.x + randi_range(-2, 2), cb.y + randi_range(-2, 2))
		if not WorldManager.in_bounds(b) or not WorldManager.sectors.has(b):
			continue
		var center := WorldManager.block_center(b)
		var t := randf() * 8.0 * h
		var p := CivilianController.ring_point(center, h, t)
		var d := Vector2(p.x - pp.x, p.z - pp.z).length()
		if d < dmin or d > dmax or not _is_free(p):
			continue
		return {"pos": p, "center": center, "h": h, "t": t}
	return {}

func _ambient(pp: Vector3) -> void:
	var dens := SettingsManager.npc_density()
	var city := WorldManager.city
	# --- nettoyage (loin du joueur) : police de renfort sans recherche, groupes isolés, voitures de trafic
	for g in ["police", "gang", "dealer"]:
		for n in get_tree().get_nodes_in_group(g):
			var n3 := n as Node3D
			if n3 == null:
				continue
			var d := n3.global_position.distance_to(pp)
			var far := d > 85.0
			if g == "police":
				var pc := n as PoliceController
				if pc != null and pc.reinforcement and not CrimeManager.is_wanted() and d > 35.0:
					far = true
			if far:
				n3.queue_free()
		# --- police à pied en patrouille
	if NPCManager.count_of("police") < int(round(DENSITY_POLICE * dens)) and randf() < 0.5:
		var r := _ring_spawn(pp, 28.0, 60.0)
		if not r.is_empty():
			_make_police(r["pos"], r["center"], r["h"], r["t"], 0, false)
	# --- gangs (groupes de 2 à 4)
	if NPCManager.count_of("gang") < int(round(DENSITY_GANG * dens)) and randf() < 0.45:
		var r2 := _ring_spawn(pp, 30.0, 62.0)
		if not r2.is_empty():
			_make_gang_group(r2["pos"], int(randi_range(2, 4)), "gang")
	# --- trafiquants (2 + une camionnette)
	if NPCManager.count_of("dealer") < int(round(DENSITY_DEALER * dens)) and randf() < 0.3:
		var r3 := _ring_spawn(pp, 32.0, 65.0)
		if not r3.is_empty():
				_make_gang_group(r3["pos"], 2, "dealer")
				var side: Vector3 = (Vector3(r3["center"]) - Vector3(r3["pos"])).normalized()
				var vp: Vector3 = Vector3(r3["pos"]) - side * 3.2
				var vv := VehicleManager.spawn("van", Transform3D(Basis(Vector3.UP, atan2(side.x, side.z) + PI * 0.5), Vector3(vp.x, 0.1, vp.z)), WorldManager.entities)
				if vv != null:
					vv.set_body_color(Color(0.1, 0.1, 0.12))
	_ambient_traffic(pp)

## Trafic civil séparé des autres PNJ : en mission secrète, seuls ces véhicules restent actifs.
func _ambient_traffic(pp: Vector3) -> void:
	var city := WorldManager.city
	if city == null:
		return
	for v in get_tree().get_nodes_in_group("traffic"):
		var v3 := v as Node3D
		if v3 != null and v3.global_position.distance_to(pp) > 150.0:
			v3.queue_free()
	if city.traffic <= 0 or city.blocks_x < 3 or city.blocks_z < 3:
		return
	var secret := GameManager.mode == "secret"
	var cap := int(round(float(city.traffic) * (2.0 if secret else 3.0) * SettingsManager.npc_density()))
	if get_tree().get_nodes_in_group("traffic").size() < cap and randf() < 0.8:
		_spawn_traffic_car(pp)

func _make_police(pos: Vector3, center: Vector3, h: float, t: float, level: int, reinforcement: bool) -> PoliceController:
	var c := PoliceController.new()
	c.patrol_level = level
	c.reinforcement = reinforcement
	if not reinforcement:
		c.ring_center = center
		c.ring_half = h
		c.ring_t = t
	c.position = pos
	WorldManager.entities.add_child(c)
	return c

func _make_gang_group(pos: Vector3, count: int, fac: String) -> void:
	var weapons: Array = ["pistol", "pistol", "smg", "bat", "dagger"] if fac == "gang" else ["smg", "shotgun", "pistol"]
	var gcol: Color = GangController.GANG_COLORS[randi() % GangController.GANG_COLORS.size()]
	for i in count:
		var g := GangController.new()
		g.faction = fac
		g.gang_color = gcol
		g.weapon_id = str(weapons[randi() % weapons.size()])
		g.position = _spawn_point(pos, 0.8, 3.0)
		WorldManager.entities.add_child(g)

## Voiture de trafic sur une voie de droite, à 60-130 m du joueur, dans le sens d'une route réelle.
func _spawn_traffic_car(pp: Vector3) -> bool:
	var city := WorldManager.city
	var ids: Array = ["sedan", "sedan", "sport", "van", "moto"]
	for k in 8:
		var nd := Vector2i(randi_range(1, city.blocks_x - 1), randi_range(1, city.blocks_z - 1))
		var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var hd: Vector2i = dirs[randi() % 4]
		if not TrafficDriver.valid_node(city, nd - hd):
			continue
		var seg := city.block_size + city.road_width
		var xf := TrafficDriver.spawn_transform(city, nd, hd, randf_range(8.0, seg - 8.0))
		var d := Vector2(xf.origin.x - pp.x, xf.origin.z - pp.z).length()
		var secret := GameManager.mode == "secret"
		var min_distance := 20.0 if secret else 40.0
		var max_distance := 80.0 if secret else 90.0
		if d < min_distance or d > max_distance:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.6, 1.4, 5.5)
		q.shape = bs
		q.transform = Transform3D(xf.basis, xf.origin + Vector3(0, 1.0, 0))
		q.collision_mask = 16
		if not get_viewport().world_3d.direct_space_state.intersect_shape(q, 1).is_empty():
			continue
		var v := VehicleManager.spawn(str(ids[randi() % ids.size()]), xf, WorldManager.entities)
		if v == null:
			return false
		var cols: Array = [Color(0.15, 0.2, 0.5), Color(0.75, 0.75, 0.78), Color(0.1, 0.1, 0.12), Color(0.6, 0.55, 0.1), Color(0.12, 0.4, 0.25), Color(0.7, 0.1, 0.1), Color(0.8, 0.8, 0.82)]
		v.set_body_color(cols[randi() % cols.size()])
		v.add_to_group("traffic")
		var drv := TrafficDriver.new()
		v.add_child(drv)
		drv.setup(v, nd, hd, "traffic")
		return true
	return false

## Appelé par CrimeManager : agents de renfort à pied près du joueur (hors de vue immédiate).
func spawn_police(count: int, near: Vector3, level: int) -> void:
	if WorldManager.entities == null:
		return
	for i in count:
		var p := _spawn_point(near, 28.0, 48.0)
		_make_police(p, Vector3.ZERO, 24.0, 0.0, level, true)

## Voiture de patrouille qui fonce vers le joueur (TrafficDriver en mode « pursue »), sirène allumée.
func spawn_police_car(near: Vector3, level: int) -> void:
	var city := WorldManager.city
	if city == null or city.blocks_x < 3 or city.blocks_z < 3 or WorldManager.entities == null:
		return
	for k in 12:
		var nd := Vector2i(randi_range(1, city.blocks_x - 1), randi_range(1, city.blocks_z - 1))
		var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var hd: Vector2i = dirs[randi() % 4]
		if not TrafficDriver.valid_node(city, nd - hd):
			continue
		var xf := TrafficDriver.spawn_transform(city, nd, hd, 14.0)
		var d := Vector2(xf.origin.x - near.x, xf.origin.z - near.z).length()
		if d < 70.0 or d > 170.0:
			continue
		var v := VehicleManager.spawn("sedan", xf, WorldManager.entities)
		if v == null:
			return
		v.make_police(true)
		v.add_to_group("police_car")
		var drv := TrafficDriver.new()
		v.add_child(drv)
		drv.setup(v, nd, hd, "pursue")
		drv.level = level
		return

## Les agents sortent de la voiture de patrouille arrêtée.
func dismount_police(v: Vehicle, level: int) -> void:
	if WorldManager.entities == null or not is_instance_valid(v):
		return
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var p := v.global_position + v.global_transform.basis.x * side * (v.def.size.x * 0.5 + 1.0)
		p.y = 0.1
		_make_police(p, Vector3.ZERO, 24.0, 0.0, level, true)

## Conducteur éjecté d'une voiture volée : un civil qui s'enfuit.
func spawn_fleeing_civilian(pos: Vector3, from: Vector3) -> void:
	if WorldManager.entities == null or WorldManager.city == null:
		return
	var b := WorldManager.block_of(pos)
	if not WorldManager.in_bounds(b):
		return
	var h := WorldManager.city.block_size * 0.5 + SIDEWALK_HALF
	var center := WorldManager.block_center(b)
	var c := CivilianController.new()
	c.ring_center = center
	c.ring_half = h
	var sn := _snap_to_ring(pos)
	c.ring_t = CivilianController.ring_t_of(sn.x - center.x, sn.z - center.z, h)
	c.position = Vector3(pos.x, 0.1, pos.z)
	WorldManager.entities.add_child(c)
	c.flee_from(from)
