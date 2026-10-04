extends Node3D
## Écran principal de C.A.D.I.S WARS. Histoire, Mission secrète, Personnage, Magasins, Paramètres, Crédits : écrans réels ; Online : verrouillé (« Bientôt disponible »).
## Décor : vidéo de fond en boucle « ville la nuit » (art/menu_bg.ogv, 10 s, titre C.A.D.I.S WARS incrusté dans l'image) ; affiche fixe art/menu_bg.png dessous.
## Les boutons sont centrés sous le titre. Plus de personnage ni de titre en texte sur l'écran principal.

const GAME_TITLE := "C.A.D.I.S WARS"
const ENTRIES := ["Histoire", "Mission secrète", "Online", "Personnage", "Magasins", "Paramètres", "Crédits"]

const BG_POSTER := "res://art/menu_bg.png"      # affiche fixe (image 1280x720 avec le titre)
const BG_VIDEO := "res://art/menu_bg.ogv"        # boucle vidéo Theora 1280x720
const VID_W := 1280.0
const VID_H := 720.0
const TITLE_BOTTOM := 245.0                      # bas du titre dans l'image (px sur 720) : les boutons commencent juste dessous
const MENU_W := 380.0

var _holder: Control
var _poster: TextureRect
var _video: VideoStreamPlayer
var _veil: TextureRect
var _menu_box: VBoxContainer
var _popup: PanelContainer
var _popup_label: Label
var _popup_box: VBoxContainer
var _story_buttons: Array = []

func _ready() -> void:
	SaveManager.load_latest_profile()      # menus/magasins affichent l'état réel de la dernière sauvegarde
	UIManager.push_back(_on_back)
	_build_ui()
	OnlineManager.status_changed.connect(_on_online_status)
	OnlineManager.room_changed.connect(_on_online_room)
	OnlineManager.match_started.connect(_on_online_match_started)
	AudioManager.play_music("menu")

func _exit_tree() -> void:
	if _video != null and is_instance_valid(_video):
		_video.stop()
		_video.stream = null

## Fond : affiche + vidéo en boucle, recadrés « cover » (échelle = max des deux rapports, aligné en haut pour que le titre reste en place).
func _build_background(root: Control) -> void:
	_holder = root
	_holder.clip_contents = true
	var back := ColorRect.new()                       # secours si ni affiche ni vidéo ne se chargent
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color(0.05, 0.06, 0.15)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)
	if ResourceLoader.exists(BG_POSTER):
		_poster = TextureRect.new()
		_poster.texture = load(BG_POSTER)
		_poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_poster.stretch_mode = TextureRect.STRETCH_SCALE
		_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_poster)
	else:
		push_warning("Affiche du menu introuvable : " + BG_POSTER)
	if ResourceLoader.exists(BG_VIDEO):
		var vs = load(BG_VIDEO)
		if vs != null:
			_video = VideoStreamPlayer.new()
			_video.stream = vs
			_video.expand = true
			_video.loop = true
			_video.autoplay = true
			_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_video.finished.connect(func() -> void: _video.play())      # filet de sécurité si `loop` ne relance pas
			root.add_child(_video)
	else:
		push_warning("Vidéo du menu introuvable : " + BG_VIDEO)
	# halo sombre en ellipse derrière les boutons (lisibilité sans bord net)
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.07, 0.66))
	g.add_point(0.5, Color(0.02, 0.03, 0.07, 0.5))
	g.set_color(g.get_point_count() - 1, Color(0.02, 0.03, 0.07, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	_veil = TextureRect.new()
	_veil.texture = gt
	_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_veil.stretch_mode = TextureRect.STRETCH_SCALE
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_veil)
	_add_rain(root)
	root.resized.connect(_layout)
	_layout.call_deferred()

## v17 : pluie par-dessus la ville (si la dernière partie finissait sous la pluie / l'orage, sinon 1 lancement sur 3).
## Aucun personnage sur l'écran principal : seulement la ville (immeubles, maisons, voitures, jour/nuit/pluie) comme dans le jeu.
func _add_rain(root: Control) -> void:
	var rainy := GameManager.world_weather == "rain" or GameManager.world_weather == "storm" or randf() < 0.33
	if not rainy:
		return
	var img := Image.create(2, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		var a := float(y) / 27.0
		for x in 2:
			img.set_pixel(x, y, Color(0.75, 0.85, 1.0, a * 0.55))
	var p2 := GPUParticles2D.new()
	p2.name = "MenuRain"
	p2.texture = ImageTexture.create_from_image(img)
	p2.amount = 380
	p2.lifetime = 0.75
	p2.preprocess = 0.75
	p2.position = Vector2(640, -30)
	p2.visibility_rect = Rect2(-900, -60, 1800, 900)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(900, 1, 1)
	pm.direction = Vector3(0.12, 1.0, 0.0)
	pm.spread = 3.0
	pm.initial_velocity_min = 1000.0
	pm.initial_velocity_max = 1250.0
	pm.gravity = Vector3.ZERO
	p2.process_material = pm
	root.add_child(p2)

## Place fond, halo et colonne de boutons selon la taille réelle de l'écran.
func _layout() -> void:
	if _holder == null:
		return
	var vs := _holder.size
	if vs.x < 1.0 or vs.y < 1.0:
		return
	var s := maxf(vs.x / VID_W, vs.y / VID_H)
	var sz := Vector2(VID_W, VID_H) * s
	var pos := Vector2((vs.x - sz.x) * 0.5, 0.0)
	for c in [_poster, _video]:
		if c != null:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = pos
			c.size = sz
	var top := TITLE_BOTTOM * s + 14.0
	if _menu_box != null:
		_menu_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_menu_box.size = Vector2(MENU_W, 10.0)       # la hauteur se réduit au minimum du contenu
		_menu_box.position = Vector2((vs.x - MENU_W) * 0.5, top)
	if _veil != null:
		_veil.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_veil.size = Vector2(MENU_W + 360.0, maxf(vs.y - top + 120.0, 100.0))
		_veil.position = Vector2((vs.x - _veil.size.x) * 0.5, top - 60.0)

func _menu_button(text: String) -> Button:
	# Style « tactique » : coins diagonaux (haut-droit et bas-gauche arrondis, les deux autres vifs) + liseré doré au survol. Pas de vrais parallélogrammes.
	var b := UIKit.button(text, Color(0.1, 0.11, 0.16, 0.86), 44.0)
	b.custom_minimum_size = Vector2(MENU_W, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 23)
	for sname in ["normal", "hover", "pressed", "focus"]:
		var sb := b.get_theme_stylebox(sname) as StyleBoxFlat
		if sb == null:
			continue
		sb = sb.duplicate() as StyleBoxFlat
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_right = 0
		sb.corner_radius_top_right = 20
		sb.corner_radius_bottom_left = 20
		sb.content_margin_left = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
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
	_build_background(root)
	_menu_box = VBoxContainer.new()
	_menu_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_menu_box.add_theme_constant_override("separation", 6)
	root.add_child(_menu_box)
	var sub := Label.new()
	sub.text = "Version 0.15  ·  %d $" % GameManager.money
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.72, 0.76, 0.88, 0.85))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("outline_size", 4)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_top = -34.0
	sub.offset_bottom = -8.0
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sub)
	for n in ENTRIES:
		var b := _menu_button(n)
		b.pressed.connect(_on_entry.bind(n))
		_menu_box.add_child(b)
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
		CharacterUI.open(self, func() -> void: pass)      # plus de personnage affiché sur l'écran principal
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
		_open_online_lobby()
	else:
		_popup_label.text = "%s\n\nEncore en développement" % n
	_popup.visible = true

