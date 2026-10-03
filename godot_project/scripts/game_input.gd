class_name GameInput
extends RefCounted
## Actions d'entrée créées par code (clavier). Les boutons tactiles appellent Input.action_press() sur les mêmes actions.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "crouch": [KEY_C], "roll": [KEY_V],
	"punch": [KEY_J], "kick": [KEY_K], "fire": [KEY_F], "reload": [KEY_R], "interact": [KEY_E],
}

static func setup() -> void:
	if InputMap.has_action("move_left"):
		return
	for a in ACTIONS:
		InputMap.add_action(a)
		for k in ACTIONS[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k as Key
			InputMap.action_add_event(a, ev)
