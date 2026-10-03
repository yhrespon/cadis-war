class_name TravelPoint
extends Node3D
## Point de voyage (poteau bleu sur la place « travel » de chaque ville). interact() ouvre TravelUI.
## INPUT (interact) -> UI (TravelUI) -> GameManager.travel_to -> sauvegarde -> rechargement de game.tscn dans la ville choisie.
## [NON TESTÉ DANS GODOT]

var prompt := "Voyager vers une autre ville"
var interact_range := 2.6

func _ready() -> void:
	add_to_group("interactable")
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = 2.2
	post.mesh = cm
	post.position.y = 1.1
	post.material_override = CityBuilder.mat(Color(0.2, 0.22, 0.26))
	add_child(post)
	var sign_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.5, 0.06)
	sign_mesh.mesh = bm
	sign_mesh.position.y = 2.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.4, 0.9)
	mat.emission_energy_multiplier = 0.7
	sign_mesh.material_override = mat
	add_child(sign_mesh)
	var l := Label3D.new()
	l.text = "VOYAGE"
	l.font_size = 72
	l.pixel_size = 0.008
	l.position = Vector3(0, 2.1, 0.04)
	l.modulate = Color(1, 1, 1)
	add_child(l)

func interact(_p: Node) -> void:
	TravelUI.open(self)
