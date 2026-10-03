class_name Player
extends CharacterBody3D
## Joueur : CharacterBody3D (capsule, gravité, collisions) + GameCharacter (modèle/animations) + caméra SpringArm3D.
## Clavier/souris : ZQSD/WASD, Espace saut, Maj sprint, C accroupi, V roulade, J poing, K pied, F tir, R recharge, E interagir.
## Tactile : TouchControls. NON exécuté dans Godot (voir README_GODOT.md) : à tester et régler.

signal health_changed(hp: float)
signal weapon_changed(text: String)
signal prompt_changed(text: String)

@export var character_id := "homme_barbu"
## false : vitesse codée = vitesse de l'animation (pas de patinage) ; true : vitesse = root motion de l'animation.
@export var use_root_motion := false
@export var max_health := 100.0

const GRAVITY := 22.0
const JUMP_SPEED := 5.2
const INTERACT_RANGE := 1.8

var health := 100.0
var gc: GameCharacter
var touch: TouchControls
var cam_rig: Node3D
var spring: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.3
var height := 1.75
var weapon: Weapon = null
var driving: Vehicle = null
var climbing: Ladder = null
var crouching := false
var dead := false

var _cap: CapsuleShape3D
var _shape: CollisionShape3D
var _lock := 0.0
var _action := ""
var _cur_anim := ""
var _roll_dir := Vector3.ZERO
var _target: Node = null
var _spawn := Vector3.ZERO

func _ready() -> void:
	GameInput.setup()
	add_to_group("player")
	_spawn = global_position
	health = max_health
	var man := GameCharacter.load_manifest()
	var entry: Dictionary = man["characters"][0]
	for c in man["characters"]:
		if c["id"] == character_id:
			entry = c
	height = float(entry["height_m"])
	gc = GameCharacter.new()
	gc.apply_root_motion = false
	add_child(gc)
	gc.setup(entry)
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.28 if height > 1.4 else 0.22
	_shape = CollisionShape3D.new()
	_shape.shape = _cap
	add_child(_shape)
	_set_capsule(1.0)
	cam_rig = Node3D.new()
	cam_rig.top_level = true
	add_child(cam_rig)
	spring = SpringArm3D.new()
	spring.spring_length = 3.2
	spring.margin = 0.2
	spring.add_excluded_object(get_rid())
	cam_rig.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 60
	spring.add_child(cam)
	cam.make_current()
	_emit_weapon()

func _set_capsule(f: float) -> void:
	_cap.height = height * f
	_shape.position.y = height * f * 0.5

func _move_input() -> Vector2:
	if touch != null and touch.move_vector.length() > 0.05:
		return touch.move_vector
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _unhandled_input(ev: InputEvent) -> void:
	if DisplayServer.is_touchscreen_available():
		return
	if ev is InputEventMouseButton and ev.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= ev.relative.x * 0.003
		pitch = clampf(pitch - ev.relative.y * 0.003, -1.1, 0.4)

