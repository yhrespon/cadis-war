class_name AllyController
extends NPCActor
## PNJ allié des missions « escort » / « protect » : suit le joueur à distance, groupe « friendly » (les ennemis le prennent pour cible).
## Disparaît (queue_free) peu après sa mort : MissionManager détecte l'échec par is_instance_valid().
## v13 : script chargé sous Godot 4.3 ; comportement gameplay non testé.

const FOLLOW_MIN := 2.5
const FOLLOW_RUN := 9.0

func _allowed_ages() -> Array:
	return ["adulte"]

func _setup_role() -> void:
	add_to_group("friendly")
	collision_layer = 8
	collision_mask = 1 | 2 | 8 | 16
	max_hp = 150.0
	corpse_time = 1.2
	randomize_outfit([Color(0.85, 0.85, 0.8), Color(0.3, 0.45, 0.6), Color(0.55, 0.5, 0.35)])

func _think(_dt: float) -> void:
	_face_dir = Vector3.ZERO
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		_stop()
		return
	var d := _flat_dist(p.global_position)
	if d > FOLLOW_RUN:
		_go(p.global_position, run_v)
	elif d > FOLLOW_MIN + 1.0:
		_go(p.global_position, walk_v * 1.3)
	else:
		_stop()
		_face_dir = _flat_dir_to(p.global_position)

func _on_died(_from: Node) -> void:
	remove_from_group("friendly")