func _open_online_lobby() -> void:
	_popup_label.text = "ONLINE — SALONS ET DUELS\n\nServeur : cadis-war.up.railway.app\n2 à 6 joueurs · campagne coop · duels · clans"
	_popup_label.add_theme_font_size_override("font_size", 22)
	_add_story_button("Créer un salon campagne — 2 joueurs", func() -> void: OnlineManager.create_room("campaign", 2))
	_add_story_button("Créer un salon campagne — 6 joueurs", func() -> void: OnlineManager.create_room("campaign", 6))
	_add_story_button("Créer un duel par équipes", func() -> void: OnlineManager.create_room("team_duel", 2))
	_add_story_button("Créer un duel solo", func() -> void: OnlineManager.create_room("solo_duel", 2))
	var code_input := LineEdit.new()
	code_input.placeholder_text = "Code du salon (ex. A1B2C3)"
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.custom_minimum_size = Vector2(0, 46)
	_popup_box.add_child(code_input)
	_popup_box.move_child(code_input, _popup_box.get_child_count() - 2)
	_add_story_button("Rejoindre le salon", func() -> void: OnlineManager.join_room(code_input.text))
	_add_story_button("Recherche duel + IA de secours", func() -> void: OnlineManager.search_player("solo_duel"))
	_add_story_button("Créer mon clan CADIS", func() -> void: OnlineManager.create_clan("Clan CADIS", "CADIS"))

func _on_online_status(text: String) -> void:
	if _popup_label != null and _popup.visible:
		_popup_label.text = "ONLINE\n\n" + text

func _on_online_room(r: Dictionary) -> void:
	if _popup_label != null and _popup.visible:
		_popup_label.text = "SALON %s\n\nJoueurs : %d/%d\nPartage ce code à tes équipiers, puis valide le lancement." % [r.get("code", ""), r.get("players", []).size(), r.get("maxPlayers", 2)]
		_add_story_button("Valider / démarrer", func() -> void: OnlineManager.start_room())

func _on_online_match_started(match: Dictionary) -> void:
	var has_bot := bool(match.get("botFallback", false))
	_popup_label.text = "MATCH LANCÉ\n\n%s\n%s" % ["Adversaire IA local" if has_bot else "Joueurs connectés", "La scène de combat online sera chargée dans la prochaine étape."]
	SettingsManager.vibrate(90)

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
