class_name Player
extends CharacterBody3D
## Joueur : CharacterBody3D (capsule adaptée à la taille du personnage) + GameCharacter (AnimationTree à couches) + caméra
## SpringArm3D + PlayerCombat. Entrées : clavier/souris, manette, TouchControls. Entrées gameplay non testées.

signal health_changed()
signal died()
signal hud_damage_number(pos: Vector3, amount: float, head: bool)
signal prompt_changed(text: String)

const GRAVITY := 20.0
const JUMP_SPEED := 5.4
const ACCEL := 16.0

@export var character_id := ""          # vide = GameManager.character_id

var max_health := 100.0
var health := 100.0
var dead := false
var height := 1.75
var gc: GameCharacter
var combat: PlayerCombat
var touch: TouchControls = null
var rig: Node3D
var spring: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.25
var face_yaw := 0.0
var aiming := false
var crouching := false
var driving: Vehicle = null
var climbing: Ladder = null
var controls_enabled := true
var speed_now := 0.0
var invuln := 0.0

var _cs: CollisionShape3D
var _cap: CapsuleShape3D
var _lock := 0.0
var _rolling := false
var _roll_vel := Vector3.ZERO
var _move_dir := Vector3(0, 0, 1)
var _walk_v := 1.1
var _run_v := 3.6
var _sprint_v := 5.2
var _was_air := false
var _air_t := 0.0
var _scale := 1.0
var _base_len := 3.2
var _target: Node = null
var _find_t := 0.0
var _prompt := ""
var _step_t := 0.0
var _combat_t := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8 | 16
	var id := character_id if character_id != "" else GameManager.character_id
	var entry := GameManager.character_entry(id)
	height = float(entry["height_m"])
	_scale = clampf(height / 1.75, 0.55, 1.0)
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.28 * clampf(_scale, 0.7, 1.0)
	_cap.height = height
	_cs = CollisionShape3D.new()
	_cs.shape = _cap
	_cs.position.y = height * 0.5
	add_child(_cs)

	gc = GameCharacter.new()
	add_child(gc)
	if gc.setup(entry):
		gc.apply_root_motion = false
		if not gc.build_tree():
			push_warning("AnimationTree indisponible : repli sur AnimationPlayer (pas de couches haut/bas)")
		var w := gc.anim_speed("walk")
		_walk_v = w if w > 0.3 else _walk_v
		var r := gc.anim_speed("run")
		_run_v = r if r > _walk_v else _run_v
		var s := gc.anim_speed("sprint")
		_sprint_v = s if s > _run_v else _sprint_v
		gc.apply_inventory_outfit()
	InventoryManager.changed.connect(func() -> void:
		if gc != null:
			gc.apply_inventory_outfit())

	rig = Node3D.new()
	rig.position.y = height * 0.86
	add_child(rig)
	spring = SpringArm3D.new()
	_base_len = 3.2 * clampf(_scale, 0.75, 1.0)
	spring.spring_length = _base_len
	spring.collision_mask = 1
	var ss := SphereShape3D.new()
	ss.radius = 0.2
	spring.shape = ss
	spring.add_excluded_object(get_rid())
	spring.rotation.x = pitch
	rig.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.h_offset = 0.45 * _scale
	cam.far = float(SettingsManager.get_value("graphics", "view_distance")) + 40.0
	cam.current = true
	spring.add_child(cam)

	combat = PlayerCombat.new()
	add_child(combat)
	combat.setup(self)
	health = max_health

func set_touch(t: TouchControls) -> void:
	touch = t

# ------------------------------------------------------------------ entrées caméra
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled and not get_tree().paused:
		var sens := float(SettingsManager.get_value("controls", "sensitivity"))
		var inv := -1.0 if bool(SettingsManager.get_value("controls", "invert_y")) else 1.0
		yaw -= ev.relative.x * 0.003 * sens
		pitch = clampf(pitch - ev.relative.y * 0.003 * sens * inv, -1.25, 0.6)

