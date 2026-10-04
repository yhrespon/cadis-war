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
var ai_driven := false             # v17 : conduit par un PNJ (TrafficDriver) ; interact() = vol de voiture
var ai_driver: Node = null         # TrafficDriver attaché
var police_skin := false
var siren_on := false
var height := 1.5

var _throttle := 0.0
var _steer := 0.0
var _brake := false
var _hit_area: Area3D
var _hit_cd: Dictionary = {}
var _engine: AudioStreamPlayer3D = null
var _body_mats: Array = []
var _lift := 0.0
var _rotor: Node3D = null
var _icon: Sprite3D = null
var _icon_t := 0.0
var _icon_near := false
var _headlights: Array = []
var _siren_audio: AudioStreamPlayer3D = null
var _siren_lights: Array = []
var _siren_t := 0.0
static var _icon_tex: ImageTexture = null

func _ready() -> void:
	if def == null:
		def = VehicleManager.get_def("sedan")
	hp = def.max_hp
	collision_layer = 16
	collision_mask = 1 | 16
	add_to_group("interactable")
	add_to_group("vehicle")
	add_to_group("damageable")
	prompt = ""                      # v14 : plus de texte ; un symbole flottant (touchable) indique qu'on peut monter
	interact_range = {"moto": 2.6, "truck": 5.0, "heli": 4.6, "plane": 6.5}.get(def.kind, 3.0)
	_build()
	_make_headlights()
	_make_icon_node()
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
		# Les surfaces transparentes coûtent déjà plus cher ; elles ne projettent
		# pas d'ombre utile sur les véhicules procéduraux.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.material_override = m
	return mi

## Couleur de carrosserie (voiture de police : blanc/noir, voir make_police()).
func set_body_color(c: Color) -> void:
	for i in _body_mats.size():
		var m := _body_mats[i] as StandardMaterial3D
		if m != null:
			m.albedo_color = c if i < 2 else c.darkened(0.15)

## Livrée police : carrosserie blanche, gyrophares bleu/rouge sur le toit, sirène optionnelle.
func make_police(siren: bool) -> void:
	police_skin = true
	set_body_color(Color(0.92, 0.93, 0.95))
	add_to_group("police_vehicle")
	var s := def.size
	var roof_y := def.seat_y + 1.12
	for k in 2:
		var sx := -1.0 if k == 0 else 1.0
		_box(Vector3(0.45, 0.14, 0.2), Vector3(sx * 0.3, roof_y + 0.1, -s.z * 0.04), Color(0.1, 0.2, 1.0) if k == 0 else Color(1.0, 0.1, 0.1))
		var l := OmniLight3D.new()
		l.omni_range = 7.0
		l.light_energy = 2.5
		l.light_color = Color(0.2, 0.3, 1.0) if k == 0 else Color(1.0, 0.15, 0.15)
		l.position = Vector3(sx * 0.3, roof_y + 0.3, -s.z * 0.04)
		l.visible = false
		add_child(l)
		_siren_lights.append(l)
	set_siren(siren)

func set_siren(on: bool) -> void:
	siren_on = on
	if on and _siren_audio == null:
		_siren_audio = AudioManager.make_loop_3d("siren_loop", "Vehicles")
		if _siren_audio != null:
			_siren_audio.max_distance = 90.0
			add_child(_siren_audio)
	if _siren_audio != null:
		if on and not _siren_audio.playing:
			_siren_audio.play()
		elif not on:
			_siren_audio.stop()
	for l in _siren_lights:
		(l as Light3D).visible = on

func _tick_siren(delta: float) -> void:
	if not siren_on or _siren_lights.size() < 2:
		return
	_siren_t += delta
	var phase := int(_siren_t * 6.0) % 2 == 0
	(_siren_lights[0] as Light3D).visible = phase
	(_siren_lights[1] as Light3D).visible = not phase

