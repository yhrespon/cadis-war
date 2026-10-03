extends Node
## Transitions de scène (fondu), messages courts (toasts), bouton retour Android par contexte.

var _fade: ColorRect
var _layer: CanvasLayer
var _toasts: VBoxContainer
var _back_stack: Array = []          # Callables : le dernier enregistré traite le « retour »
var _busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 70
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_toasts)

func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_back_stack.clear()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.25)
	await tw.finished
	get_tree().paused = false
	GameManager.paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Impossible de charger la scène : %s" % path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.3)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

## Message court en haut d'écran (récompense, mission, achat...).
func toast(text: String, color := Color.WHITE, seconds := 3.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(l)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

## Retour Android : chaque écran ouvert enregistre un handler (le plus récent est appelé).
func push_back(handler: Callable) -> void:
	_back_stack.append(handler)

func pop_back(handler: Callable) -> void:
	_back_stack.erase(handler)

func handle_back() -> void:
	while not _back_stack.is_empty():
		var h: Callable = _back_stack[_back_stack.size() - 1]
		if h.is_valid():
			h.call()
			return
		_back_stack.pop_back()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("on_back"):
		scene.call("on_back")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.autosave_if_playing()
		get_tree().quit()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		handle_back()