func _update_look(delta: float) -> void:
	if not controls_enabled:
		return
	var sens := float(SettingsManager.get_value("controls", "sensitivity"))
	var inv := -1.0 if bool(SettingsManager.get_value("controls", "invert_y")) else 1.0
	if touch != null:
		var d := touch.consume_look()
		yaw -= d.x * 0.004 * sens
		pitch -= d.y * 0.004 * sens * inv
	var pad := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= pad.x * 2.6 * sens * delta
	pitch -= pad.y * 1.8 * sens * delta * inv
	pitch = clampf(pitch, -1.25, 0.6)

func add_recoil(deg: float) -> void:
	pitch = clampf(pitch + deg_to_rad(deg) * 0.5, -1.25, 0.6)
	yaw += randf_range(-1.0, 1.0) * deg_to_rad(deg) * 0.15

# ------------------------------------------------------------------ boucle principale
func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	_lock = maxf(0.0, _lock - delta)
	_combat_t = maxf(0.0, _combat_t - delta)
	if dead:
		velocity = Vector3(0, velocity.y - GRAVITY * delta if not is_on_floor() else 0.0, 0)
		move_and_slide()
		return
	_update_look(delta)
	if driving != null:
		_update_driving(delta)
		return
	if climbing != null:
		_update_climb(delta)
		return
	_update_aim(delta)
	rig.rotation.y = yaw
	spring.rotation.x = pitch
	_update_interact(delta)

	var iv := Vector2.ZERO
	if controls_enabled:
		iv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch != null and touch.move_vector.length() > 0.05:
			iv = touch.move_vector
	var mag := iv.length()

	if _rolling:
		velocity.x = _roll_vel.x
		velocity.z = _roll_vel.z
		if _lock <= 0.0:
			_rolling = false
			gc.play("idle")
	else:
		var target := 0.0
		if mag > 0.1:
			var sprint := controls_enabled and Input.is_action_pressed("sprint") and not aiming and not crouching
			if sprint:
				target = _sprint_v
			elif crouching or aiming:
				target = _walk_v * 0.85
			elif mag < 0.55:
				target = _walk_v
			else:
				target = _run_v
			_move_dir = (Basis(Vector3.UP, yaw) * Vector3(iv.x, 0, iv.y)).normalized()
		if _lock > 0.0 and not _rolling:
			target *= 0.3
		speed_now = move_toward(speed_now, target, ACCEL * delta)
		velocity.x = _move_dir.x * speed_now
		velocity.z = _move_dir.z * speed_now

	if is_on_floor():
		velocity.y = 0.0
		if _was_air:
			_was_air = false
			if not _rolling and _lock <= 0.0:
				gc.play("idle")
		if controls_enabled and _lock <= 0.0 and not _rolling:
			if Input.is_action_just_pressed("jump") and not crouching:
				velocity.y = JUMP_SPEED
				_start_air()
			elif Input.is_action_just_pressed("roll") and not crouching:
				_start_roll(mag > 0.1)
			elif Input.is_action_just_pressed("crouch"):
				_set_crouch(not crouching)
	else:
		velocity.y -= GRAVITY * delta
		_air_t += delta
		if not _was_air and _air_t > 0.18:
			_start_air()
	if is_on_floor():
		_air_t = 0.0

	if controls_enabled:
		_handle_actions()
	combat.update(delta, controls_enabled and not _rolling and not dead and climbing == null)
	move_and_slide()

	# orientation du modèle : caméra si on vise/tire, sinon sens du déplacement
	var shooting := aiming or _combat_t > 0.0 or Input.is_action_pressed("fire")
	if _rolling:
		face_yaw = atan2(_roll_vel.x, _roll_vel.z)
	elif shooting and controls_enabled:
		face_yaw = yaw + PI
	elif speed_now > 0.3:
		face_yaw = atan2(_move_dir.x, _move_dir.z)
	gc.rotation.y = lerp_angle(gc.rotation.y, face_yaw, 1.0 - exp(-14.0 * delta))

	_update_anim(delta, mag)

