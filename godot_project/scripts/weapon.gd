class_name Weapon
extends Node3D
## Arme procédurale (primitives). À attacher à la main via GameCharacter.attach_to_bone(w, "RightHand").
## Axe long = +Y de l'os de la main (bras levé : l'arme pointe devant). Ajuster grip_offset / grip_rotation_deg après test.

var kind := "pistol"
var display_name := "Pistolet"
var melee := false
var damage := 25.0
var mag_size := 12
var ammo := 12
var reserve := 36
var grip_offset := Vector3(0, 0.04, 0.0)
var grip_rotation_deg := Vector3(0, 0, 0)
var _light: OmniLight3D

static func make(k: String) -> Weapon:
	var w := Weapon.new()
	w.kind = k
	w._build()
	return w

func _build() -> void:
	var dark := _mat(Color(0.11, 0.11, 0.13))
	var wood := _mat(Color(0.5, 0.32, 0.16))
	if kind == "bat":
		display_name = "Batte"
		melee = true
		damage = 35.0
		mag_size = 0
		ammo = 0
		reserve = 0
		_cyl(0.022, 0.022, 0.30, Vector3(0, 0.12, 0), wood)
		_cyl(0.028, 0.045, 0.50, Vector3(0, 0.52, 0), wood)
	else:
		_box(Vector3(0.032, 0.18, 0.045), Vector3(0, 0.08, 0.0), dark)      # canon + culasse
		_box(Vector3(0.030, 0.05, 0.10), Vector3(0, 0.00, -0.045), dark)    # crosse
		_light = OmniLight3D.new()
		_light.position = Vector3(0, 0.2, 0)
		_light.omni_range = 3.0
		_light.light_color = Color(1.0, 0.8, 0.4)
		_light.visible = false
		add_child(_light)
	position = grip_offset
	rotation_degrees = grip_rotation_deg

## Prise calculée (manifest["weapon_grip"], MESURÉE sur la pose « shoot ») : canon vers l'avant, dessus de l'arme vers le haut,
## paume à mi-longueur de la main. Remplace grip_offset / grip_rotation_deg quand l'entrée est présente.
func apply_grip(entry: Dictionary) -> void:
	var g: Dictionary = entry.get("weapon_grip", {})
	if g.is_empty():
		return
	var c: Array = g["basis_cols"]
	var b := Basis(Vector3(c[0][0], c[0][1], c[0][2]), Vector3(c[1][0], c[1][1], c[1][2]), Vector3(c[2][0], c[2][1], c[2][2]))
	var s := float(g["hand_len_m"]) / 0.143          # échelle relative à la main adulte
	basis = b.scaled(Vector3(s, s, s))
	position = Vector3(0.045 * s, 0.5 * float(g["hand_len_m"]), 0.0)

func flash() -> void:
	if _light == null:
		return
	_light.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(_light):
		_light.visible = false

func reload() -> void:
	var need := mag_size - ammo
	var take := mini(need, reserve)
	ammo += take
	reserve -= take

func hud_text() -> String:
	return display_name if melee else "%s  %d/%d" % [display_name, ammo, reserve]

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	add_child(mi)

func _cyl(r_bottom: float, r_top: float, h: float, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	mi.mesh = cm
	mi.position = pos
	mi.material_override = m
	add_child(mi)
