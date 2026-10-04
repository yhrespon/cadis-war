class_name UIKit
extends RefCounted
## Fabrique de contrôles pour les écrans (boutique, réglages, crédits) : même style que le panneau de missions. Données = aucune, pur style.
## [NON TESTÉ DANS GODOT]

const GOLD := Color(1.0, 0.85, 0.3)
const BG := Color(0.07, 0.08, 0.11, 0.98)
const CARD := Color(0.13, 0.14, 0.19)

static func style(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 10) -> StyleBoxFlat:
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

static func label(text: String, size := 22, color := Color.WHITE, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, color := Color(0.18, 0.2, 0.26), height := 60.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_stylebox_override("normal", style(color, Color(1, 1, 1, 0.15), 1))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.15), GOLD, 2))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2), GOLD, 2))
	b.add_theme_stylebox_override("focus", style(color.lightened(0.1), GOLD, 3))
	b.add_theme_stylebox_override("disabled", style(Color(0.12, 0.13, 0.16), Color(1, 1, 1, 0.06), 1))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.pressed.connect(func() -> void: AudioManager.play_ui("ui_select"))
	return b

## Colonne défilante verticale (pas de défilement horizontal) ; retourne la VBox à remplir.
static func scroll_column(parent: Control, separation := 8) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	sc.add_child(box)
	return box
