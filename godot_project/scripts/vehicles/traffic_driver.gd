class_name TrafficDriver
extends Node
## Pilote automatique d'un Vehicle (v17) : circule sur le quadrillage des routes de la ville, voie de droite, choisit un sens à
## chaque intersection (tout droit 60 %, virages 20 % chacun), freine devant tout obstacle (piéton, voiture, joueur) grâce à un rayon
## avant, ralentit sous la pluie / la nuit et dans les virages. Pas de feux de circulation (v17) : en cas de blocage de 7 s, la
## voiture devient « fantôme » 3 s vis-à-vis des autres véhicules pour se dégager.
## Mode « pursue » (voiture de police) : à chaque intersection, prend la direction qui rapproche le plus du joueur ; à moins de
## 24 m, s'arrête, les agents descendent (NPCSpawner.dismount_police) et le véhicule redevient un véhicule normal.
## Les routes sont les lignes x = -p/2 + i*p et z = -p/2 + j*p (i, j = 1 .. blocs-1 : intersections intérieures).
## Repère véhicule : avant = +Z local, droite = -X local. [NON TESTÉ DANS GODOT]

const LANE := 1.1                 # distance du centre de voie à l'axe de la route (m)
const TURN_AT := 0.9
const PREVIEW := 15.0
const SIGNAL_LOOKAHEAD := 23.0
const SIGNAL_STOP_LINE := 8.5
const SIGNAL_DECELERATION := 6.0   # Vehicle ralentit à 6 m/s² lorsque le frein fort n'est pas engagé

var vehicle: Vehicle = null
var mode := "traffic"             # traffic | pursue
var cruise := 10.0                # m/s
var heading := Vector2i(0, 1)     # (dx, dz) entiers
var node := Vector2i(1, 1)        # intersection vers laquelle on roule
var pending := Vector2i(0, 1)     # direction choisie pour la prochaine intersection
var level := 1                    # niveau de recherche (pursuite)

var _chosen := false
var _blocked_t := 0.0
var _ghost_t := 0.0
var _honk_t := 0.0
var _age := 0.0
var _normal_collision_mask := 1 | 16

static func node_world(city: CityDef, n: Vector2i) -> Vector3:
	var p := city.block_size + city.road_width
	return Vector3(-p * 0.5 + float(n.x) * p, 0.0, -p * 0.5 + float(n.y) * p)

static func valid_node(city: CityDef, n: Vector2i) -> bool:
	return n.x >= 1 and n.y >= 1 and n.x <= city.blocks_x - 1 and n.y <= city.blocks_z - 1

static func right_of(h: Vector2i) -> Vector3:
	return Vector3(-float(h.y), 0.0, float(h.x))

## Position + lacet de départ : à `dist` m avant `target_node`, sur la voie de droite du sens `h`.
static func spawn_transform(city: CityDef, target_node: Vector2i, h: Vector2i, dist: float) -> Transform3D:
	var c := node_world(city, target_node)
	var pos := c - Vector3(float(h.x), 0, float(h.y)) * dist + right_of(h) * LANE
	pos.y = 0.1
	return Transform3D(Basis(Vector3.UP, atan2(float(h.x), float(h.y))), pos)

func setup(v: Vehicle, start_node: Vector2i, h: Vector2i, drive_mode := "traffic") -> void:
	vehicle = v
	heading = h
	node = start_node
	pending = h
	mode = drive_mode
	_normal_collision_mask = v.collision_mask
	cruise = randf_range(8.0, 12.0) if mode == "traffic" else 16.0
	if v.def.max_speed < cruise + 2.0:
		cruise = v.def.max_speed * 0.8
	v.ai_driven = true
	v.ai_driver = self

func _exit_tree() -> void:
	if vehicle != null and is_instance_valid(vehicle):
		if _ghost_t > 0.0:
			vehicle.collision_mask = _normal_collision_mask
		if vehicle.ai_driver == self:
			vehicle.ai_driver = null

