class_name TouchControls
extends CanvasLayer
## Commandes tactiles : joystick à gauche, caméra en glissant à droite, boutons d'action contextuels.
## Paramètres appliqués en direct : taille, transparence, position (décalage), sensibilité caméra.
## Contexte "foot" (à pied) ou "vehicle" (conduite : stick = accélérer/freiner/tourner, bouton = sortir).

const STICK_RADIUS := 110.0
const BTN_RADIUS := 56.0

var move_vector := Vector2.ZERO
var context := "foot"
var _look_delta := Vector2.ZERO
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _btn_touch := {}          # index du doigt -> action
var _canvas: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ui)
	add_child(_canvas)
	SettingsManager.changed.connect(func(_s: String, _k: String) -> void: _canvas.queue_redraw())

func set_context(c: String) -> void:
	context = c
	_release_all()
	_canvas.queue_redraw()

func _release_all() -> void:
	for idx in _btn_touch:
		Input.action_release(_btn_touch[idx])
	_btn_touch.clear()
	_stick_id = -1
	_look_id = -1
	move_vector = Vector2.ZERO

func consume_look() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d

func _scale() -> float:
	return float(SettingsManager.get_value("controls", "touch_scale"))

func _buttons() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	var ox := float(SettingsManager.get_value("controls", "touch_offset_x"))
	var oy := float(SettingsManager.get_value("controls", "touch_offset_y"))
	var k := _scale()
	var out: Dictionary = {}
	var base: Dictionary
	if context == "vehicle":
		base = {"interact": Vector2(-130, -150), "jump": Vector2(-290, -120), "pause": Vector2(-60, 60)}      # « jump » = frein à main en véhicule
	else:
		base = {
			"jump": Vector2(-130, -150), "punch": Vector2(-270, -110), "kick": Vector2(-230, -240),
			"fire": Vector2(-110, -290), "interact": Vector2(-370, -200), "sprint": Vector2(-490, -110),
			"roll": Vector2(-350, -330), "crouch": Vector2(-480, -250), "reload": Vector2(-240, -370),
			"aim": Vector2(-110, -430), "weapon": Vector2(-250, -490), "heal": Vector2(-390, -440),
			"pause": Vector2(-60, 60),
		}
	for a in base:
		var p: Vector2 = base[a]
		if a == "pause":
			out[a] = Vector2(s.x + p.x, p.y)        # coin haut-droit, hors décalage (corrigé : y était négatif = hors écran)
		else:
			out[a] = Vector2(s.x + p.x * k + ox, s.y + p.y * k + oy)
	return out

func _radius(a: String) -> float:
	return (30.0 if a == "pause" else BTN_RADIUS) * (1.0 if a == "pause" else _scale())

func _button_at(p: Vector2) -> String:
	var b := _buttons()
	for a in b:
		if p.distance_to(b[a]) <= _radius(a):
			return a
	return ""

func _input(ev: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	var s := get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			var a := _button_at(t.position)
			if a != "":
				_btn_touch[t.index] = a
				Input.action_press(a)
				SettingsManager.vibrate(12)
			elif t.position.x < s.x * 0.4 and _stick_id == -1:
				_stick_id = t.index
				_stick_origin = t.position
				_stick_pos = t.position
			elif _look_id == -1 and t.position.x >= s.x * 0.4:
				_look_id = t.index
		else:
			if _btn_touch.has(t.index):
				Input.action_release(_btn_touch[t.index])
				_btn_touch.erase(t.index)
			if t.index == _stick_id:
				_stick_id = -1
				move_vector = Vector2.ZERO
			if t.index == _look_id:
				_look_id = -1
		_canvas.queue_redraw()
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if d.index == _stick_id:
			_stick_pos = d.position
			move_vector = ((_stick_pos - _stick_origin) / STICK_RADIUS).limit_length(1.0)
		elif d.index == _look_id:
			_look_delta += d.relative
		_canvas.queue_redraw()

func _draw_ui() -> void:
	var op := float(SettingsManager.get_value("controls", "touch_opacity"))
	if _stick_id != -1:
		_canvas.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12 * op * 2.0))
		_canvas.draw_circle(_stick_origin + move_vector * STICK_RADIUS, 40.0, Color(1, 1, 1, 0.35 * op * 1.8))
	var b := _buttons()
	var font := ThemeDB.fallback_font
	var labels := {"jump": "SAUT", "punch": "COUP", "kick": "PIED", "fire": "TIR", "interact": "ACTION", "sprint": "SPRINT",
		"roll": "ROULE", "crouch": "BAISSE", "reload": "RECH.", "aim": "VISER", "weapon": "ARME", "heal": "SOIN", "pause": "II"}
	if context == "vehicle":
		labels["jump"] = "FREIN"
		labels["interact"] = "SORTIR"
	for a in b:
		var on: bool = _btn_touch.values().has(a)
		var r := _radius(a)
		_canvas.draw_circle(b[a], r, Color(1, 1, 1, (0.5 if on else 0.28) * op))
		_canvas.draw_arc(b[a], r, 0.0, TAU, 28, Color(1, 1, 1, 0.8 * op), 2.0)
		_canvas.draw_string(font, b[a] + Vector2(-r, 6), str(labels.get(a, a)), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 15, Color(1, 1, 1, min(1.0, op * 2.0)))