## Un phare orientable (SpotLight3D) : allumé par EnvironmentController la nuit / sous la pluie, seulement près de la caméra.
func _make_headlights() -> void:
	if def.kind == "heli" or def.kind == "plane":
		return
	var l := SpotLight3D.new()
	l.spot_range = 22.0
	l.spot_angle = 38.0
	l.light_energy = 3.0
	l.light_color = Color(1.0, 0.95, 0.8)
	l.shadow_enabled = false
	l.position = Vector3(0, 0.75, def.size.z * 0.5 + 0.1 if def.kind != "moto" else 0.9)
	l.rotation_degrees = Vector3(-6, 180, 0)
	l.visible = false
	l.add_to_group("headlight")
	add_child(l)
	_headlights.append(l)

func is_aircraft() -> bool:
	return def.kind == "heli" or def.kind == "plane"

func icon_height() -> float:
	match def.kind:
		"moto": return 1.9
		"truck": return 3.8
		"heli": return 3.6
		"plane": return 2.7
	return def.seat_y + 1.9

static func _icon_texture() -> ImageTexture:
	if _icon_tex != null:
		return _icon_tex
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(48.0, 48.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= 46.0:
				col = Color(1.0, 0.82, 0.25, 1.0) if d > 41.0 else Color(0.06, 0.07, 0.1, 0.9)
				if d <= 41.0:
					var px := float(x)
					var py := float(y)
					if absf(px - 48.0) <= 7.0 and py >= 22.0 and py <= 52.0:
						col = Color.WHITE
					elif py > 52.0 and py <= 74.0 and absf(px - 48.0) <= (74.0 - py) * 0.95:
						col = Color.WHITE
			img.set_pixel(x, y, col)
	_icon_tex = ImageTexture.create_from_image(img)
	return _icon_tex

func _make_icon_node() -> void:
	_icon = Sprite3D.new()
	_icon.texture = _icon_texture()
	_icon.pixel_size = 0.012
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.shaded = false
	_icon.double_sided = true
	_icon.position = Vector3(0, icon_height(), 0)
	_icon.visible = false
	add_child(_icon)

func _tick_icon(delta: float) -> void:
	if _icon == null:
		return
	_icon_t -= delta
	if _icon_t <= 0.0:
		_icon_t = 0.25
		var pl := get_tree().get_first_node_in_group("player") as Node3D
		var d := 999.0
		if pl != null:
			d = Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length()
		_icon.visible = pl != null and driver == null and not destroyed and d < 14.0
		_icon_near = d <= interact_range
		_icon.modulate = Color(1, 1, 1, 1.0 if _icon_near else 0.55)
	if _icon.visible:
		var k := (1.25 if _icon_near else 0.9) * (1.0 + 0.07 * sin(Time.get_ticks_msec() * 0.006))
		_icon.scale = Vector3.ONE * k

func _wheel(pos: Vector3, r: float, w: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = w
	m.mesh = cm
	m.rotation_degrees.z = 90
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.07, 0.07)
	m.material_override = mat
	add_child(m)

func _finish(col_size: Vector3, col_center: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = col_size
	cs.shape = bs
	cs.position = col_center
	add_child(cs)
	anchor = Marker3D.new()
	anchor.position = Vector3(def.seat_x, def.seat_y, def.seat_z)
	add_child(anchor)
	_hit_area = Area3D.new()
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = 2 | 4 | 8
	var hcs := CollisionShape3D.new()
	var hbs := BoxShape3D.new()
	hbs.size = Vector3(minf(def.size.x, 2.0), 1.2, 1.3)
	hcs.shape = hbs
	hcs.position = Vector3(0, 0.8, col_size.z * 0.5 + 0.4)
	_hit_area.add_child(hcs)
	add_child(_hit_area)

func _seat_boxes() -> void:
	var dark := Color(0.15, 0.15, 0.18)
	_box(Vector3(0.5, 0.1, 0.5), Vector3(def.seat_x, def.seat_y - 0.05, def.seat_z), dark)
	_box(Vector3(0.5, 0.55, 0.1), Vector3(def.seat_x, def.seat_y + 0.28, def.seat_z - 0.28), dark)

func _build_moto() -> void:
	var dark := Color(0.1, 0.1, 0.12)
	var b := _box(Vector3(0.3, 0.3, 1.3), Vector3(0, 0.5, 0), def.body_color)
	_body_mats.append(b.material_override)
	var tank := _box(Vector3(0.32, 0.26, 0.5), Vector3(0, 0.78, 0.3), def.body_color.lightened(0.2))
	_body_mats.append(tank.material_override)
	_box(Vector3(0.3, 0.08, 0.6), Vector3(0, def.seat_y - 0.05, def.seat_z), dark)
	_box(Vector3(0.7, 0.05, 0.05), Vector3(0, 1.0, 0.7), dark)
	_box(Vector3(0.06, 0.6, 0.06), Vector3(0, 0.68, 0.72), dark)
	_box(Vector3(0.2, 0.2, 0.15), Vector3(0, 0.9, 0.8), Color(1.0, 0.95, 0.7))
	_box(Vector3(0.18, 0.1, 0.05), Vector3(0, 0.65, -0.85), Color(0.8, 0.1, 0.1))
	_wheel(Vector3(0, 0.33, 0.75), 0.33, 0.14)
	_wheel(Vector3(0, 0.33, -0.75), 0.33, 0.14)
	_finish(Vector3(0.6, 1.0, 2.0), Vector3(0, 0.5, 0))

func _build_heli() -> void:
	var s := def.size
	var dark := Color(0.1, 0.1, 0.12)
	var hull := _box(Vector3(s.x * 0.9, 0.35, s.z * 0.7), Vector3(0, 0.6, 0.2), def.body_color)
	_body_mats.append(hull.material_override)
	var roof := _box(Vector3(s.x * 0.9, 0.12, s.z * 0.55), Vector3(0, 1.95, -0.05), def.body_color.darkened(0.15))
	_body_mats.append(roof.material_override)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.07, 1.2, 0.07), Vector3(sx * s.x * 0.43, 1.35, -0.05 + sz * s.z * 0.25), dark)
	_box(Vector3(s.x * 0.86, 1.1, 0.04), Vector3(0, 1.4, 0.2 + s.z * 0.3), Color(0.55, 0.75, 0.9, 0.35), true)
	_seat_boxes()
	var boom := _box(Vector3(0.28, 0.28, 2.8), Vector3(0, 1.0, -s.z * 0.35 - 1.4), def.body_color)
	_body_mats.append(boom.material_override)
	_box(Vector3(0.08, 0.9, 0.5), Vector3(0, 1.4, -s.z * 0.35 - 2.6), def.body_color.darkened(0.2))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.08, 0.08, s.z * 0.9), Vector3(sx * s.x * 0.4, 0.06, 0.1), dark)
		_box(Vector3(0.06, 0.4, 0.06), Vector3(sx * s.x * 0.4, 0.3, 0.9), dark)
		_box(Vector3(0.06, 0.4, 0.06), Vector3(sx * s.x * 0.4, 0.3, -0.6), dark)
	_box(Vector3(0.12, 0.4, 0.12), Vector3(0, 2.2, -0.05), dark)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 2.45, -0.05)
	add_child(_rotor)
	for ry in [0.0, 90.0]:
		var bl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(7.0, 0.04, 0.25)
		bl.mesh = bm
		bl.rotation_degrees.y = ry
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.12, 0.12, 0.14)
		bl.material_override = mt
		_rotor.add_child(bl)
	_finish(Vector3(s.x * 0.9, 2.0, s.z * 0.8), Vector3(0, 1.0, 0.1))