func _update_aim(delta: float) -> void:
	var def := combat.def
	var want := controls_enabled and Input.is_action_pressed("aim") and def != null and not def.melee
	aiming = want
	var tl := _base_len * (0.62 if aiming else 1.0)
	spring.spring_length = lerpf(spring.spring_length, tl, 1.0 - exp(-10.0 * delta))
	var tf := def.fov_aim if (aiming and def != null) else 70.0
	cam.fov = lerpf(cam.fov, tf, 1.0 - exp(-10.0 * delta))
	cam.h_offset = lerpf(cam.h_offset, (0.55 if aiming else 0.45) * _scale, 1.0 - exp(-10.0 * delta))

func _update_anim(delta: float, mag: float) -> void:
	if _rolling or _lock > 0.0:
		return
	if _was_air:
		return
	if crouching and speed_now < 0.2:
		if gc.tree_active and gc.current_base_state() != "crouch":
			gc.play("crouch")
		elif not gc.tree_active:
			gc.play("crouch")
	else:
		if gc.tree_active:
			if gc.current_base_state() != "loco":
				gc.play("idle")
			gc.set_loco_speed(speed_now)
		else:
			if speed_now > _run_v + 0.6:
				gc.play("sprint")
			elif speed_now > _run_v * 0.55 and mag > 0.1:
				gc.play("run")
			elif speed_now > 0.2:
				gc.play("walk")
			else:
				gc.play("idle")
	# pas
	if is_on_floor() and speed_now > 0.5:
		_step_t -= delta * speed_now
		if _step_t <= 0.0:
			_step_t = 1.3
			AudioManager.play_sfx("step", "Steps", global_position, -6.0)

func _start_air() -> void:
	_was_air = true
	if gc.tree_active:
		var air_time := maxf(2.0 * JUMP_SPEED / GRAVITY, 0.3)
		gc.set_jump_scale(gc.duration("jump") / air_time)
	gc.play("jump", 0.1)

func _start_roll(moving: bool) -> void:
	var dur := gc.duration("roll")
	var dist := gc.anim_distance("roll")
	if dist < 0.5:
		dist = 2.4 * _scale
	var dir := _move_dir if moving else (Basis(Vector3.UP, gc.rotation.y) * Vector3(0, 0, 1))
	dir.y = 0.0
	dir = dir.normalized()
	_rolling = true
	_roll_vel = dir * (dist / dur)
	_lock = dur
	invuln = dur * 0.7
	speed_now = 0.0
	if gc.tree_active:
		gc.tree_travel("roll", true)
	else:
		gc.play("roll", 0.05)

func _set_crouch(c: bool) -> void:
	crouching = c
	var h := height * (0.62 if c else 1.0)
	_cap.height = h
	_cs.position.y = h * 0.5
	rig.position.y = height * (0.62 if c else 0.86)

func _handle_actions() -> void:
	if Input.is_action_just_pressed("weapon"):
		InventoryManager.cycle_weapon()
	if Input.is_action_just_pressed("heal"):
		if InventoryManager.use_heal(self):
			UIManager.toast("Soin utilisé", Color(0.5, 1, 0.5), 1.2)
		elif InventoryManager.use_armor():
			UIManager.toast("Gilet enfilé", Color(0.6, 0.8, 1), 1.2)
	if _lock <= 0.0 and combat.ready_to_attack():
		if Input.is_action_just_pressed("punch"):
			var bat := combat.def != null and combat.def.melee
			combat.melee_attack(combat.def.damage if bat else 15.0, 1.5, "punch")
		elif Input.is_action_just_pressed("kick"):
			combat.melee_attack(20.0, 1.7, "kick")
	if Input.is_action_just_pressed("interact") and _target != null and is_instance_valid(_target):
		_target.call("interact", self)

