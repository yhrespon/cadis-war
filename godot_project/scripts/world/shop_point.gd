class_name ShopPoint
extends Node3D
## Comptoir de magasin : interactable devant la porte du magasin.

var prompt := "Entrer dans le magasin"
var interact_range := 2.6

func _ready() -> void:
	add_to_group("interactable")
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.04
	m.mesh = cm
	m.position.y = 0.04
	m.material_override = CityBuilder.mat(Color(1.0, 0.82, 0.2))
	add_child(m)

func interact(p: Node) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("open_shop"):
		scene.call("open_shop")