func _build_plane() -> void:
	var s := def.size
	var L := s.z
	var dark := Color(0.12, 0.12, 0.15)
	var accent := Color(0.75, 0.12, 0.12)
	var fus := _box(Vector3(1.1, 0.5, L), Vector3(0, 0.65, 0), def.body_color)
	_body_mats.append(fus.material_override)
	var nose := _box(Vector3(1.0, 0.7, 0.9), Vector3(0, 0.75, L * 0.5 - 0.2), def.body_color.darkened(0.08))
	_body_mats.append(nose.material_override)
	var tail := _box(Vector3(0.7, 0.4, L * 0.35), Vector3(0, 0.85, -L * 0.4), def.body_color)
	_body_mats.append(tail.material_override)
	var wing := _box(Vector3(s.x, 0.1, 1.5), Vector3(0, 0.55, 0.2), accent)
	_body_mats.append(wing.material_override)
	_box(Vector3(0.1, 1.0, 0.9), Vector3(0, 1.4, -L * 0.5 + 0.5), def.body_color)
	_box(Vector3(3.0, 0.08, 0.7), Vector3(0, 0.95, -L * 0.5 + 0.5), accent)
	_box(Vector3(0.9, 0.5, 0.04), Vector3(0, 1.25, def.seat_z + 0.85), Color(0.55, 0.75, 0.9, 0.35), true)
	_seat_boxes()
	_wheel(Vector3(-0.7, 0.25, 0.9), 0.25, 0.1)
	_wheel(Vector3(0.7, 0.25, 0.9), 0.25, 0.1)
	_wheel(Vector3(0, 0.18, -L * 0.5 + 0.4), 0.18, 0.08)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 0.75, L * 0.5 + 0.3)
	add_child(_rotor)
	for rz in [0.0, 90.0]:
		var bl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 2.0, 0.04)
		bl.mesh = bm
		bl.rotation_degrees.z = rz
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.1, 0.1, 0.12)
		bl.material_override = mt
		_rotor.add_child(bl)
	_finish(Vector3(1.3, 1.6, L), Vector3(0, 0.8, 0))

