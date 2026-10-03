class_name TargetDummy
extends StaticBody3D
## Mannequin d'entraînement : prend des dégâts (tir / mêlée), clignote, réapparaît après 3 s.

var hp := 100.0
var _shape: CollisionShape3D
var _mat := StandardMaterial3D.new()

func _ready() -> void:
	add_to_group("damageable")
	_mat.albedo_color = Color(0.8, 0.75, 0.6)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.5
	body.mesh = cm
	body.position.y = 0.85
	body.material_override = _mat
	add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	head.mesh = sm
	head.position.y = 1.78
	head.material_override = _mat
	add_child(head)
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.9
	_shape.shape = cap
	_shape.position.y = 0.95
	add_child(_shape)

func take_damage(amount: float, _from: Node = null) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_mat.albedo_color = Color(0.9, 0.2, 0.2)
	await get_tree().create_timer(0.12).timeout
	_mat.albedo_color = Color(0.8, 0.75, 0.6)
	if hp <= 0.0:
		visible = false
		_shape.set_deferred("disabled", true)
		await get_tree().create_timer(3.0).timeout
		hp = 100.0
		visible = true
		_shape.set_deferred("disabled", false)
