class_name CivilianController
extends NPCActor
## Civil : marche sur l'anneau de trottoir de son bloc (waypoints, pauses), fuit les tirs / les coups / les véhicules qui le touchent.
## v17 : traverse les rues aux coins (passages piétons), est témoin des crimes (CrimeManager : appel à la police), fuit la police armée.
## v13 : script chargé sous Godot 4.3 ; comportement gameplay non testé.

enum S { WALK, IDLE, FLEE, CROSS }

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
var _corner_wp := false             # le waypoint courant est un coin de trottoir (traversée possible)
var _cross_pt := Vector3.ZERO
var _cross_center := Vector3.ZERO
var _cross_t := 0.0

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

func _crime_kind(killed: bool) -> String:
	return "murder" if killed else "assault"

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
	var step := randf_range(6.0, 16.0)
	var q := 2.0 * ring_half
	_corner_wp = false
	if randf() < 0.6:
		var corner := (floorf(ring_t / q) + 1.0) * q if ring_dir > 0.0 else (ceilf(ring_t / q) - 1.0) * q
		if absf(corner - ring_t) <= step and absf(corner - ring_t) > 0.5:
			ring_t = corner
			_corner_wp = true
			_wp = ring_point(ring_center, ring_half, ring_t)
			return
	ring_t += ring_dir * step
	_wp = ring_point(ring_center, ring_half, ring_t)

## Abscisse curviligne de l'anneau pour un point local (x, z) du bloc (inverse de ring_point).
static func ring_t_of(lx: float, lz: float, h: float) -> float:
	if absf(lz + h) < 0.05 and lx < h - 0.05:
		return lx + h
	if absf(lx - h) < 0.05 and lz < h - 0.05:
		return 2.0 * h + (lz + h)
	if absf(lz - h) < 0.05 and lx > -h + 0.05:
		return 4.0 * h + (h - lx)
	return 6.0 * h + (h - lz)

## Au coin de trottoir : traverse la rue vers le coin du bloc voisin (passage piétonnier), si ce bloc existe et est chargé.
func _try_cross() -> bool:
	if WorldManager.city == null:
		return false
	var h := ring_half
	var l := to_local_ring()
	# coin le plus proche du joueur-PNJ
	var cx := h if l.x > 0.0 else -h
	var cz := h if l.z > 0.0 else -h
	var dirs: Array = []
	if absf(l.x - cx) < 2.5 and absf(l.z - cz) < 2.5:
		dirs = [Vector3(signf(cx), 0, 0), Vector3(0, 0, signf(cz))]
	if dirs.is_empty():
		return false
	var d: Vector3 = dirs[randi() % dirs.size()]
	var pitch := WorldManager.pitch()
	var nb := WorldManager.block_of(ring_center + d * pitch)
	if not WorldManager.in_bounds(nb) or not WorldManager.sectors.has(nb):
		return false
	var corner_world := Vector3(ring_center.x + cx, 0.1, ring_center.z + cz)
	_cross_pt = corner_world + d * (pitch - 2.0 * h)
	_cross_center = WorldManager.block_center(nb)
	var loc := _cross_pt - _cross_center
	_cross_t = ring_t_of(loc.x, loc.z, h)
	_set_state(S.CROSS)
	return true

func to_local_ring() -> Vector3:
	return global_position - ring_center

func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0

func _think(dt: float) -> void:
	_state_t += dt
	_face_dir = Vector3.ZERO
	match state:
		S.WALK:
			if _flat_dist(_wp) < 1.3:
				if _corner_wp and randf() < 0.45 and _try_cross():
					return
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
		S.CROSS:
			if _flat_dist(_cross_pt) < 1.2 or _state_t > 25.0:
				ring_center = _cross_center
				ring_t = _cross_t
				_next_wp()
				_set_state(S.WALK)
			else:
				_go(_cross_pt, walk_v * 1.2)
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
	if state == S.CROSS:
		_set_state(S.WALK)
		_wp = ring_point(ring_center, ring_half, ring_t)
		return
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