func start_melee(anim: String) -> void:
	_combat_t = 0.8
	_lock = gc.duration(anim) * 0.85
	face_yaw = yaw + PI
	gc.rotation.y = face_yaw
	if gc.tree_active:
		gc.tree_travel(anim, true)
	else:
		gc.play(anim, 0.05)

# ------------------------------------------------------------------ interaction
func _update_interact(delta: float) -> void:
	_find_t -= delta
	if _find_t > 0.0:
		return
	_find_t = 0.12
	var best: Node3D = null
	var best_d := 999.0
	for n in get_tree().get_nodes_in_group("interactable"):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var d := Vector2(n3.global_position.x - global_position.x, n3.global_position.z - global_position.z).length()
		var rng := float(n3.get("interact_range")) if n3.get("interact_range") != null else 1.8
		if d <= rng and d < best_d and absf(n3.global_position.y - global_position.y) < 4.0:
			best = n3
			best_d = d
	_target = best
	var txt := ""
	if best != null and best.get("prompt") != null:
		txt = str(best.get("prompt"))
	if txt != _prompt:
		_prompt = txt
		prompt_changed.emit(txt)

func interact_prompt() -> String:
	return _prompt

# ------------------------------------------------------------------ santé
func take_damage(amount: float, _from: Node = null, _head := false) -> void:
	if dead or invuln > 0.0 or amount <= 0.0:
		return
	var dmg := amount
	if InventoryManager.armor > 0.0:
		var absorbed := minf(InventoryManager.armor, dmg * 0.6)
		InventoryManager.armor -= absorbed
		dmg -= absorbed
		InventoryManager.changed.emit()
	health -= dmg
	SettingsManager.vibrate(35)
	health_changed.emit()
	if health <= 0.0:
		_die()
	elif dmg >= 15.0 and speed_now < 0.5 and _lock <= 0.0 and driving == null and climbing == null:
		_lock = 0.45
		if gc.tree_active:
			gc.tree_travel("damage", true)
		else:
			gc.play("damage", 0.05)

func heal(n: float) -> void:
	health = minf(max_health, health + n)
	health_changed.emit()

func _die() -> void:
	dead = true
	health = 0.0
	if driving != null:
		exit_vehicle(true)
	climbing = null
	_rolling = false
	if gc.tree_active:
		gc.tree_travel("death", true)
	else:
		gc.play("death", 0.1)
	GameManager.deaths += 1
	health_changed.emit()
	died.emit()

func respawn(pos: Vector3) -> void:
	dead = false
	health = max_health
	invuln = 2.0
	_lock = 0.0
	_was_air = false
	speed_now = 0.0
	velocity = Vector3.ZERO
	global_position = pos
	if crouching:
		_set_crouch(false)
	gc.play("idle", 0.1)
	health_changed.emit()

# ------------------------------------------------------------------ véhicule
func enter_vehicle(v: Vehicle) -> void:
	if driving != null or v.driver != null or dead:
		return
	driving = v
	v.set_driver(self)
	_cs.disabled = true
	collision_layer = 0
	velocity = Vector3.ZERO
	speed_now = 0.0
	spring.add_excluded_object(v.get_rid())
	spring.spring_length = 6.5 * clampf(_scale, 0.85, 1.0)
	_base_len = spring.spring_length
	pitch = -0.28
	gc.position = Vector3(0, -float(gc.manifest_entry["drive_seat"]["butt_y"]), -float(gc.manifest_entry["drive_seat"]["hips_z"]))
	gc.rotation.y = 0.0
	if gc.tree_active:
		gc.tree_travel("drive", true)
	else:
		gc.play("drive", 0.1)
	if touch != null:
		touch.set_context("vehicle")

