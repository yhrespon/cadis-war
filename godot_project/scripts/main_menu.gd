extends Node3D
## Écran principal de C.A.D.I.S WARS. Toutes les rubriques affichent « en développement ».
## Décor : un des personnages fournis (idle), à l'échelle réelle (1,75 m), qui change toutes les 6 s.

const GAME_TITLE := "C.A.D.I.S WARS"
const ENTRIES := ["Histoire", "Mission secrète", "Online", "Personnage", "Magasins", "Paramètres"]

var manifest: Dictionary
var _char: GameCharacter
var _idx := 0
var _popup: PanelContainer
var _popup_label: Label

func _ready() -> void:
	manifest = GameCharacter.load_manifest()
	_build_scene()
	_build_ui()
	_show_character(randi() % manifest["characters"].size())
	var t := Timer.new()
	t.wait_time = 6.0
	t.autostart = true
	t.timeout.connect(func() -> void: _show_character((_idx + 1) % manifest["characters"].size()))
	add_child(t)

func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.08, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.75)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.light_energy = 1.2
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(1.5, 1.8, -1.5)
	rim.light_color = Color(0.4, 0.6, 1.0)
	rim.omni_range = 6.0
	add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(-0.9, 1.15, 3.4)     # personnage décalé à droite de l'écran, boutons à gauche
	cam.rotation_degrees = Vector3(-3, -8, 0)
	cam.fov = 40.0
	add_child(cam)
	cam.current = true

func _show_character(i: int) -> void:
	_idx = i
	if _char != null:
		_char.queue_free()
	_char = GameCharacter.new()
	_char.apply_root_motion = false
	add_child(_char)
	if _char.setup(manifest["characters"][i]):
		_char.rotation_degrees.y = 160.0
		_char.play("idle", 0.0)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	box.offset_left = 60
	box.offset_right = 460
	box.offset_top = 40
	box.offset_bottom = -40
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	var title := Label.new()
	title.text = GAME_TITLE
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Version de développement"
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(sub)
	box.add_child(Control.new())
	for n in ENTRIES:
		var b := Button.new()
		b.text = n
		b.custom_minimum_size = Vector2(380, 62)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_entry.bind(n))
		box.add_child(b)
	var credit := Label.new()
	credit.text = "Modèle de personnage : voir source_model/license.txt (CC-BY-4.0)"
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_right = -16
	credit.offset_bottom = -10
	root.add_child(credit)
	var dev := Button.new()      # accès au niveau de test technique (à supprimer pour la version finale)
	dev.text = "Niveau de test (dev)"
	dev.flat = true
	dev.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dev.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dev.offset_left = 16
	dev.offset_bottom = -6
	dev.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://game.tscn"))
	root.add_child(dev)
	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup.visible = false
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	_popup.add_child(pv)
	_popup_label = Label.new()
	_popup_label.add_theme_font_size_override("font_size", 28)
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_popup_label)
	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(200, 52)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func() -> void: _popup.visible = false)
	pv.add_child(ok)
	root.add_child(_popup)

func _on_entry(n: String) -> void:
	_popup_label.text = "%s\n\nEncore en développement" % n
	_popup.visible = true
