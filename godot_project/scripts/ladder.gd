class_name Ladder
extends Node3D
## Échelle : le joueur se tient du côté +Z (le mur est côté -Z). Animation « climb » (0,5 m/s en hauteur).

@export var height := 3.0
var prompt := "Monter à l'échelle"
var interact_range := 1.5
var _body: StaticBody3D

func _ready() -> void:
	add_to_group("interactable")
	var c := Color(0.55, 0.4, 0.2)
	_body = StaticBody3D.new()      # collisions physiques : 2 montants + un barreau tous les 0,30 m
	add_child(_body)
	for x in [-0.25, 0.25]:
		_add_box(Vector3(0.05, height, 0.05), Vector3(x, height * 0.5, 0), c)
	var n := int(height / 0.3)
	for i in n:
		_add_box(Vector3(0.5, 0.04, 0.04), Vector3(0, 0.15 + i * 0.3, 0), c)

func interact(p: Node) -> void:
	p.start_climb(self)

func top_y() -> float:
	return global_position.y + height

func top_exit() -> Vector3:
	return global_position + global_basis * Vector3(0, height + 0.05, -0.9)

func _add_box(size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	mi.material_override = m
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	_body.add_child(cs)