func _process(delta: float) -> void:
	if touch != null:
		var l := touch.consume_look()
		yaw -= l.x * 0.005
		pitch = clampf(pitch - l.y * 0.004, -1.1, 0.4)
	if driving != null:
		global_transform = driving.anchor.global_transform
		yaw = lerp_angle(yaw, driving.rotation.y + PI, 1.5 * delta)
	cam_rig.global_position = global_position + Vector3(0, height * 0.9, 0)
	cam_rig.rotation = Vector3(pitch, yaw, 0)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if driving != null:
		var di := _move_input()
		driving.set_controls(-di.y, di.x, Input.is_action_pressed("sprint"))
		if Input.is_action_just_pressed("interact"):
			_exit_vehicle()
		return
	_find_target()
	if climbing != null:
		_climb(delta)
		return

	_lock = maxf(0.0, _lock - delta)
	if _lock <= 0.0 and _action != "":
		if _action == "roll":
			_set_capsule(0.65 if crouching else 1.0)
		_action = ""
	var on_floor := is_on_floor()
	var inp := _move_input()
	var dir := Basis(Vector3.UP, yaw) * Vector3(inp.x, 0, inp.y)
	var vy := velocity.y
	var hv := Vector3(velocity.x, 0, velocity.z)

	# --- actions ---
	if _lock <= 0.0 and on_floor:
		if Input.is_action_just_pressed("interact") and _target != null:
			_target.interact(self)
			if driving != null or climbing != null:
				return
		elif Input.is_action_just_pressed("jump") and not crouching:
			vy = JUMP_SPEED
			_cur_anim = "jump"
			gc.player.speed_scale = gc.duration("jump") / (2.0 * JUMP_SPEED / GRAVITY)
			gc.play("jump", 0.05)
		elif Input.is_action_just_pressed("roll"):
			_roll_dir = dir.normalized() if dir.length() > 0.1 else gc.global_transform.basis.z
			_roll_dir.y = 0.0
			_set_capsule(0.55)
			_start_action("roll")
		elif Input.is_action_just_pressed("punch"):
			_attack("punch", weapon.damage if (weapon != null and weapon.melee) else 12.0, 0.35)
		elif Input.is_action_just_pressed("kick"):
			_attack("kick", 18.0, 0.4)
		elif Input.is_action_just_pressed("fire"):
			_fire()
		elif Input.is_action_just_pressed("reload"):
			_reload()
		elif Input.is_action_just_pressed("crouch"):
			crouching = not crouching
			_set_capsule(0.65 if crouching else 1.0)
			_cur_anim = ""

	# --- déplacement ---
	var mode := "idle"
	if _lock > 0.0:
		hv = _roll_dir * (gc.anim_distance("roll") / gc.duration("roll")) if _action == "roll" else Vector3.ZERO
	elif on_floor:
		hv = Vector3.ZERO
		if inp.length() > 0.15:
			mode = "walk" if (crouching or inp.length() < 0.55) else "run"
			if Input.is_action_pressed("sprint") and not crouching:
				mode = "sprint"
			var sp := gc.anim_speed(mode) * (0.6 if crouching else 1.0)
			if use_root_motion and not crouching:
				var rm := gc.consume_root_motion()
				hv = Vector3(rm.x, 0, rm.z) / delta
			else:
				hv = dir.normalized() * sp
	if on_floor and vy <= 0.0:
		vy = -0.5
	else:
		vy -= GRAVITY * delta

	# --- orientation du modèle (+Z = avant du modèle) ---
	if _lock > 0.0 and _action == "shoot":
		gc.rotation.y = lerp_angle(gc.rotation.y, yaw + PI, 15.0 * delta)
	elif hv.length() > 0.1:
		gc.rotation.y = lerp_angle(gc.rotation.y, atan2(hv.x, hv.z), 12.0 * delta)

	# --- animation de déplacement ---
	if _lock <= 0.0 and on_floor:
		if mode == "idle":
			_play_loop("crouch" if crouching else "idle", 1.0)
		else:
			_play_loop(mode, 0.6 if crouching else 1.0)
	elif _lock <= 0.0 and not on_floor and _cur_anim != "jump":
		_play_loop("jump", 0.5)   # chute sans saut : la pose de saut sert de chute

	velocity = Vector3(hv.x, vy, hv.z)
	move_and_slide()

func _play_loop(n: String, speed_scale: float) -> void:
	if _cur_anim != n:
		_cur_anim = n
		gc.play(n, 0.2)
	gc.player.speed_scale = speed_scale

func _start_action(n: String, extra := 0.0) -> bool:
	if gc.player == null or not gc.player.has_animation(n):
		return false
	_action = n
	_lock = gc.duration(n) + extra
	_cur_anim = n
	gc.player.speed_scale = 1.0
	gc.play(n, 0.08)
	return true

func _attack(anim: String, dmg: float, hit_at: float) -> void:
	if _start_action(anim):
		get_tree().create_timer(gc.duration(anim) * hit_at).timeout.connect(_melee_hit.bind(dmg))

func _melee_hit(dmg: float) -> void:
	if dead:
		return
	var c := global_position + gc.global_transform.basis.z * 0.9
	for n in get_tree().get_nodes_in_group("damageable"):
		var n3 := n as Node3D
		if n3 == null or n3 == self:
			continue
		var d := Vector2(n3.global_position.x - c.x, n3.global_position.z - c.z).length()
		if d < 0.9 and absf(n3.global_position.y - global_position.y) < 2.0:
			n3.take_damage(dmg, self)

func _fire() -> void:
	if weapon == null or weapon.melee:
		return
	if weapon.ammo <= 0:
		_reload()
		return
	if not _start_action("shoot"):
		return
	weapon.ammo -= 1
	weapon.flash()
	gc.rotation.y = yaw + PI
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * 80.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.size() > 0:
		var col: Object = hit["collider"]
		if col != null and col.has_method("take_damage"):
			col.take_damage(weapon.damage, self)
	_emit_weapon()