func _build() -> void:
	match def.kind:
		"moto":
			_build_moto()
			return
		"heli":
			_build_heli()
			return
		"plane":
			_build_plane()
			return
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
	if def.kind == "truck":
		var cargo := _box(Vector3(s.x * 0.95, 1.9, s.z * 0.30), Vector3(0, tub_top + 0.95, -s.z * 0.36), Color(0.85, 0.85, 0.88))
		_body_mats.append(cargo.material_override)

func interact(p: Node) -> void:
	if destroyed or driver != null:
		return
	if ai_driven:
		carjack(p)
		return
	if not persistent and get_parent() != WorldManager.entities and p is Player:
		CrimeManager.report_crime("vehicle_theft", global_position, p)
	# détache le véhicule du secteur de ville (il ne doit pas être déchargé avec lui)
	if WorldManager.entities != null and get_parent() != WorldManager.entities:
		reparent(WorldManager.entities, true)
	persistent = true
	p.enter_vehicle(self)

## Vol de voiture : le conducteur PNJ est éjecté (un civil qui s'enfuit), crime « carjack » si vu.
func carjack(p: Node) -> void:
	if not ai_driven or destroyed:
		return
	ai_driven = false
	remove_from_group("traffic")
	if ai_driver != null and is_instance_valid(ai_driver):
		ai_driver.queue_free()
	ai_driver = null
	_throttle = 0.0
	_steer = 0.0
	speed = 0.0
	var side := global_transform.basis.x * (def.size.x * 0.5 + 0.9)
	if MissionManager.spawner != null and MissionManager.spawner.has_method("spawn_fleeing_civilian") and not police_skin:
		MissionManager.spawner.call("spawn_fleeing_civilian", global_position + side, global_position)
	if p is Player:
		CrimeManager.report_crime("carjack", global_position, p)
	NPCManager.emit_noise(global_position, 30.0, p)
	if WorldManager.entities != null and get_parent() != WorldManager.entities:
		reparent(WorldManager.entities, true)
	persistent = true
	(p as Player).enter_vehicle(self)

