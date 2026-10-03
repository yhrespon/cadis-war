class_name CivilianController
extends NPCActor
## Civil : marche sur l'anneau de trottoir de son bloc (waypoints, pauses), fuit les tirs / les coups / les véhicules qui le touchent.
## Pas de traversée de rue, pas de bâtiments, pas de réactions à la police (aucun système de recherche dans le projet).
## v13 : script chargé sous Godot 4.3 ; comportement gameplay non testé.

enum S { WALK, IDLE, FLEE }

const PALETTE: Array = [Color(0.8, 0.25, 0.2), Color(0.2, 0.45, 0.75), Color(0.9, 0.8, 0.3), Color(0.3, 0.6, 0.35), Color(0.85, 0.85, 0.8), Color(0.55, 0.3, 0.6), Color(0.25, 0.25, 0.3)]
const HEAR_FLEE_RADIUS := 30.0

var ring_center := Vector3.ZERO     # centre du bloc (monde)
var ring_half := 24.0               # demi-côté de l'anneau de trottoir
var ring_t := 0.0                   # abscisse curviligne du waypoint courant
var ring_dir := 1.0

var state: int = S.WALK
var _wp := Vector3.ZERO
var _state_t := 0.0
var _idle_for := 3.0
var _speed_mult := 1.0

func _allowed_ages() -> Array:
	return ["adulte", "ado", "enfant"]

## Point de l'anneau (carré de demi-côté h) à l'abscisse t (périmètre 8h), y = 0,1.
static func ring_point(center: Vector3, h: float, t: float) -> Vector3:
	var l := 8.0 * h
	var s := fposmod(t, l)
	var side := int(s / (2.0 * h))
	var u := s - float(side) * 2.0 * h
	var local := Vector3.ZERO
	match side:
		0:
			local = Vector3(-h + u, 0.0, -h)
		1:
			local = Vector3(h, 0.0, -h + u)
		2:
			local = Vector3(h - u, 0.0, h)
		_:
			local = Vector3(-h, 0.0, h - u)
	return Vector3(center.x + local.x, 0.1, center.z + local.z)

func _setup_role() -> void:
	add_to_group("civilian")
	collision_layer = 8
	collision_mask = 1 | 2 | 8 | 16
	max_hp = 40.0
	_speed_mult = randf_range(0.85, 1.1)
	ring_dir = 1.0 if randf() < 0.5 else -1.0
	randomize_outfit(PALETTE)
	_wp = ring_point(ring_center, ring_half, ring_t)
	_next_wp()

func _next_wp() -> void:
	ring_t += ring_dir * randf_range(6.0, 16.0)
	_wp = ring_point(ring_center, ring_half, ring_t)

func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0

func _think(dt: float) -> void:
	_state_t += dt
	_face_dir = Vector3.ZERO
	match state:
		S.WALK:
			if _flat_dist(_wp) < 1.3:
				if randf() < 0.3:
					_idle_for = randf_range(2.0, 6.0)
					_set_state(S.IDLE)
					_stop()
				else:
					_next_wp()
			else:
				_go(_wp, walk_v * _speed_mult)
		S.IDLE:
			_stop()
			if _state_t >= _idle_for:
				if randf() < 0.25:
					ring_dir = -ring_dir
				_next_wp()
				_set_state(S.WALK)
		S.FLEE:
			if _state_t > 9.0:
				_set_state(S.IDLE)
				_idle_for = 3.0
				_stop()
			elif _flat_dist(_wp) < 2.0:
				ring_t += ring_dir * 12.0
				_wp = ring_point(ring_center, ring_half, ring_t)
			else:
				_go(_wp, run_v * 0.85)

func _on_stuck() -> void:
	ring_dir = -ring_dir
	ring_t += ring_dir * 4.0
	_wp = ring_point(ring_center, ring_half, ring_t)

## Fuit en suivant l'anneau dans le sens qui éloigne de la menace.
func flee_from(pos: Vector3) -> void:
	var a := ring_point(ring_center, ring_half, ring_t + 12.0)
	var b := ring_point(ring_center, ring_half, ring_t - 12.0)
	ring_dir = 1.0 if a.distance_to(pos) >= b.distance_to(pos) else -1.0
	ring_t += ring_dir * 12.0
	_wp = ring_point(ring_center, ring_half, ring_t)
	_set_state(S.FLEE)

func hear_noise(pos: Vector3, _source: Node) -> void:
	if dead or state == S.FLEE:
		return
	if global_position.distance_to(pos) < HEAR_FLEE_RADIUS:
		flee_from(pos)

func _on_hurt(from: Node, _amount: float) -> void:
	var f := from as Node3D
	flee_from(f.global_position if f != null else global_position + Vector3(1, 0, 0))

func _on_died(_from: Node) -> void:
	remove_from_group("civilian")
