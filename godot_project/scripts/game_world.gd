extends Node3D
## Niveau de test jouable : sol, bâtiment + échelle, rampe, obstacle, voiture, armes, mannequins, HUD, commandes tactiles.
## Tout est construit par code (primitives avec collisions). NON exécuté dans Godot.

var player: Player
var hud_status: Label
var hud_prompt: Label

func _ready() -> void:
	GameInput.setup()
	_build_environment()
	_build_level()
	player = Player.new()
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	var touch := TouchControls.new()
	add_child(touch)
	player.touch = touch
	_build_hud()
	player.health_changed.connect(func(hp: float) -> void: _refresh_status())
	player.weapon_changed.connect(func(t: String) -> void: _refresh_status())
	player.prompt_changed.connect(func(t: String) -> void: hud_prompt.text = t)
	_refresh_status()

func _refresh_status() -> void:
	var w := player.weapon.hud_text() if player.weapon != null else "Mains nues"
	hud_status.text = "PV %d   |   %s" % [int(player.health), w]

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.62, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)

func _static_box(size: Vector3, pos: Vector3, c: Color, rot_deg := Vector3.ZERO, mat: Material = null) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation_degrees = rot_deg
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	if mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		mat = m
	mi.material_override = mat
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	return sb

func _build_level() -> void:
	# sol damier 1 m (le haut du sol est à y = 0)
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.36, 0.37, 0.4)); img.set_pixel(1, 1, Color(0.36, 0.37, 0.4))
	img.set_pixel(1, 0, Color(0.27, 0.28, 0.3)); img.set_pixel(0, 1, Color(0.27, 0.28, 0.3))
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gm.uv1_scale = Vector3(200, 200, 1)
	_static_box(Vector3(200, 1, 200), Vector3(0, -0.5, 0), Color.WHITE, Vector3.ZERO, gm)
	# bâtiment (toit à 3 m) avec échelle sur sa face +Z
	_static_box(Vector3(8, 3, 6), Vector3(-14, 1.5, -10), Color(0.6, 0.55, 0.5))
	var ladder := Ladder.new()
	ladder.height = 3.0
	ladder.position = Vector3(-14, 0, -6.95)
	add_child(ladder)
	# rampe (~15°) vers une plate-forme, et obstacle bas à sauter
	_static_box(Vector3(3, 0.2, 8), Vector3(12, 1.03, -4), Color(0.5, 0.5, 0.6), Vector3(15, 0, 0))
	_static_box(Vector3(6, 0.2, 4), Vector3(12, 2.05, -9.6), Color(0.5, 0.5, 0.6))
	_static_box(Vector3(2, 0.6, 0.4), Vector3(0, 0.3, 5), Color(0.7, 0.6, 0.2))
	# voiture
	var car := Vehicle.new()
	car.position = Vector3(6, 0.1, 6)
	add_child(car)
	# armes
	var p1 := Pickup.new()
	p1.kind = "pistol"
	p1.position = Vector3(2, 0, -3)
	add_child(p1)
	var p2 := Pickup.new()
	p2.kind = "bat"
	p2.position = Vector3(-2, 0, -3)
	add_child(p2)
	# mannequins
	for x in [-3.0, 0.0, 3.0]:
		var d := TargetDummy.new()
		d.position = Vector3(x, 0, -12)
		add_child(d)

func _build_hud() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	hud_status = Label.new()
	hud_status.position = Vector2(16, 12)
	hud_status.add_theme_font_size_override("font_size", 22)
	ui.add_child(hud_status)
	hud_prompt = Label.new()
	hud_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.position = Vector2(-120, -160)
	hud_prompt.add_theme_font_size_override("font_size", 24)
	ui.add_child(hud_prompt)
	var help := Label.new()
	help.text = "ZQSD/WASD bouger · Espace saut · Maj sprint · C accroupi · V roulade · J poing · K pied · F tir · R recharge · E interagir"
	help.position = Vector2(16, 44)
	help.add_theme_font_size_override("font_size", 13)
	help.visible = not DisplayServer.is_touchscreen_available()
	ui.add_child(help)
