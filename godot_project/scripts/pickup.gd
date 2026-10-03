class_name Pickup
extends Node3D
## Arme posée au sol : interact() -> ajoutée à l'inventaire (avec munitions) et équipée.
@export var kind := "pistol"
var prompt := ""
var interact_range := 1.6

func _ready() -> void:
	add_to_group("interactable")
	var d := WeaponManager.get_def(kind)
	if d == null:
		queue_free()
		return
	var w := Weapon.make(d)
	prompt = "Prendre : %s" % d.display_name
	w.position = Vector3(0, 0.9, 0)
	w.rotation_degrees = Vector3(0, 0, 90)
	add_child(w)

func interact(_p: Node) -> void:
	InventoryManager.grant_item("w_" + kind)
	UIManager.toast("Arme obtenue : " + WeaponManager.get_def(kind).display_name, Color(1, 0.9, 0.4))
	queue_free()

func _process(dt: float) -> void:
	rotate_y(dt)
