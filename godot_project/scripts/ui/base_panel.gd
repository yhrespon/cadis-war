class_name BasePanel
extends CanvasLayer
## Base des écrans plein cadre (boutique, réglages, crédits) : fond assombri, cadre doré, en-tête (titre, info, Fermer), zone `body`.
## Pause du jeu seulement en partie (GameManager.in_game), restaurée à la fermeture ; bouton retour Android = fermeture ; un seul écran à la fois.
## Les sous-classes surchargent _title(), _header_info(), _build_content() et appellent _refresh_header() après une action.
## v13 : script chargé sous Godot 4.3 ; comportement du panneau non testé.

static var _active: BasePanel = null

var body: VBoxContainer
var _head_info: Label
var _was_paused := false
var _paused_by_me := false
var _back_cb: Callable
var _closed := false
var on_closed: Callable = Callable()      # appelé après la fermeture (ex. rouvrir le menu pause)

static func show_panel(host: Node, panel: BasePanel) -> void:
	if _active != null and is_instance_valid(_active):
		panel.free()
		return
	var scene := host.get_tree().current_scene
	if scene == null:
		panel.free()
		return
	scene.add_child(panel)

func _title() -> String:
	return ""

func _header_info() -> String:
	return ""

func _build_content() -> void:
	pass

func _ready() -> void:
	_active = self
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager.in_game:
		_was_paused = GameManager.paused
		GameManager.set_paused(true)
		_paused_by_me = true
		var scene := get_tree().current_scene
		if scene != null and scene.get("touch") is TouchControls:
			var tc := scene.get("touch") as TouchControls
			tc.set_context(tc.context)          # relâche stick et boutons appuyés
	_build_frame()
	_build_content()
	_refresh_header()
	_back_cb = close
	UIManager.push_back(_back_cb)

func _exit_tree() -> void:
	if _active == self:
		_active = null

func close() -> void:
	if _closed:
		return
	_closed = true
	if _active == self:
		_active = null                 # libère tout de suite : permet d'ouvrir un autre écran dans la foulée
	UIManager.pop_back(_back_cb)
	if _paused_by_me:
		GameManager.set_paused(_was_paused)
	queue_free()
	if on_closed.is_valid():
		on_closed.call()

func _refresh_header() -> void:
	if _head_info != null:
		_head_info.text = _header_info()

func _build_frame() -> void:
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
	panel.add_theme_stylebox_override("panel", UIKit.style(UIKit.BG, UIKit.GOLD, 2, 14))
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	head.add_child(UIKit.label(_title(), 38, UIKit.GOLD, false))
	_head_info = UIKit.label("", 22, Color(0.8, 0.82, 0.88), false)
	_head_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_head_info)
	var x := UIKit.button("Fermer", Color(0.3, 0.14, 0.14), 56.0)
	x.custom_minimum_size = Vector2(150, 56)
	x.pressed.connect(close)
	head.add_child(x)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)
