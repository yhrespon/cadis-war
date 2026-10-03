class_name Vehicle
extends CharacterBody3D
## Voiture arcade (CharacterBody3D). Avant = +Z, gauche = +X (comme les personnages). Habitacle ouvert : le conducteur reste
## visible. Siège/volant dimensionnés d'après manifest["drive_seat"] (butt_y, hips_z) par Player.enter_vehicle().
## Dégâts : collisions (perte de vitesse brutale), tirs ; renverse les piétons à vitesse élevée.

var def: VehicleDef
var hp := 200.0
var speed := 0.0
var driver: Player = null
var anchor: Marker3D
var prompt := "Monter dans le véhicule"
var interact_range := 3.0
var persistent := false
var destroyed := false
var height := 1.5

var _throttle := 0.0
var _steer := 0.0
var _brake := false
var _hit_area: Area3D
var _hit_cd: Dictionary = {}
var _engine: AudioStreamPlayer3D = null
var _body_mats: Array = []

func _ready() -> void:
	if def == null:
		def = VehicleManager.get_def("sedan")
	hp = def.max_hp
	collision_layer = 16
	collision_mask = 1 | 16
	add_to_group("interactable")
	add_to_group("vehicle")
	add_to_group("damageable")
	prompt = "Monter : %s" % def.display_name
	_build()
	_engine = AudioManager.make_loop_3d("engine_loop", "Vehicles")
	if _engine != null:
		add_child(_engine)

func _box(size: Vector3, pos: Vector3, c: Color, translucent := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if translucent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(mi)
	mi.material_override = m
	return mi

func _build() -> void:
	var s := def.size
	var floor_y := 0.32
	var tub_top := def.seat_y + 0.05
	var tub_h := tub_top - floor_y
	var body := _box(Vector3(s.x, tub_h, s.z), Vector3(0, floor_y + tub_h * 0.5, 0), def.body_color)
	_body_mats.append(body.material_override)
	# capot avant + coffre (plus hauts que l'habitacle)
	var hood := _box(Vector3(s.x, 0.1, s.z * 0.28), Vector3(0, tub_top + 0.02, s.z * 0.36), def.body_color)
	_body_mats.append(hood.material_override)
	# toit sur 4 montants (hauteur libre ~1,0 m au-dessus de l'assise : tête d'un adulte assis)
	var roof_y := def.seat_y + 1.05 * clampf(def.cabin_height / 0.55, 0.85, 1.2)
	var roof := _box(Vector3(s.x * 0.92, 0.08, s.z * 0.46), Vector3(0, roof_y, -s.z * 0.04), def.body_color.darkened(0.15))
	_body_mats.append(roof.material_override)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.07, roof_y - tub_top, 0.07), Vector3(sx * s.x * 0.44, tub_top + (roof_y - tub_top) * 0.5, -s.z * 0.04 + sz * s.z * 0.22), Color(0.1, 0.1, 0.12))
	# pare-brise translucide
	_box(Vector3(s.x * 0.86, roof_y - tub_top, 0.04), Vector3(0, tub_top + (roof_y - tub_top) * 0.5, -s.z * 0.04 + s.z * 0.22), Color(0.55, 0.75, 0.9, 0.35), true)
	# siège + volant (volant à ~0,6 m au-dessus de l'assise, devant le conducteur)
	_box(Vector3(0.5, 0.1, 0.5), Vector3(def.seat_x, def.seat_y - 0.05, def.seat_z), Color(0.15, 0.15, 0.18))
	_box(Vector3(0.5, 0.55, 0.1), Vector3(def.seat_x, def.seat_y + 0.28, def.seat_z - 0.28), Color(0.15, 0.15, 0.18))
	var wheel := _box(Vector3(0.36, 0.36, 0.04), Vector3(def.seat_x, def.seat_y + 0.5, def.seat_z + 0.5), Color(0.08, 0.08, 0.08))
	wheel.rotation_degrees.x = -35.0
	# phares
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.25, 0.12, 0.05), Vector3(sx * s.x * 0.34, floor_y + tub_h * 0.6, s.z * 0.5), Color(1.0, 0.95, 0.7))
		_box(Vector3(0.25, 0.1, 0.05), Vector3(sx * s.x * 0.34, floor_y + tub_h * 0.6, -s.z * 0.5), Color(0.8, 0.1, 0.1))
	# roues (rayon 0,33 m)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.33
			cm.bottom_radius = 0.33
			cm.height = 0.24
			w.mesh = cm
			w.rotation_degrees.z = 90
			w.position = Vector3(sx * (s.x * 0.5 - 0.05), 0.33, sz * s.z * 0.32)
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.07, 0.07, 0.07)
			w.material_override = m
			add_child(w)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(s.x, tub_top - 0.05, s.z)
	cs.shape = bs
	cs.position = Vector3(0, 0.05 + (tub_top - 0.05) * 0.5, 0)
	add_child(cs)
	anchor = Marker3D.new()
	anchor.position = Vector3(def.seat_x, def.seat_y, def.seat_z)
	add_child(anchor)
	# zone de choc avant (piétons)
	_hit_area = Area3D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 2 | 4 | 8
	var hcs := CollisionShape3D.new()
	var hbs := BoxShape3D.new()
	hbs.size = Vector3(s.x, 1.2, 1.3)
	hcs.shape = hbs
	hcs.position = Vector3(0, 0.8, s.z * 0.5 + 0.4)
	_hit_area.add_child(hcs)
	add_child(_hit_area)