func set_driver(p: Player) -> void:
	driver = p
	if p == null:
		_throttle = 0.0
		_steer = 0.0
		_brake = false
		_lift = 0.0
	remove_from_group("interactable") if p != null else add_to_group("interactable")

func set_controls(throttle: float, steer: float, brake: bool, lift := 0.0) -> void:
	_lift = lift
	_throttle = throttle
	_steer = steer
	_brake = brake

func _fly(delta: float) -> void:
	var active := driver != null and not destroyed
	var heli := def.kind == "heli"
	var grounded := is_on_floor()
	var t := _throttle if active else 0.0
	var target := t * def.max_speed if t >= 0.0 else t * def.max_reverse
	if not heli and active and not grounded:
		# avion en l'air : vitesse de croisière mini, manche avant = vite, manche arrière = ralenti (décrochage)
		target = lerpf(def.lift_speed * 0.75, def.max_speed, clampf((t + 1.0) * 0.5, 0.0, 1.0))
	var rate := def.accel if absf(target) > absf(speed) else 5.0
	speed = move_toward(speed, target, rate * delta)
	if (_brake and active) or destroyed:
		speed = move_toward(speed, 0.0, def.brake_force * delta)
	var vy := velocity.y
	if not active:
		vy = vy - 22.0 * delta if not grounded else 0.0
	else:
		var can_lift := heli or absf(speed) >= def.lift_speed
		if _lift > 0.0 and can_lift and global_position.y < 70.0:
			vy = move_toward(vy, def.climb_rate, 14.0 * delta)
		elif _lift < 0.0 and not grounded:
			vy = move_toward(vy, -def.climb_rate, 14.0 * delta)
		elif heli:
			vy = move_toward(vy, 0.0, 10.0 * delta)
		elif grounded:
			vy = 0.0
		elif absf(speed) < def.lift_speed * 0.85:
			vy = move_toward(vy, -9.0, 10.0 * delta)
		else:
			vy = move_toward(vy, 0.0, 6.0 * delta)
		var turn := 1.0 if heli else clampf(absf(speed) / 8.0, 0.0, 1.0)
		rotation.y -= _steer * def.steer_rate * delta * turn
	var fwd := global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var before := speed
	velocity = Vector3(fwd.x * speed, vy, fwd.z * speed)
	move_and_slide()
	speed = Vector3(velocity.x, 0.0, velocity.z).dot(fwd)
	var lost := absf(before) - absf(speed)
	if lost > 4.0 and get_slide_collision_count() > 0:
		_crash((lost - 4.0) * 7.0)
	if _rotor != null and active:
		if heli:
			_rotor.rotate_y(delta * 35.0)
		else:
			_rotor.rotate_z(delta * 45.0)
	_update_engine()

func _update_engine() -> void:
	if _engine != null:
		var running := driver != null or (ai_driven and not destroyed)
		if not _engine.playing and running:
			_engine.play()
		elif _engine.playing and not running:
			_engine.stop()
		_engine.pitch_scale = 0.8 + absf(speed) / def.max_speed

func _physics_process(delta: float) -> void:
	_hit_cd_tick(delta)
	_tick_icon(delta)
	_tick_siren(delta)
	if is_aircraft():
		_fly(delta)
		return
	var piloted := (driver != null or ai_driven) and not destroyed
	var t := _throttle if piloted else 0.0
	var target := t * def.max_speed if t >= 0.0 else t * def.max_reverse
	var accel := def.accel if absf(target) > absf(speed) else 6.0
	speed = move_toward(speed, target, accel * delta)
	if (_brake and piloted) or destroyed:
		speed = move_toward(speed, 0.0, def.brake_force * delta)
	if absf(speed) > 0.3 and piloted:
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
	_update_engine()

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
	set_siren(false)
	ai_driven = false
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
