class_name TravelUI
extends BasePanel
## Choix de la ville de destination. Villes débloquées (GameManager.unlocked_cities) uniquement ; la ville courante et les villes verrouillées
## sont grisées ; refusé pendant une mission (même règle que GameManager.travel_to). [NON TESTÉ DANS GODOT]

const ORDER := ["port_alpha", "nova_district", "ironworks", "sunset_bay"]

static func open(host: Node) -> void:
	BasePanel.show_panel(host, TravelUI.new())

func _title() -> String:
	return "VOYAGE"

func _header_info() -> String:
	return "%d $" % GameManager.money

func _build_content() -> void:
	var col := UIKit.scroll_column(body, 10)
	if MissionManager.active_id != "":
		col.add_child(UIKit.label("Terminez ou abandonnez votre mission avant de voyager.", 22, Color(1.0, 0.7, 0.4)))
	for id in ORDER:
		var def := load("res://data/cities/%s.tres" % id) as CityDef
		var name_txt: String = def.display_name if def != null else id
		var unlocked: bool = GameManager.unlocked_cities.has(id)
		var here: bool = id == GameManager.current_city
		var b: Button
		if here:
			b = UIKit.button("%s — vous êtes ici" % name_txt, Color(0.16, 0.18, 0.23), 70.0)
			b.disabled = true
		elif not unlocked:
			b = UIKit.button("%s — verrouillée (terminez la mission d'histoire de la ville précédente)" % name_txt, Color(0.16, 0.18, 0.23), 70.0)
			b.disabled = true
		else:
			b = UIKit.button("Aller à %s" % name_txt, Color(0.15, 0.4, 0.2), 70.0)
			b.disabled = MissionManager.active_id != ""
			b.pressed.connect(_go.bind(id))
		col.add_child(b)

func _go(id: String) -> void:
	close()
	if not GameManager.travel_to(id):
		UIManager.toast("Voyage impossible pour le moment", Color(1, 0.4, 0.4))