func _reload() -> void:
	if weapon == null or weapon.melee or weapon.reserve <= 0 or weapon.ammo >= weapon.mag_size:
		return
	if _start_action("reload"):
		get_tree().create_timer(gc.duration("reload") * 0.8).timeout.connect(func() -> void:
			if weapon != null:
				weapon.reload()
				_emit_weapon())

func equip(kind: String) -> void:
	if weapon != null and weapon.kind == kind and not weapon.melee:
		weapon.reserve += 24
	else:
		if weapon != null:
			weapon.queue_free()
		weapon = Weapon.make(kind)
		if kind != "bat":
			weapon.apply_grip(gc.manifest_entry)   # prise mesurée (pose shoot) ; la batte garde grip_offset
		if gc.attach_to_bone(weapon, "RightHand") == null:
			add_child(weapon)   # repli : os introuvable
	_emit_weapon()

func _emit_weapon() -> void:
	weapon_changed.emit(weapon.hud_text() if weapon != null else "Mains nues")

func take_damage(amount: float, _from: Node = null) -> void:
	if dead:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	if health <= 0.0:
		_die()
	elif _lock <= 0.0:
		_start_action("damage")

func _die() -> void:
	dead = true
	_start_action("death")
	await get_tree().create_timer(3.0).timeout
	global_position = _spawn
	velocity = Vector3.ZERO
	health = max_health
	health_changed.emit(health)
	_lock = 0.0
	_action = ""
	_cur_anim = ""
	dead = false

# --- interaction ---
func _find_target() -> void:
	var best: Node = null
	var bd := 1.0e9
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null:
			continue
		var d := global_position.distance_to(n3.global_position)
		if d < float(n.get("interact_range")) and d < bd:
			bd = d
			best = n
	if best != _target:
		_target = best
		prompt_changed.emit("[E] %s" % str(best.get("prompt")) if best != null else "")

# --- échelle ---
func start_climb(l: Ladder) -> void:
	climbing = l
	velocity = Vector3.ZERO
	var y := clampf(global_position.y, l.global_position.y, l.top_y())
	var p := l.global_position + l.global_basis * Vector3(0, 0, 0.45)
	global_position = Vector3(p.x, y, p.z)
	gc.rotation.y = l.global_rotation.y + PI
	_cur_anim = "climb"
	gc.play("climb", 0.1)

func _climb(delta: float) -> void:
	var inp := _move_input()
	var vy := -inp.y * 0.5          # l'animation « climb » avance de 0,5 m/s en hauteur
	gc.player.speed_scale = signf(vy) if absf(vy) > 0.05 else 0.0
	global_position.y += vy * delta
	if Input.is_action_just_pressed("jump"):
		var back := climbing.global_basis.z * 3.0
		_stop_climb()
		velocity = Vector3(back.x, 2.0, back.z)
	elif global_position.y >= climbing.top_y():
		global_position = climbing.top_exit()
		_stop_climb()
	elif global_position.y <= climbing.global_position.y and vy < 0.0:
		_stop_climb()

func _stop_climb() -> void:
	climbing = null
	gc.player.speed_scale = 1.0
	_cur_anim = ""

# --- véhicule ---
func enter_vehicle(v: Vehicle) -> void:
	driving = v
	v.driver = self
	velocity = Vector3.ZERO
	_shape.set_deferred("disabled", true)
	gc.rotation = Vector3.ZERO
	var seat: Dictionary = gc.manifest_entry.get("drive_seat", {})
	if seat.has("butt_y"):      # fesses du modèle posées sur le point d'assise (valeurs mesurées sur la pose « drive »)
		gc.position = Vector3(0.0, -float(seat["butt_y"]), -float(seat["hips_z"]))
	_cur_anim = "drive"
	gc.player.speed_scale = 1.0
	gc.play("drive", 0.2)

func _exit_vehicle() -> void:
	var v := driving
	driving = null
	v.driver = null
	v.set_controls(0.0, 0.0, false)
	global_position = v.to_global(Vector3(1.8, 0.1, 0.0))
	rotation = Vector3.ZERO
	gc.position = Vector3.ZERO
	_shape.set_deferred("disabled", false)
	_cur_anim = ""
