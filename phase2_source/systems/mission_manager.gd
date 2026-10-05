extends Node
## Vertical slice phase 2 : mission aventure jouable sans dépendance réseau.
## Les objectifs sont persistants, lisibles à l’écran et extensibles vers le coop.

signal objective_changed(index: int, title: String, completed: bool)
signal checkpoint_reached(index: int)
signal mission_completed(mission_id: String)

const MISSION_ID := "north_gate_revolt"
const CHECKPOINT_PATH := "user://cadis_phase2_checkpoint.cfg"
const OBJECTIVES := [
	"Rejoindre le sas nord",
	"Neutraliser la menace robotique",
	"Atteindre le point d’extraction"
]
const TARGETS := [
	Vector3(20.0, -2.0, 35.0),
	Vector3(0.0, -5.0, 0.0),
	Vector3(-28.0, -3.0, -34.0)
]

var active := false
var objective_index := -1
var checkpoint_index := -1
var _level: Node3D
var _hud: CanvasLayer
var _objective_label: Label
var _checkpoint_label: Label
var _robot_baseline := 0
var _robot_clear_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()

func start_mission(level: Node3D) -> void:
	_level = level
	active = true
	objective_index = _load_checkpoint()
	checkpoint_index = objective_index - 1
	_robot_baseline = level.get_node_or_null("SpawnedNodes").get_child_count() if level.get_node_or_null("SpawnedNodes") else 0
	_set_objective(maxi(objective_index, 0))
	DialogueManager.play_line(
		"Joe, le sas nord est verrouillé. Rejoins-le, puis sécurise le complexe.",
		"res://audio/dialogue/mission_intro_fr.wav",
		8.0
	)

func _process(delta: float) -> void:
	if not active or _level == null or objective_index < 0:
		return
	var player := _find_local_player()
	if player == null:
		return
	var distance := player.global_position.distance_to(TARGETS[objective_index])
	if objective_index == 1:
		var spawned := _level.get_node_or_null("SpawnedNodes")
		var alive := spawned.get_child_count() if spawned else 0
		if alive <= 1:
			_robot_clear_timer += delta
		else:
			_robot_clear_timer = 0.0
		if _robot_clear_timer >= 1.0:
			_complete_objective()
	elif distance < 9.0:
		_complete_objective()
	_update_hud(distance)

func _find_local_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("cadis_local_player")
	if players.is_empty():
		return null
	return players[0] as Node3D

func _complete_objective() -> void:
	checkpoint_index = objective_index
	_save_checkpoint(checkpoint_index + 1)
	checkpoint_reached.emit(checkpoint_index)
	objective_changed.emit(objective_index, OBJECTIVES[objective_index], true)
	if objective_index >= OBJECTIVES.size() - 1:
		active = false
		_objective_label.text = "MISSION RÉUSSIE\n" + MISSION_ID
		_checkpoint_label.text = "Récompense : accès au secteur nord"
		DialogueManager.play_line("Extraction confirmée. Le complexe est sous contrôle.", "", 5.0)
		mission_completed.emit(MISSION_ID)
		return
	_set_objective(objective_index + 1)

func _set_objective(index: int) -> void:
	objective_index = clampi(index, 0, OBJECTIVES.size() - 1)
	objective_changed.emit(objective_index, OBJECTIVES[objective_index], false)
	_objective_label.text = "OBJECTIF %d/%d\n%s" % [objective_index + 1, OBJECTIVES.size(), OBJECTIVES[objective_index]]
	_checkpoint_label.text = "Point de contrôle : %d" % (checkpoint_index + 1)
	if objective_index == 1:
		DialogueManager.play_line("Le robot a verrouillé le secteur. Ouvre-toi un passage.", "res://audio/dialogue/boss_warning_fr.wav", 5.0)

func _update_hud(distance: float) -> void:
	if objective_index < 0 or objective_index >= TARGETS.size():
		return
	if objective_index != 1:
		_checkpoint_label.text = "Point de contrôle : %d  |  Distance : %dm" % [checkpoint_index + 1, roundi(distance)]

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "MissionHUD"
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28)
	panel.size = Vector2(390, 112)
	panel.modulate = Color(0.03, 0.05, 0.08, 0.88)
	_hud.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_objective_label = Label.new()
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_label.text = "MISSION EN ATTENTE"
	box.add_child(_objective_label)
	_checkpoint_label = Label.new()
	_checkpoint_label.add_theme_font_size_override("font_size", 14)
	_checkpoint_label.text = "Point de contrôle : aucun"
	box.add_child(_checkpoint_label)

func _save_checkpoint(value: int) -> void:
	var config := ConfigFile.new()
	config.set_value("mission", MISSION_ID, value)
	config.save(CHECKPOINT_PATH)

func _load_checkpoint() -> int:
	var config := ConfigFile.new()
	if config.load(CHECKPOINT_PATH) != OK:
		return 0
	return clampi(int(config.get_value("mission", MISSION_ID, 0)), 0, OBJECTIVES.size() - 1)
