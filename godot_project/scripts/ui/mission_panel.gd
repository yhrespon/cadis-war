class_name MissionPanel
extends CanvasLayer
## Panneau de missions (étape 5) : liste à gauche (Histoire / Contrats / Secondaires, missions verrouillées grisées avec leur prérequis),
## détail à droite (donneur, type, briefing, objectifs, récompense, limite de temps), actions Accepter / Abandonner / Fermer.
## Ouvert par MissionBoard.interact() via MissionPanel.open(self). Met le jeu en pause pendant l'affichage.
## Flux : INPUT (interact) -> UI (ce panneau) -> MissionManager.accept/abandon -> état (active_id) -> HUD (objectif) -> SAVE (autosave à la fin de mission).
## Données 100 % réelles (MissionManager.defs, completed, active_id). Résolution de base 1280x720. Bouton retour Android = fermeture.
## v13 : script chargé sous Godot 4.3 ; comportement du panneau non testé.

const GOLD := Color(1.0, 0.85, 0.3)
const CAT_ORDER := {"main": 0, "contract": 1, "side": 2}
const CAT_LABEL := {"main": "HISTOIRE", "contract": "CONTRATS", "side": "SECONDAIRES"}
const CAT_COLOR := {"main": Color(1.0, 0.85, 0.3), "contract": Color(0.45, 0.8, 1.0), "side": Color(0.7, 0.9, 0.55)}

static var _instance: MissionPanel = null

var _list_box: VBoxContainer
var _detail_box: VBoxContainer
var _head_info: Label
var _selected := ""
var _abandon_armed := false
var _was_paused := false
var _back_cb: Callable
var _closed := false

## Ouvre le panneau (une seule instance à la fois).
static func open(host: Node) -> void:
	if _instance != null and is_instance_valid(_instance):
		return
	var scene := host.get_tree().current_scene
	if scene == null:
		return
	var p := MissionPanel.new()
	scene.add_child(p)

func _ready() -> void:
	_instance = self
	layer = 20                                   # au-dessus du HUD (5) et des boutons tactiles (10), sous UIManager (100)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = GameManager.paused
	GameManager.set_paused(true)
	var scene := get_tree().current_scene
	if scene != null and scene.get("touch") != null:
		var tc: Variant = scene.get("touch")
		if tc is TouchControls:
			(tc as TouchControls).set_context((tc as TouchControls).context)   # relâche stick et boutons appuyés
	_build()
	_back_cb = close
	UIManager.push_back(_back_cb)
	_selected = MissionManager.active_id if MissionManager.active_id != "" else _first_available()
	_refresh()

func _exit_tree() -> void:
	if _instance == self:
		_instance = null

func close() -> void:
	if _closed:
		return
	_closed = true
	UIManager.pop_back(_back_cb)
	GameManager.set_paused(_was_paused)
	queue_free()

# ------------------------------------------------------------------ construction de l'interface
func _style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _label(text: String, size := 22, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(text: String, color := Color(0.18, 0.2, 0.26)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(color, Color(1, 1, 1, 0.15), 1))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.15), GOLD, 2))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.2), GOLD, 2))
	b.add_theme_stylebox_override("focus", _style(color.lightened(0.1), GOLD, 3))
	b.add_theme_stylebox_override("disabled", _style(Color(0.12, 0.13, 0.16), Color(1, 1, 1, 0.06), 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	return b

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 50
	panel.offset_right = -50
	panel.offset_top = 32
	panel.offset_bottom = -32
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.08, 0.11, 0.98), GOLD, 2, 14))
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	var title := _label("MISSIONS", 38, GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(title)
	_head_info = _label("", 22, Color(0.8, 0.82, 0.88))
	_head_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_head_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_head_info)
	var x := _button("Fermer", Color(0.3, 0.14, 0.14))
	x.custom_minimum_size = Vector2(150, 56)
	x.pressed.connect(close)
	head.add_child(x)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := ScrollContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(left)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	left.add_child(_list_box)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _style(Color(0.11, 0.12, 0.16), Color(1, 1, 1, 0.08), 1))
	body.add_child(right)
	var rs := ScrollContainer.new()
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rs)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 10)
	rs.add_child(_detail_box)

# ------------------------------------------------------------------ données
## Missions de la ville courante, triées par catégorie puis id.
func _city_missions() -> Array:
	var out: Array = []
	for id in MissionManager.defs:
		var d: MissionDef = MissionManager.defs[id]
		if d.city == GameManager.current_city:
			out.append(d)
	out.sort_custom(func(a: MissionDef, b: MissionDef) -> bool:
		var oa: int = int(CAT_ORDER.get(a.category, 3))
		var ob: int = int(CAT_ORDER.get(b.category, 3))
		return oa < ob if oa != ob else a.id < b.id)
	return out

func _first_available() -> String:
	for d in _city_missions():
		if MissionManager.is_available(d.id):
			return d.id
	return ""

func _missing_requirements(d: MissionDef) -> Array:
	var out: Array = []
	for r in d.requires:
		if not MissionManager.is_completed(str(r)):
			var rd: MissionDef = MissionManager.def_of(str(r))
			out.append(rd.title if rd != null else str(r))
	return out

func _fmt_time(sec: float) -> String:
	var s := int(ceil(sec))
	return "%d:%02d" % [s / 60, s % 60]

