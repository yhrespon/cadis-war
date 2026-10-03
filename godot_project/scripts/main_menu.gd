extends Node3D
## Écran principal de C.A.D.I.S WARS. Histoire, Mission secrète, Personnage, Magasins, Paramètres, Crédits : écrans réels ; Online : verrouillé (« Bientôt disponible »).
## Décor : un des personnages fournis (idle), à l'échelle réelle (1,75 m), qui change toutes les 6 s.

const GAME_TITLE := "C.A.D.I.S WARS"
const ENTRIES := ["Histoire", "Mission secrète", "Online", "Personnage", "Magasins", "Paramètres", "Crédits"]

var manifest: Dictionary
var _char: GameCharacter
var _idx := 0
var _popup: PanelContainer
var _popup_label: Label
var _popup_box: VBoxContainer
var _story_buttons: Array = []
var _timer: Timer

func _ready() -> void:
	SaveManager.load_latest_profile()      # menus/magasins affichent l'état réel de la dernière sauvegarde
	UIManager.push_back(_on_back)
	manifest = GameCharacter.load_manifest()
	_build_scene()
	_build_ui()
	_show_character(randi() % manifest["characters"].size())
	_timer = Timer.new()
	_timer.wait_time = 6.0
	_timer.autostart = true
	_timer.timeout.connect(func() -> void: _show_character((_idx + 1) % manifest["characters"].size()))
	add_child(_timer)

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
		# Le personnage est orienté vers +Z ; la caméra de prévisualisation est placée côté +Z.
		_char.rotation_degrees.y = 0.0
		_char.play("idle", 0.0)

func _menu_button(text: String) -> Button:
	# Style « tactique » : coins diagonaux (haut-droit et bas-gauche arrondis, les deux autres vifs) + liseré doré au survol. Pas de vrais parallélogrammes.
	var b := UIKit.button(text, Color(0.1, 0.11, 0.16, 0.92), 54.0)
	b.custom_minimum_size = Vector2(380, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 25)
	for sname in ["normal", "hover", "pressed", "focus"]:
		var sb := b.get_theme_stylebox(sname) as StyleBoxFlat
		if sb == null:
			continue
		sb = sb.duplicate() as StyleBoxFlat
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_right = 0
		sb.corner_radius_top_right = 20
		sb.corner_radius_bottom_left = 20
		sb.content_margin_left = 26
		if sname == "normal":
			sb.border_width_left = 6
			sb.border_color = Color(1.0, 0.82, 0.25, 0.9)
		b.add_theme_stylebox_override(sname, sb)
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	# voile dégradé à gauche pour la lisibilité des boutons sur le décor 3D
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.06, 0.92))
	grad.set_color(1, Color(0.02, 0.03, 0.06, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var veil := TextureRect.new()
	veil.texture = gt
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 620
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	box.offset_left = 60
	box.offset_right = 470
	box.offset_top = 24
	box.offset_bottom = -24
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 9)
	root.add_child(box)
	var title := Label.new()
	title.text = "C.A.D.I.S"
	title.add_theme_font_size_override("font_size", 66)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var title2 := Label.new()
	title2.text = "WARS"
	title2.add_theme_font_size_override("font_size", 40)
	title2.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	title2.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title2.add_theme_constant_override("outline_size", 8)
	box.add_child(title2)
	var line := ColorRect.new()
	line.color = Color(1.0, 0.82, 0.25, 0.9)
	line.custom_minimum_size = Vector2(300, 3)
	box.add_child(line)
	var sub := Label.new()
	sub.text = "Version de développement  ·  %d $" % GameManager.money
	sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(sub)
	for n in ENTRIES:
		var b := _menu_button(n)
		b.pressed.connect(_on_entry.bind(n))
		box.add_child(b)
	var credit := Label.new()
	credit.text = "Modèle de personnage : « Fuse personnage » (1831251), CC-BY-4.0 — voir Crédits"
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credit.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	credit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credit.offset_right = -16
	credit.offset_bottom = -10
	root.add_child(credit)
	if OS.is_debug_build():      # niveau de test technique : visible seulement dans une build de debug
		var dev := Button.new()
		dev.text = "Niveau de test (dev)"
		dev.flat = true
		dev.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		dev.grow_vertical = Control.GROW_DIRECTION_BEGIN
		dev.offset_left = 16
		dev.offset_bottom = -6
		dev.pressed.connect(_start_test)
		root.add_child(dev)
	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_CENTER)
	_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_popup.visible = false
	_popup.add_theme_stylebox_override("panel", UIKit.style(UIKit.BG, UIKit.GOLD, 2, 14))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 14)
	pv.custom_minimum_size = Vector2(420, 0)
	_popup.add_child(pv)
	_popup_box = pv
	_popup_label = Label.new()
	_popup_label.add_theme_font_size_override("font_size", 28)
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_popup_label)
	var ok := UIKit.button("OK", Color(0.18, 0.2, 0.26), 52.0)
	ok.pressed.connect(_close_popup)
	pv.add_child(ok)
	root.add_child(_popup)

func _on_entry(n: String) -> void:
	_clear_story_buttons()
	if n == "Magasins":
		ShopUI.open(self)
		return
	if n == "Paramètres":
		SettingsUI.open(self)
		return
	if n == "Personnage":
		CharacterUI.open(self, func() -> void:
			_timer.stop()
			_show_character(maxi(0, GameManager.character_ids().find(GameManager.character_id))))
		return
	if n == "Crédits":
		CreditsUI.open(self)
		return
	_popup_label.add_theme_font_size_override("font_size", 28)
	if n == "Histoire":
		_popup_label.text = "Histoire"
		var has_save := SaveManager.any_save()
		if has_save:
			_add_story_button("Continuer", _continue_story)
		_add_story_button("Nouvelle partie", _new_story)
	elif n == "Mission secrète":
		_popup_label.text = "Mission secrète\nInfiltration chronométrée (3 min)\nVolez le dossier, évitez les gardes, rejoignez la sortie.\nMeilleur score : %d" % GameManager.secret_best_score
		_popup_label.add_theme_font_size_override("font_size", 22)
		_add_story_button("Commencer", func() -> void: GameManager.start_secret_mission())
	elif n == "Online":
		_popup_label.text = "Multijoueur – Bientôt disponible\n\nAucune connexion n'est établie."
	else:
		_popup_label.text = "%s\n\nEncore en développement" % n
	_popup.visible = true

func _add_story_button(text: String, cb: Callable) -> void:
	var b := UIKit.button(text, Color(0.15, 0.4, 0.2), 56.0)
	b.pressed.connect(cb)
	_popup_box.add_child(b)
	_popup_box.move_child(b, _popup_box.get_child_count() - 2)      # avant le bouton OK
	_story_buttons.append(b)

func _clear_story_buttons() -> void:
	for b in _story_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_story_buttons = []

func _close_popup() -> void:
	_popup.visible = false

func _continue_story() -> void:
	var slot := SaveManager.latest_slot()
	var d := SaveManager.read(slot)
	if d.is_empty():
		UIManager.toast("Sauvegarde illisible", Color(1, 0.4, 0.4))
		return
	GameManager.start_story(d)

func _new_story() -> void:
	GameManager.start_story()

func _start_test() -> void:
	GameManager.mode = "test"
	GameManager.new_game()
	UIManager.change_scene("res://game.tscn")

func _on_back() -> void:
	if _popup.visible:
		_close_popup()
	else:
		get_tree().quit()
