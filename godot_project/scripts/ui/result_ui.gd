class_name ResultUI
extends BasePanel
## Écran de résultat (Mission secrète) : titre, lignes de détail, Rejouer / Menu. Fermer ou retour Android = menu principal.
## [NON TESTÉ DANS GODOT]

var title_text := ""
var lines: Array = []
var good := false
var retry: Callable = Callable()

static func open(host: Node, title: String, detail: Array, success: bool, retry_cb: Callable) -> void:
	var r := ResultUI.new()
	r.title_text = title
	r.lines = detail
	r.good = success
	r.retry = retry_cb
	r.on_closed = func() -> void: GameManager.go_main_menu()
	BasePanel.show_panel(host, r)

func _title() -> String:
	return title_text

func _build_content() -> void:
	var wrap := CenterContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(wrap)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", 12)
	wrap.add_child(col)
	col.add_child(UIKit.label("RÉUSSIE" if good else "ÉCHOUÉE", 44, Color(0.5, 1.0, 0.6) if good else Color(1.0, 0.45, 0.45), false))
	for l in lines:
		col.add_child(UIKit.label(str(l), 24))
	var again := UIKit.button("Rejouer", Color(0.15, 0.4, 0.2), 64.0)
	again.pressed.connect(func() -> void:
		on_closed = retry
		close())
	col.add_child(again)
	var menu := UIKit.button("Menu principal", Color(0.3, 0.14, 0.14), 60.0)
	menu.pressed.connect(close)
	col.add_child(menu)