# ------------------------------------------------------------------ affichage
func _refresh() -> void:
	_abandon_armed = false
	for c in _list_box.get_children():
		c.queue_free()
	var missions := _city_missions()
	var done := 0
	var last_cat := ""
	var focus_btn: Button = null
	for d in missions:
		if MissionManager.is_completed(d.id) and d.category != "contract":      # les contrats restent listés (répétables)
			done += 1
			continue
		if d.category != last_cat:
			last_cat = d.category
			var h := _label(str(CAT_LABEL.get(d.category, d.category.to_upper())), 20, CAT_COLOR.get(d.category, Color.WHITE))
			h.autowrap_mode = TextServer.AUTOWRAP_OFF
			_list_box.add_child(h)
		var b := _mission_button(d)
		_list_box.add_child(b)
		if d.id == _selected:
			focus_btn = b
	if _list_box.get_child_count() == 0:
		_list_box.add_child(_label("Toutes les missions de cette ville sont terminées.", 22, Color(0.8, 0.8, 0.85)))
	_head_info.text = "Terminées : %d / %d      %d $" % [done, missions.size(), GameManager.money]
	_show_detail(_selected)
	if focus_btn != null:
		focus_btn.grab_focus.call_deferred()

func _mission_button(d: MissionDef) -> Button:
	var active := d.id == MissionManager.active_id
	var locked := not active and not MissionManager.is_available(d.id)
	var tag := "EN COURS" if active else ("VERROUILLÉE" if locked else "%s  ·  %d $" % [d.mission_type, int(round(float(d.reward_money) * GameManager.reward_mult()))])
	var col := Color(0.16, 0.18, 0.23)
	if active:
		col = Color(0.3, 0.24, 0.08)
	elif d.id == _selected:
		col = Color(0.2, 0.24, 0.32)
	var b := _button("%s\n%s" % [d.title, tag], col)
	b.custom_minimum_size = Vector2(0, 78)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 21)
	if locked:
		b.add_theme_color_override("font_color", Color(0.55, 0.56, 0.6))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		_selected = d.id
		_refresh())
	return b

func _show_detail(id: String) -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var d: MissionDef = MissionManager.def_of(id) if id != "" else null
	if d == null:
		_detail_box.add_child(_label("Sélectionnez une mission.", 24, Color(0.7, 0.72, 0.78)))
		return
	var cat_col: Color = CAT_COLOR.get(d.category, Color.WHITE)
	_detail_box.add_child(_label(str(CAT_LABEL.get(d.category, d.category.to_upper())), 20, cat_col))
	_detail_box.add_child(_label(d.title, 34, Color.WHITE))
	_detail_box.add_child(_label("Donneur : %s      Type : %s" % [d.giver, d.mission_type], 20, Color(0.75, 0.78, 0.85)))
	_detail_box.add_child(_label(d.briefing, 22, Color(0.92, 0.92, 0.95)))

	if not d.objectives.is_empty():
		_detail_box.add_child(_label("Objectifs", 22, GOLD))
		for spec in d.objectives:
			var txt := ""
			if spec is Dictionary:
				txt = str((spec as Dictionary).get("text", (spec as Dictionary).get("type", "")))
			_detail_box.add_child(_label("•  " + txt, 21, Color(0.88, 0.9, 0.95)))

	var reward := int(round(float(d.reward_money) * GameManager.reward_mult()))
	var rtxt := "Récompense : %d $" % reward
	if d.reward_item != "":
		var it: ItemDef = InventoryManager.item_def(d.reward_item)
		rtxt += "  +  %s" % (it.display_name if it != null else d.reward_item)
	if d.unlocks_city != "":
		rtxt += "  +  nouvelle ville"
	_detail_box.add_child(_label(rtxt, 22, Color(0.5, 1.0, 0.6)))
	if d.time_limit > 0.0:
		_detail_box.add_child(_label("Limite de temps : %s" % _fmt_time(d.time_limit), 21, Color(1.0, 0.7, 0.4)))
	if d.fail_on_death:
		_detail_box.add_child(_label("La mission échoue si vous mourez.", 20, Color(1.0, 0.55, 0.55)))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_detail_box.add_child(spacer)

	var active := d.id == MissionManager.active_id
	if active:
		_detail_box.add_child(_label("Mission en cours.", 22, GOLD))
		var ab := _button("Abandonner la mission", Color(0.35, 0.14, 0.14))
		ab.pressed.connect(func() -> void:
			if not _abandon_armed:
				_abandon_armed = true
				ab.text = "Confirmer l'abandon ?"
				return
			MissionManager.abandon()
			close())
		_detail_box.add_child(ab)
	elif MissionManager.is_completed(d.id) and d.category != "contract":
		_detail_box.add_child(_label("Mission terminée.", 22, Color(0.5, 1.0, 0.6)))
	elif MissionManager.active_id != "":
		var cur: MissionDef = MissionManager.def_of(MissionManager.active_id)
		_detail_box.add_child(_label("Terminez ou abandonnez d'abord : %s" % (cur.title if cur != null else MissionManager.active_id), 21, Color(1.0, 0.7, 0.4)))
		var nb := _button("Accepter", Color(0.15, 0.3, 0.18))
		nb.disabled = true
		_detail_box.add_child(nb)
	elif not MissionManager.is_available(d.id):
		var miss := _missing_requirements(d)
		var why := "Terminez d'abord : %s" % ", ".join(miss) if not miss.is_empty() else "Non disponible dans cette ville pour l'instant."
		_detail_box.add_child(_label(why, 21, Color(1.0, 0.7, 0.4)))
		var lb := _button("Verrouillée", Color(0.15, 0.3, 0.18))
		lb.disabled = true
		_detail_box.add_child(lb)
	else:
		var go := _button("Accepter la mission", Color(0.15, 0.4, 0.2))
		go.pressed.connect(func() -> void:
			var ok := MissionManager.accept(d.id)
			close()
			if not ok:
				UIManager.toast("Impossible d'accepter cette mission", Color(1, 0.4, 0.4)))
		_detail_box.add_child(go)
