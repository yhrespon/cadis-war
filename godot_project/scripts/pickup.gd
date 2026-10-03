class_name Pickup
extends Node3D
## Arme posée au sol (tourne sur elle-même). interact() -> le joueur l'équipe.

@export var kind := "pistol"
var prompt := ""
var interact_range := 1.6

func _ready() -> void:
	add_to_group("interactable")
	var w := Weapon.make(kind)
	prompt = "Prendre : %s" % w.display_name
	w.position = Vector3(0, 0.9, 0)
	w.rotation_degrees = Vector3(0, 0, 90)
	add_child(w)

func interact(p: Node) -> void:
	p.equip(kind)
	queue_free()

func _process(dt: float) -> void:
	rotate_y(dt)
