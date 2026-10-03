class_name PauseMenu
extends BasePanel
## Menu pause (étape 7) : Reprendre, mission en cours (+ abandon en 2 temps), Paramètres (reviens à la pause ensuite), Sauvegarder (emplacement 1),
## Quitter vers le menu (sauvegarde automatique en mode histoire). Ouvert par game.gd : touche/bouton « pause » ou bouton retour Android.
## Fermer = reprendre. [NON TESTÉ DANS GODOT]

var _abandon_armed := false

static func open(host: Node) -> void:
	BasePanel.show_panel(host, PauseMenu.new())

func _title() -> String:
	return "PAUSE"

func _header_info() -> String:
	return "%d $" % GameManager.money

func _build_content() -> void:
	var wrap := CenterContainer.new()
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(wrap)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(520, 0)
	col.add_theme_constant_override("separation", 12)
	wrap.add_child(col)
	if MissionManager.active_id != "":
		var d: MissionDef = MissionManager.def_of(MissionManager.active_id)
		if d != null:
			col.add_child(UIKit.label("Mission : %s" % d.title, 24, UIKit.GOLD))
			col.add_child(UIKit.label(MissionManager.objective_text(), 20, Color(0.85, 0.87, 0.92)))
	var resume := UIKit.button("Reprendre", Color(0.15, 0.4, 0.2), 64.0)
	resume.pressed.connect(close)
	col.add_child(resume)
	if MissionManager.active_id != "":
		var ab := UIKit.button("Abandonner la mission", Color(0.35, 0.14, 0.14), 60.0)
		ab.pressed.connect(func() -> void:
			if not _abandon_armed:
				_abandon_armed = true
				ab.text = "Confirmer l'abandon ?"
				return
			MissionManager.abandon()
			close())
		col.add_child(ab)
	var st := UIKit.button("Paramètres", Color(0.16, 0.18, 0.23), 60.0)
	st.pressed.connect(_open_settings)
	col.add_child(st)
	if GameManager.mode == "story":
		var sv := UIKit.button("Sauvegarder (emplacement 1)", Color(0.16, 0.18, 0.23), 60.0)
		sv.pressed.connect(func() -> void:
			var pl := get_tree().get_first_node_in_group("player")
			var ok := SaveManager.save_game("slot1", pl)
			UIManager.toast("Partie sauvegardée" if ok else "Échec de la sauvegarde", Color(0.5, 1, 0.6) if ok else Color(1, 0.4, 0.4)))
		col.add_child(sv)
	var q := UIKit.button("Quitter vers le menu", Color(0.3, 0.14, 0.14), 60.0)
	q.pressed.connect(func() -> void:
		var scene := get_tree().current_scene
		close()
		if scene != null and scene.has_method("quit_to_menu"):
			scene.call("quit_to_menu")
		else:
			GameManager.go_main_menu())
	col.add_child(q)

func _open_settings() -> void:
	var host := get_tree().current_scene
	close()
	var s := SettingsUI.new()
	s.on_closed = func() -> void: PauseMenu.open(host)
	BasePanel.show_panel(host, s)