func _physics_process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle) or not vehicle.ai_driven or vehicle.destroyed:
		return
	if WorldManager.city == null:
		return
	_age += delta
	_ghost_t = maxf(0.0, _ghost_t - delta)
	_honk_t = maxf(0.0, _honk_t - delta)
	var city := WorldManager.city
	var pos := vehicle.global_position
	var h3 := Vector3(float(heading.x), 0, float(heading.y))
	var nw := node_world(city, node)
	var rem := (nw - pos).dot(h3)
	# --- choix de la prochaine direction à l'approche de l'intersection
	if rem < PREVIEW and not _chosen:
		pending = _choose(city)
		_chosen = true
	if rem <= TURN_AT:
		if pending != heading:
			heading = pending
		node = node + heading
		if not valid_node(city, node):
			node = node - heading          # sécurité : ne jamais viser un nœud hors réseau
			heading = -heading
			node = node + heading
		_chosen = false
		h3 = Vector3(float(heading.x), 0, float(heading.y))
		nw = node_world(city, node)
	# --- suivi de voie : direction visée = sens + correction latérale
	var right := right_of(heading)
	var perp := Vector3(1, 0, 0) if heading.y != 0 else Vector3(0, 0, 1)
	var lane_coord := (nw + right * LANE).dot(perp)
	var err := lane_coord - pos.dot(perp)
	var want := (h3 + perp * clampf(err * 0.45, -0.8, 0.8)).normalized()
	var yaw_des := atan2(want.x, want.z)
	var diff := wrapf(yaw_des - vehicle.rotation.y, -PI, PI)
	var steer := clampf(-diff * 2.2, -1.0, 1.0)
	# --- vitesse
	var signal_state := _signal_state(node, heading) if mode == "traffic" else "green"
	var stop_line := maxf(SIGNAL_STOP_LINE, vehicle.def.size.z * 0.5 + 5.5)
	var target_speed := cruise
	if pending != heading and rem < PREVIEW:
		target_speed = minf(target_speed, 5.5)
	var signal_speed_limit := _signal_speed_limit(signal_state, rem, stop_line)
	var signal_waiting := signal_state == "red" and rem <= SIGNAL_LOOKAHEAD and rem >= stop_line - 1.0
	if signal_speed_limit >= 0.0:
		target_speed = minf(target_speed, signal_speed_limit)
	var env := get_tree().get_first_node_in_group("environment")
	if env != null and mode == "traffic":
		if bool(env.call("is_raining")):
			target_speed *= 0.75
		if bool(env.call("is_night")):
			target_speed *= 0.9
	var allowed := _obstacle_speed(target_speed)
	var brake := allowed < vehicle.speed - 1.5
	var throttle := clampf(allowed / maxf(vehicle.def.max_speed, 1.0), 0.0, 1.0)
	if absf(diff) > 1.0:
		throttle = minf(throttle, 0.25)
	vehicle.set_controls(throttle, steer, brake)
	# --- blocage
	if signal_waiting:
		_blocked_t = 0.0                 # attendre un feu rouge n’est pas un embouteillage à traverser
	elif allowed < 0.4 and absf(vehicle.speed) < 0.6 and _ghost_t <= 0.0:
		_blocked_t += delta
		if _blocked_t > 2.0 and _honk_t <= 0.0:
			_honk_t = 5.0
			AudioManager.play_sfx("car_horn", "Vehicles", vehicle.global_position, -4.0)
		if _blocked_t > 7.0:
			_blocked_t = 0.0
			_ghost_t = 3.0
			vehicle.collision_mask = 1
	else:
		_blocked_t = maxf(0.0, _blocked_t - delta)
	if _ghost_t <= 0.0 and vehicle.collision_mask != _normal_collision_mask:
		vehicle.collision_mask = _normal_collision_mask
	# --- pursuite : arrivée près du joueur
	if mode == "pursue":
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null and Vector2(pl.global_position.x - pos.x, pl.global_position.z - pos.z).length() < 24.0 and _age > 4.0:
			_arrive()

func _signal_state(intersection: Vector2i, incoming: Vector2i) -> String:
	var network := get_tree().get_first_node_in_group("traffic_signal_network")
	if network != null and network.has_method("state_for"):
		return str(network.call("state_for", intersection, incoming))
	return "green"                    # scènes de test sans ville : ne pas immobiliser les véhicules

func _signal_speed_limit(state: String, rem: float, stop_line: float) -> float:
	if state == "green" or rem > SIGNAL_LOOKAHEAD or rem < stop_line - 1.0:
		return -1.0
	var gap := maxf(rem - stop_line, 0.0)
	if state == "yellow":
		var braking_distance := vehicle.speed * vehicle.speed / (2.0 * SIGNAL_DECELERATION) + 1.5
		if gap <= braking_distance:       # trop près pour freiner sûrement : dégager le carrefour
			return -1.0
	return sqrt(maxf(0.0, 2.0 * SIGNAL_DECELERATION * maxf(gap - 1.0, 0.0)))

func _choose(city: CityDef) -> Vector2i:
	var left := Vector2i(heading.y, -heading.x)
	var right := Vector2i(-heading.y, heading.x)
	var options: Array = []
	for d in [heading, left, right]:
		var dd: Vector2i = d
		if valid_node(city, node + dd):
			options.append(dd)
	if options.is_empty():
		return -heading
	if mode == "pursue":
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		if pl != null:
			var best: Vector2i = options[0]
			var best_d := INF
			for d in options:
				var dd: Vector2i = d
				var c := node_world(city, node + dd)
				var dist := Vector2(c.x - pl.global_position.x, c.z - pl.global_position.z).length()
				if dist < best_d:
					best_d = dist
					best = dd
			return best
	var r := randf()
	if r < 0.6 and options.has(heading):
		return heading
	options.shuffle()
	return options[0]

## Vitesse autorisée : rayon avant (piétons, véhicules, joueur, décor). Ralentit proportionnellement à la distance libre.
func _obstacle_speed(cruise_now: float) -> float:
	var v := vehicle
	var fwd := v.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var look := 4.5 + absf(v.speed) * 0.9
	var from := v.global_position + Vector3(0, 0.6, 0) + fwd * (v.def.size.z * 0.5 + 0.1)
	var mask := 1 | 2 | 4 | 8 | 16
	if _ghost_t > 0.0:
		mask = 2 | 4 | 8
	var space := v.get_world_3d().direct_space_state
	var best := INF
	for off in [0.0, 0.7, -0.7]:
		var o := from + v.global_transform.basis.x * float(off)
		var q := PhysicsRayQueryParameters3D.create(o, o + fwd * look, mask, [v.get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			best = minf(best, o.distance_to(hit["position"]))
	if best == INF:
		return cruise_now
	return clampf((best - 1.8) * 1.4, 0.0, cruise_now)

func _arrive() -> void:
	var v := vehicle
	v.ai_driven = false
	v.ai_driver = null
	v.set_controls(0.0, 0.0, true)
	v.set_siren(false)
	v.remove_from_group("police_car")
	if MissionManager.spawner != null and MissionManager.spawner.has_method("dismount_police"):
		MissionManager.spawner.call("dismount_police", v, level)
	queue_free()
