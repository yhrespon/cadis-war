class_name Weapon
extends Node3D
## Modèle visuel d'arme (primitives) à l'échelle de la main. Convention du manifest (weapon_grip) :
## canon = +Y de l'arme, dessus = +Z de l'arme, la crosse pend vers -Z. Les stats viennent de WeaponDef.

var def: WeaponDef
var muzzle: Marker3D
var _light: OmniLight3D

static func make(d: WeaponDef) -> Weapon:
	var w := Weapon.new()
	w.def = d
	w._build()
	return w

func _build() -> void:
	var dark := _mat(Color(0.11, 0.11, 0.13))
	var wood := _mat(Color(0.5, 0.32, 0.16))
	var steel := _mat(Color(0.3, 0.3, 0.34))
	var muzzle_y := 0.17
	match def.model:
		"bat":
			_cyl(0.022, 0.022, 0.30, Vector3(0, 0.12, 0), wood)
			_cyl(0.028, 0.045, 0.50, Vector3(0, 0.52, 0), wood)
			muzzle_y = 0.8
		"dagger":
			var blade := _mat(Color(0.78, 0.8, 0.84))
			blade.metallic = 0.8
			blade.roughness = 0.25
			_cyl(0.017, 0.019, 0.11, Vector3(0, 0.045, 0), dark)             # manche
			_box(Vector3(0.012, 0.014, 0.10), Vector3(0, 0.105, 0), steel)  # garde
			_box(Vector3(0.010, 0.26, 0.032), Vector3(0, 0.24, 0), blade)   # lame
			_box(Vector3(0.010, 0.05, 0.020), Vector3(0, 0.395, 0), blade)  # pointe
			muzzle_y = 0.42
		"smg":
			_box(Vector3(0.04, 0.34, 0.06), Vector3(0, 0.15, 0.0), dark)
			_box(Vector3(0.025, 0.05, 0.14), Vector3(0, 0.1, -0.10), dark)
			_box(Vector3(0.03, 0.05, 0.09), Vector3(0, -0.01, -0.06), dark)
			muzzle_y = 0.33
		"shotgun":
			_cyl(0.016, 0.016, 0.62, Vector3(0, 0.30, 0.012), steel)
			_box(Vector3(0.04, 0.22, 0.07), Vector3(0, -0.11, -0.01), wood)
			_box(Vector3(0.05, 0.14, 0.05), Vector3(0, 0.2, -0.015), wood)
			_box(Vector3(0.03, 0.05, 0.09), Vector3(0, 0.0, -0.06), dark)
			muzzle_y = 0.62
		_:
			_box(Vector3(0.032, 0.18, 0.045), Vector3(0, 0.08, 0.0), dark)
			_box(Vector3(0.030, 0.05, 0.10), Vector3(0, 0.00, -0.045), dark)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, muzzle_y, 0.0)
	add_child(muzzle)
	if not def.melee:
		_light = OmniLight3D.new()
		_light.position = Vector3(0, muzzle_y + 0.03, 0)
		_light.omni_range = 3.0
		_light.light_color = Color(1.0, 0.8, 0.4)
		_light.visible = false
		add_child(_light)

## Prise calculée (manifest["weapon_grip"], mesurée sur la pose « shoot »).
func apply_grip(entry: Dictionary) -> void:
	var g: Dictionary = entry.get("weapon_grip", {})
	if g.is_empty():
		position = Vector3(0, 0.04, 0)
		return
	var c: Array = g["basis_cols"]
	var b := Basis(Vector3(c[0][0], c[0][1], c[0][2]), Vector3(c[1][0], c[1][1], c[1][2]), Vector3(c[2][0], c[2][1], c[2][2]))
	var s := float(g["hand_len_m"]) / 0.143
	basis = b.scaled(Vector3(s, s, s))
	position = Vector3(0.045 * s, 0.5 * float(g["hand_len_m"]), 0.0)

func flash() -> void:
	if _light == null:
		return
	_light.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(_light):
		_light.visible = false

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m

func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = m
	add_child(mi)

func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	mi.mesh = cm
	mi.position = pos
	mi.material_override = m
	add_child(mi)