func _update_driving(delta: float) -> void:
	var v := driving
	if v == null or not is_instance_valid(v):
		exit_vehicle(true)
		return
	global_transform = Transform3D(v.global_transform.basis, v.anchor.global_position)
	rig.rotation.y = PI   # caméra derrière le véhicule (le véhicule avance vers +Z local)
	spring.rotation.x = lerpf(spring.rotation.x, clampf(pitch, -0.9, -0.05), 1.0 - exp(-6.0 * delta))
	cam.fov = lerpf(cam.fov, 70.0 + clampf(absf(v.speed) * 0.6, 0.0, 14.0), 1.0 - exp(-4.0 * delta))
	cam.h_offset = lerpf(cam.h_offset, 0.0, 1.0 - exp(-8.0 * delta))
	var iv := Vector2.ZERO
	if controls_enabled:
		iv = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch != null and touch.move_vector.length() > 0.05:
			iv = touch.move_vector
	v.set_controls(-iv.y, iv.x, controls_enabled and Input.is_action_pressed("jump"))
	_find_t = 0.0
	if controls_enabled and Input.is_action_just_pressed("interact"):
		exit_vehicle(false)

func exit_vehicle(forced: bool) -> void:
	var v := driving
	if v == null:
		return
	driving = null
	if is_instance_valid(v):
		spring.remove_excluded_object(v.get_rid())
		v.set_driver(null)
		var side := v.global_transform.basis.x * 1.7
		global_transform = Transform3D(Basis.IDENTITY, v.global_position + side + Vector3(0, 0.3, 0))
		face_yaw = v.global_rotation.y
	else:
		global_transform = Transform3D(Basis.IDENTITY, global_position)
	gc.position = Vector3.ZERO
	gc.rotation.y = face_yaw
	_cs.disabled = false
	collision_layer = 2
	velocity = Vector3.ZERO
	_base_len = 3.2 * clampf(_scale, 0.75, 1.0)
	spring.spring_length = _base_len
	yaw = face_yaw + PI
	pitch = -0.25
	cam.h_offset = 0.45 * _scale
	if not dead:
		gc.play("idle", 0.1)
	if touch != null:
		touch.set_context("foot")
	if forced:
		velocity = Vector3.ZERO

# ------------------------------------------------------------------ échelle
func start_climb(l: Ladder) -> void:
	if climbing != null or driving != null or dead:
		return
	climbing = l
	velocity = Vector3.ZERO
	var base := l.global_position
	global_position = Vector3(base.x, clampf(global_position.y, base.y, l.top_y()), base.z) + l.global_transform.basis * Vector3(0, 0, 0.42)
	face_yaw = l.global_rotation.y + PI
	gc.rotation.y = face_yaw
	if gc.tree_active:
		gc.tree_travel("climb", true)
	else:
		gc.play("climb", 0.1)

func _update_climb(delta: float) -> void:
	var l := climbing
	rig.rotation.y = yaw
	spring.rotation.x = pitch
	var up := 0.0
	if controls_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch != null and touch.move_vector.length() > 0.05:
			iv = touch.move_vector
		up = -iv.y
		if Input.is_action_just_pressed("jump"):
			climbing = null
			velocity = l.global_transform.basis * Vector3(0, 2.5, 2.0)
			gc.play("jump", 0.1)
			return
	gc.set_climb_scale(clampf(absf(up), 0.0, 1.0))
	global_position.y += up * 0.5 * delta
	if global_position.y >= l.top_y():
		global_position = l.top_exit()
		climbing = null
		gc.play("idle", 0.1)
	elif global_position.y <= l.global_position.y and up < -0.1:
		climbing = null
		gc.play("idle", 0.1)

# ------------------------------------------------------------------ sauvegarde
func restore(pos: Vector3, yaw_v: float, hp: float) -> void:
	global_position = pos
	yaw = yaw_v
	health = clampf(hp, 1.0, max_health)
	health_changed.emit()
