class_name CharacterUI
extends BasePanel
## Choix du personnage (menu principal) : les 10 personnages du manifest (genre, âge, taille). Choisir = GameManager.character_id (utilisé par Player),
## sauvegardé seulement s'il existe déjà une sauvegarde (sinon gardé en mémoire : new_game() ne le réinitialise pas). Pas d'aperçu 3D dans cet écran :
## le décor 3D du menu se met à jour à la fermeture (on_closed). [NON TESTÉ DANS GODOT]

const GENDER := {"m": "Homme", "f": "Femme"}

static func open(host: Node, closed_cb: Callable = Callable()) -> void:
	var p := CharacterUI.new()
	p.on_closed = closed_cb
	BasePanel.show_panel(host, p)

func _title() -> String:
	return "PERSONNAGE"

func _header_info() -> String:
	return "Actuel : %s" % _pretty(GameManager.character_id)

func _pretty(id: String) -> String:
	return id.replace("_", " ").capitalize()

func _build_content() -> void:
	var col := UIKit.scroll_column(body, 8)
	for id in GameManager.character_ids():
		col.add_child(_row(GameManager.character_entry(str(id))))

func _row(c: Dictionary) -> Control:
	var id := str(c["id"])
	var card := PanelContainer.new()
	var current := id == GameManager.character_id
	card.add_theme_stylebox_override("panel", UIKit.style(Color(0.3, 0.24, 0.08) if current else UIKit.CARD, UIKit.GOLD if current else Color(1, 1, 1, 0.08), 2 if current else 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UIKit.label(_pretty(id), 26, Color.WHITE))
	info.add_child(UIKit.label("%s · %s · %.2f m" % [GENDER.get(str(c.get("gender", "")), "?"), str(c.get("age", "")).capitalize(), float(c.get("height_m", 0.0))], 19, Color(0.75, 0.78, 0.85)))
	var b := UIKit.button("Sélectionné" if current else "Choisir", Color(0.15, 0.4, 0.2), 60.0)
	b.custom_minimum_size = Vector2(200, 60)
	b.disabled = current
	b.pressed.connect(func() -> void:
		GameManager.character_id = id
		if SaveManager.any_save():
			SaveManager.save_profile()
		close())
	h.add_child(b)
	return card
