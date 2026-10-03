class_name SettingsUI
extends BasePanel
## Réglages : onglets Audio / Contrôles / Graphismes / Jeu, construits depuis la table SPEC et lus/écrits via SettingsManager
## (persistance user://settings.cfg, application réelle). Curseurs : l'écriture se fait au relâchement (drag_ended), pas à chaque pixel.
## Changer le préréglage de qualité réécrit plusieurs valeurs : la page est reconstruite. [NON TESTÉ DANS GODOT]

const SECTIONS := [["audio", "Audio"], ["controls", "Contrôles"], ["graphics", "Graphismes"], ["gameplay", "Jeu"]]

# [clé, libellé, type, paramètres]  — types : slider (min, max, pas), check, choice (liste de libellés)
const SPEC := {
	"audio": [
		["master", "Volume général", "slider", [0.0, 1.0, 0.05]],
		["music", "Musique", "slider", [0.0, 1.0, 0.05]],
		["sfx", "Effets sonores", "slider", [0.0, 1.0, 0.05]],
		["voice", "Voix", "slider", [0.0, 1.0, 0.05]],
	],
	"controls": [
		["sensitivity", "Sensibilité caméra", "slider", [0.3, 2.5, 0.05]],
		["aim_assist", "Aide à la visée", "slider", [0.0, 1.0, 0.05]],
		["touch_scale", "Taille des boutons tactiles", "slider", [0.7, 1.5, 0.05]],
		["touch_opacity", "Opacité des boutons tactiles", "slider", [0.2, 1.0, 0.05]],
		["vibration", "Vibration", "check", []],
		["invert_y", "Inverser l'axe vertical", "check", []],
	],
	"graphics": [
		["quality", "Qualité", "choice", ["Auto", "Low", "Medium", "High", "Ultra"]],
		["fps", "Images par seconde", "fps", []],
		["res_scale", "Résolution 3D", "slider", [0.5, 1.0, 0.05]],
		["view_distance", "Distance de vue (m)", "slider", [60.0, 260.0, 10.0]],
		["shadows", "Ombres", "check", []],
		["effects", "Effets", "check", []],
		["dynamic_quality", "Qualité dynamique (baisse la résolution si lent)", "check", []],
	],
	"gameplay": [
		["difficulty", "Difficulté", "choice", ["Facile", "Normal", "Difficile"]],
		["show_damage", "Afficher les chiffres de dégâts", "check", []],
	],
}

var _section := "audio"
var _tabs_row: HBoxContainer
var _list: VBoxContainer

static func open(host: Node) -> void:
	BasePanel.show_panel(host, SettingsUI.new())

func _title() -> String:
	return "PARAMÈTRES"

func _build_content() -> void:
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 8)
	body.add_child(_tabs_row)
	var holder := VBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(holder)
	_list = UIKit.scroll_column(holder, 10)
	_rebuild()

func _rebuild() -> void:
	for c in _tabs_row.get_children():
		c.queue_free()
	for s in SECTIONS:
		var sid: String = s[0]
		var b := UIKit.button(str(s[1]), Color(0.3, 0.24, 0.08) if sid == _section else Color(0.16, 0.18, 0.23), 52.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_section = sid
			_rebuild())
		_tabs_row.add_child(b)
	for c in _list.get_children():
		c.queue_free()
	for spec in SPEC[_section]:
		_list.add_child(_row(spec))

func _row(spec: Array) -> Control:
	var key: String = spec[0]
	var kind: String = spec[2]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.style(UIKit.CARD, Color(1, 1, 1, 0.08), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	var name_l := UIKit.label(str(spec[1]), 22, Color.WHITE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.custom_minimum_size = Vector2(330, 0)
	h.add_child(name_l)
	var cur: Variant = SettingsManager.get_value(_section, key)
	match kind:
		"slider":
			var p: Array = spec[3]
			var sl := HSlider.new()
			sl.min_value = float(p[0])
			sl.max_value = float(p[1])
			sl.step = float(p[2])
			sl.value = clampf(float(cur), float(p[0]), float(p[1]))
			sl.custom_minimum_size = Vector2(380, 48)
			sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(sl)
			var val := UIKit.label(_fmt(sl.value, float(p[1])), 22, UIKit.GOLD, false)
			val.custom_minimum_size = Vector2(80, 0)
			h.add_child(val)
			sl.value_changed.connect(func(v: float) -> void: val.text = _fmt(v, float(p[1])))
			sl.drag_ended.connect(func(_changed: bool) -> void: SettingsManager.set_value(_section, key, sl.value))
		"check":
			var cb := CheckButton.new()
			cb.button_pressed = bool(cur)
			cb.custom_minimum_size = Vector2(110, 48)
			cb.toggled.connect(func(on: bool) -> void: SettingsManager.set_value(_section, key, on))
			h.add_child(cb)
		"choice":
			var labels: Array = spec[3]
			var ob := OptionButton.new()
			for l in labels:
				ob.add_item(str(l))
			var idx := 0
			if cur is String:
				idx = maxi(0, labels.find(cur))
			else:
				idx = clampi(int(cur), 0, labels.size() - 1)
			ob.select(idx)
			ob.custom_minimum_size = Vector2(250, 52)
			ob.add_theme_font_size_override("font_size", 22)
			ob.item_selected.connect(func(i: int) -> void:
				SettingsManager.set_value(_section, key, str(labels[i]) if cur is String else i)
				if key == "quality":
					_rebuild())              # le préréglage réécrit fps, résolution, ombres, etc.
			h.add_child(ob)
		"fps":
			var fl: Array = SettingsManager.available_fps()
			var fb := OptionButton.new()
			for f in fl:
				fb.add_item("%d FPS" % int(f))
			fb.select(maxi(0, fl.find(int(cur))))
			fb.custom_minimum_size = Vector2(250, 52)
			fb.add_theme_font_size_override("font_size", 22)
			fb.item_selected.connect(func(i: int) -> void: SettingsManager.set_value(_section, key, int(fl[i])))
			h.add_child(fb)
	return card

func _fmt(v: float, vmax: float) -> String:
	if vmax <= 1.0:
		return "%d %%" % int(round(v * 100.0))
	if vmax > 100.0:
		return "%d" % int(round(v))
	return "%.2f" % v
