class_name CreditsUI
extends BasePanel
## Crédits. Le texte du modèle de personnage reprend mot pour mot la mention exigée par la licence CC-BY-4.0 (source_model/license.txt) :
## à conserver dans toute version distribuée. [NON TESTÉ DANS GODOT]

const MODEL_CREDIT := "This work is based on \"Fuse personnage\" (https://sketchfab.com/3d-models/fuse-personnage-826c65a1832d45a7a72e107a20f26864) by 1831251 (https://sketchfab.com/1831251) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)"

static func open(host: Node) -> void:
	BasePanel.show_panel(host, CreditsUI.new())

func _title() -> String:
	return "CRÉDITS"

func _build_content() -> void:
	var col := UIKit.scroll_column(body, 14)
	col.add_child(UIKit.label("C.A.D.I.S WARS", 40, UIKit.GOLD))
	col.add_child(UIKit.label("Version de développement", 20, Color(0.7, 0.75, 0.85)))
	col.add_child(UIKit.label("Modèle de personnage", 26, UIKit.GOLD))
	col.add_child(UIKit.label(MODEL_CREDIT, 20, Color(0.9, 0.9, 0.95)))
	col.add_child(UIKit.label("Les personnages du jeu (têtes, cheveux, vêtements, animations) sont dérivés de ce modèle par traitement procédural.", 20, Color(0.75, 0.78, 0.85)))
	col.add_child(UIKit.label("Moteur : Godot Engine 4 (licence MIT).", 20, Color(0.75, 0.78, 0.85)))
