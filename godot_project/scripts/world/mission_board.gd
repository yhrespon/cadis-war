class_name MissionBoard
extends Node3D
## Panneau de missions dans le monde (mesh jaune). interact() ouvre MissionPanel (scripts/ui/mission_panel.gd) : liste, détail,
## Accepter / Abandonner. INPUT (interact) -> UI (MissionPanel) -> MissionManager.accept -> état (active_id) -> HUD -> SAVE.
## [NON TESTÉ]

var prompt := "Consulter les missions"
var interact_range := 2.4

func _ready() -> void:
	add_to_group("interactable")
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.06
	cm.height = 1.4
	post.mesh = cm
	post.position.y = 0.7
	post.material_override = CityBuilder.mat(Color(0.25, 0.25, 0.28))
	add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.6, 0.05)
	board.mesh = bm
	board.position.y = 1.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.7, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.6, 0.1)
	mat.emission_energy_multiplier = 0.6
	board.material_override = mat
	add_child(board)

func interact(_p: Node) -> void:
	MissionPanel.open(self)
