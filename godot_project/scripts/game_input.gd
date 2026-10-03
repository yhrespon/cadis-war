class_name GameInput
extends RefCounted
## Actions d'entrée créées par code : clavier/souris, manette, et boutons tactiles (mêmes actions via Input.action_press).

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_C], "roll": [KEY_V],
	"punch": [KEY_J], "kick": [KEY_K], "fire": [KEY_F], "reload": [KEY_R], "interact": [KEY_E],
	"aim": [KEY_G], "weapon": [KEY_Q], "heal": [KEY_H], "armor": [KEY_B], "pause": [KEY_P],
	"look_left": [], "look_right": [], "look_up": [], "look_down": [],
}

static func _key(a: String, k: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k as Key
	InputMap.action_add_event(a, ev)

static func _pad_btn(a: String, b: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	InputMap.action_add_event(a, ev)

static func _pad_axis(a: String, axis: JoyAxis, v: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = v
	InputMap.action_add_event(a, ev)

static func setup() -> void:
	if InputMap.has_action("move_left"):
		return
	for a in ACTIONS:
		InputMap.add_action(a, 0.25)
		for k in ACTIONS[a]:
			_key(a, k)
	# souris (bureau uniquement : sur mobile, les touches émulent la souris pour l'UI)
	if not OS.has_feature("mobile"):
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", m)
		var m2 := InputEventMouseButton.new()
		m2.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", m2)
	# manette
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_pad_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_pad_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_pad_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_pad_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_pad_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_pad_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_btn("jump", JOY_BUTTON_A)
	_pad_btn("roll", JOY_BUTTON_B)
	_pad_btn("reload", JOY_BUTTON_X)
	_pad_btn("interact", JOY_BUTTON_Y)
	_pad_btn("weapon", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_btn("heal", JOY_BUTTON_LEFT_SHOULDER)
	_pad_btn("sprint", JOY_BUTTON_LEFT_STICK)
	_pad_btn("crouch", JOY_BUTTON_RIGHT_STICK)
	_pad_btn("punch", JOY_BUTTON_DPAD_LEFT)
	_pad_btn("kick", JOY_BUTTON_DPAD_RIGHT)
	_pad_btn("pause", JOY_BUTTON_START)
