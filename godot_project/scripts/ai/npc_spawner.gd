class_name NPCSpawner
extends Node
## Fabrique des PNJ : sert de `MissionManager.spawner` (spawn_enemies / spawn_friendly) et maintient les civils ambiants autour du joueur
## (effectif max = CityDef.civilians × densité ; apparition sur le trottoir des blocs chargés, hors de vue proche ; retrait au-delà de 120 m).
## Les ennemis de mission ne sont PAS plafonnés (un objectif « tuer N » doit rester atteignable).
## Placement : test de capsule libre (intersect_shape) autour du point demandé, sinon repli sur l'anneau de trottoir du bloc.
## v13 : script chargé ; placement par requête physique et apparition sur secteur fraîchement chargé non testés.
## Risque connu : un secteur qui vient d'être chargé peut ne pas encore répondre aux requêtes physiques ; le repli « trottoir » limite l'effet.

const SIDEWALK_HALF := 1.05          # centre du trottoir par rapport au bord du bloc (trottoirs de 2,1 m)
const CIV_MIN_DIST := 22.0
const CIV_MAX_DIST := 90.0
const CIV_DESPAWN := 120.0

var _t := 0.0
var _probe: CapsuleShape3D = null

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
	if _t < 0.8:
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
	while n + made < cap and made < 2:
		if not _spawn_civilian(pp):
			break
		made += 1

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
