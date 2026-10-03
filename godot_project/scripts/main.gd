extends Node3D
## Visionneuse de personnages (lobby de test) : choix du perso, boutons d'animation, caméra orbitale tactile/souris.

var manifest: Dictionary
var current: GameCharacter
var cam: Camera3D
var yaw := 20.0
var pitch := -8.0
var dist := 3.6
var cam_target := Vector3(0, 0.9, 0)
var anim_box: HFlowContainer
var picker: OptionButton

func _ready() -> void:
	manifest = GameCharacter.load_manifest()
	_build_world()
	_build_ui()
	_select(0)

func _build_world() -> void:
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
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor_mesh.mesh = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)   # damier 1 m (2x2 px)
	img.set_pixel(0, 0, Color(0.36, 0.37, 0.4)); img.set_pixel(1, 1, Color(0.36, 0.37, 0.4))
	img.set_pixel(1, 0, Color(0.27, 0.28, 0.3)); img.set_pixel(0, 1, Color(0.27, 0.28, 0.3))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(200, 200, 1)
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	_update_cam()

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	picker = OptionButton.new()
	for c in manifest["characters"]:
		picker.add_item(c["id"])
	picker.item_selected.connect(_select)
	root.add_child(picker)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	anim_box = HFlowContainer.new()
	root.add_child(anim_box)
	var rst := Button.new()
	rst.text = "↺ Recentrer"
	rst.pressed.connect(_reset_pos)
	root.add_child(rst)
	var credit := Label.new()
	credit.text = "Modèle de base « Fuse personnage » (Sketchfab, auteur 1831251), CC-BY-4.0"
	credit.add_theme_font_size_override("font_size", 12)
	root.add_child(credit)

func _select(i: int) -> void:
	if current:
		current.queue_free()
		current = null
	var entry: Dictionary = manifest["characters"][i]
	var gc := GameCharacter.new()
	add_child(gc)
	if not gc.setup(entry):
		gc.queue_free()
		return
	current = gc
	_reset_pos()
	for b in anim_box.get_children():
		b.queue_free()
	for a in gc.animation_names():
		var btn := Button.new()
		btn.text = a
		btn.pressed.connect(gc.play.bind(a))
		anim_box.add_child(btn)
	cam_target.y = entry["height_m"] * 0.52
	dist = 2.2 + entry["height_m"] * 1.1
	_update_cam()
	gc.play("idle", 0.0)

func _reset_pos() -> void:
	if current:
		current.global_position = Vector3.ZERO

func _process(_dt: float) -> void:
	if current:   # la caméra suit le personnage (le sol est un damier de 1 m)
		cam_target.x = current.global_position.x
		cam_target.z = current.global_position.z
		cam_target.y = current.manifest_entry["height_m"] * 0.52 + current.global_position.y
		_update_cam()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		yaw -= ev.relative.x * 0.4
		pitch = clampf(pitch - ev.relative.y * 0.3, -60.0, 30.0)
		_update_cam()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: dist = maxf(1.2, dist - 0.2)
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = minf(8.0, dist + 0.2)
		_update_cam()

func _update_cam() -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
	cam.global_position = cam_target + b * Vector3(0, 0, dist)
	cam.look_at(cam_target)
