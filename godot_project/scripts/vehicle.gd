class_name Vehicle
extends CharacterBody3D
## Voiture arcade (CharacterBody3D, pas de VehicleBody3D : plus simple et robuste). Avant = +Z, gauche = +X.

const MAX_SPEED := 16.0
const MAX_REVERSE := 5.0
const SEAT_X := 0.4
const SEAT_Y := 0.9      # dessus de la carrosserie
const SEAT_Z := -0.3

var prompt := "Monter dans la voiture"
var interact_range := 3.2
var driver: Node = null
var anchor: Marker3D          # position assise du conducteur
var speed := 0.0
var _throttle := 0.0
var _steer := 0.0
var _brake := false

func _ready() -> void:
	add_to_group("interactable")
	_add_box(Vector3(1.8, 0.6, 4.0), Vector3(0, 0.6, 0), Color(0.7, 0.1, 0.1))
	_add_box(Vector3(1.6, 0.5, 0.06), Vector3(0, 1.15, 0.75), Color(0.55, 0.75, 0.9))   # pare-brise (habitacle ouvert : le conducteur reste visible)
	_add_box(Vector3(0.5, 0.45, 0.5), Vector3(0.4, 1.12, -0.3), Color(0.15, 0.15, 0.18))   # siège (dossier + assise)
	for x in [-0.9, 0.9]:
		for z in [-1.3, 1.3]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.35
			cm.bottom_radius = 0.35
			cm.height = 0.25
			w.mesh = cm
			w.rotation_degrees.z = 90
			w.position = Vector3(x, 0.35, z)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.08, 0.08, 0.08)
			w.material_override = m
			add_child(w)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.8, 1.1, 4.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	anchor = Marker3D.new()
	# Ancre = point d'assise (dessus du siège). Le perso est décalé par Player.enter_vehicle d'après manifest["drive_seat"].
	anchor.position = Vector3(SEAT_X, SEAT_Y, SEAT_Z)
	add_child(anchor)
	_add_box(Vector3(0.36, 0.36, 0.03), Vector3(SEAT_X, SEAT_Y + 0.60, SEAT_Z + 0.45), Color(0.1, 0.1, 0.1))   # volant (disque), mains à ~0,6 m au-dessus de l'assise

func interact(p: Node) -> void:
	if driver == null:
		p.enter_vehicle(self)

func set_controls(throttle: float, steer: float, brake: bool) -> void:
	_throttle = throttle
	_steer = steer
	_brake = brake

func _physics_process(delta: float) -> void:
	var t := _throttle if driver != null else 0.0
	var target := t * MAX_SPEED if t >= 0.0 else t * MAX_REVERSE
	var accel := 9.0 if absf(target) > absf(speed) else 6.0
	speed = move_toward(speed, target, accel * delta)
	if _brake and driver != null:
		speed = move_toward(speed, 0.0, 24.0 * delta)
	if absf(speed) > 0.3 and driver != null:
		rotation.y -= _steer * 1.7 * delta * clampf(speed / 6.0, -1.0, 1.0)   # steer > 0 = droite
	var vy := velocity.y - 22.0 * delta if not is_on_floor() else 0.0
	var fwd := global_transform.basis.z
	velocity = Vector3(fwd.x * speed, vy, fwd.z * speed)
	move_and_slide()
	if is_on_wall():
		speed *= 0.5

func _add_box(size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	mi.material_override = m
	add_child(mi)
