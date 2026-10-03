class_name TouchControls
extends CanvasLayer
## Commandes tactiles : joystick virtuel à gauche, caméra en glissant à droite, boutons d'action.
## Les boutons déclenchent les mêmes actions que le clavier (Input.action_press).

const STICK_RADIUS := 110.0
const BTN_RADIUS := 58.0

var move_vector := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _btn_touch := {}          # index du doigt -> action
var _canvas: Control

func _ready() -> void:
	layer = 10
	visible = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ui)
	add_child(_canvas)

func consume_look() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d

func _buttons() -> Dictionary:
	var s := get_viewport().get_visible_rect().size
	return {
		"jump": Vector2(s.x - 130, s.y - 150), "punch": Vector2(s.x - 270, s.y - 110),
		"kick": Vector2(s.x - 230, s.y - 240), "fire": Vector2(s.x - 110, s.y - 290),
		"interact": Vector2(s.x - 370, s.y - 200), "sprint": Vector2(s.x - 490, s.y - 110),
		"roll": Vector2(s.x - 350, s.y - 330), "crouch": Vector2(s.x - 480, s.y - 250),
		"reload": Vector2(s.x - 240, s.y - 370),
	}

func _button_at(p: Vector2) -> String:
	var b := _buttons()
	for a in b:
		if p.distance_to(b[a]) <= BTN_RADIUS:
			return a
	return ""

func _input(ev: InputEvent) -> void:
	if not visible:
		return
	var s := get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			var a := _button_at(t.position)
			if a != "":
				_btn_touch[t.index] = a
				Input.action_press(a)
			elif t.position.x < s.x * 0.4 and _stick_id == -1:
				_stick_id = t.index
				_stick_origin = t.position
				_stick_pos = t.position
			elif _look_id == -1:
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
	if _stick_id != -1:
		_canvas.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		_canvas.draw_circle(_stick_origin + move_vector * STICK_RADIUS, 40.0, Color(1, 1, 1, 0.35))
	var b := _buttons()
	var font := ThemeDB.fallback_font
	for a in b:
		var on := _btn_touch.values().has(a)
		_canvas.draw_circle(b[a], BTN_RADIUS, Color(1, 1, 1, 0.38 if on else 0.18))
		_canvas.draw_string(font, b[a] + Vector2(-BTN_RADIUS * 0.8, 6), a, HORIZONTAL_ALIGNMENT_CENTER, BTN_RADIUS * 1.6, 15)