func interact(p: Node) -> void:
	if destroyed or driver != null:
		return
	# détache le véhicule du secteur de ville (il ne doit pas être déchargé avec lui)
	if WorldManager.entities != null and get_parent() != WorldManager.entities:
		reparent(WorldManager.entities, true)
	persistent = true
	p.enter_vehicle(self)

func set_driver(p: Player) -> void:
	driver = p
	if p == null:
		_throttle = 0.0
		_steer = 0.0
		_brake = false
	remove_from_group("interactable") if p != null else add_to_group("interactable")

func set_controls(throttle: float, steer: float, brake: bool) -> void:
	_throttle = throttle
	_steer = steer
	_brake = brake

func _physics_process(delta: float) -> void:
	_hit_cd_tick(delta)
	var t := _throttle if (driver != null and not destroyed) else 0.0
	var target := t * def.max_speed if t >= 0.0 else t * def.max_reverse
	var accel := def.accel if absf(target) > absf(speed) else 6.0
	speed = move_toward(speed, target, accel * delta)
	if (_brake and driver != null) or destroyed:
		speed = move_toward(speed, 0.0, def.brake_force * delta)
	if absf(speed) > 0.3 and driver != null and not destroyed:
		rotation.y -= _steer * def.steer_rate * delta * clampf(speed / 6.0, -1.0, 1.0)
	var vy := velocity.y - 22.0 * delta if not is_on_floor() else 0.0
	var fwd := global_transform.basis.z
	var before := speed
	velocity = Vector3(fwd.x * speed, vy, fwd.z * speed)
	move_and_slide()
	speed = velocity.dot(fwd)
	var lost := absf(before) - absf(speed)
	if lost > 4.0 and get_slide_collision_count() > 0:
		_crash((lost - 4.0) * 7.0)
	if absf(speed) > 3.0:
		_hit_pedestrians()
	if _engine != null:
		if not _engine.playing and driver != null:
			_engine.play()
		elif _engine.playing and driver == null:
			_engine.stop()
		_engine.pitch_scale = 0.8 + absf(speed) / def.max_speed

func _crash(dmg: float) -> void:
	take_damage(dmg, null, false)
	NPCManager.emit_noise(global_position, 40.0, driver)
	AudioManager.play_sfx("car_crash", "Vehicles", global_position)
	if driver != null:
		driver.take_damage(dmg * 0.15)
		SettingsManager.vibrate(60)

func _hit_cd_tick(delta: float) -> void:
	for k in _hit_cd.keys():
		_hit_cd[k] = float(_hit_cd[k]) - delta
		if float(_hit_cd[k]) <= 0.0:
			_hit_cd.erase(k)

func _hit_pedestrians() -> void:
	for b in _hit_area.get_overlapping_bodies():
		if b == driver or not b.has_method("take_damage") or _hit_cd.has(b):
			continue
		if bool(b.get("dead")):
			continue
		_hit_cd[b] = 0.8
		b.call("take_damage", absf(speed) * 4.5, driver, false)
		if b is CharacterBody3D:
			(b as CharacterBody3D).velocity += global_transform.basis.z * absf(speed) * 0.5
		NPCManager.emit_noise(global_position, 35.0, driver)

func take_damage(amount: float, _from: Node = null, _head := false) -> void:
	if destroyed:
		return
	hp -= amount
	if driver != null and _from != null and _from != driver:
		driver.take_damage(amount * 0.3)
	if hp <= 0.0:
		_explode()

func _explode() -> void:
	destroyed = true
	hp = 0.0
	prompt = ""
	remove_from_group("interactable")
	for m in _body_mats:
		(m as StandardMaterial3D).albedo_color = Color(0.08, 0.08, 0.08)
	if driver != null:
		var d := driver
		d.exit_vehicle(true)
		d.take_damage(35.0)
	NPCManager.emit_noise(global_position, 70.0, null)
	for n in get_tree().get_nodes_in_group("damageable"):
		var n3 := n as Node3D
		if n3 != null and n3 != self and n3.global_position.distance_to(global_position) < 5.0:
			n3.call("take_damage", 60.0, null, false)

func to_dict() -> Dictionary:
	return {"id": def.id, "pos": [global_position.x, global_position.y, global_position.z], "yaw": global_rotation.y, "hp": hp}

func apply_dict(d: Dictionary) -> void:
	hp = float(d.get("hp", def.max_hp))
	if hp <= 0.0:
		destroyed = true
