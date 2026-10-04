class_name TrafficSignalNetwork
extends Node3D
## Réseau de feux de la ville : une phase commune par axe et carrefour, avec jaune et tout-rouge.
## Les états sont aussi consommés par TrafficDriver ; les lampes sont des meshes émissifs (sans lumière temps réel).

const GREEN_SECONDS := 18.0
const AMBER_SECONDS := 3.0
const ALL_RED_SECONDS := 1.0
const HALF_CYCLE := GREEN_SECONDS + AMBER_SECONDS + ALL_RED_SECONDS
const CYCLE_SECONDS := HALF_CYCLE * 2.0
const SIGNAL_DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LANE_OFFSET := 1.1
const CURB_OFFSET := 6.2
const STOP_OFFSET := 6.7

var city: CityDef = null
var _elapsed := 0.0
var _refresh_t := 0.0
var _heads: Array[Dictionary] = []

func configure(city_def: CityDef) -> void:
	city = city_def

func _ready() -> void:
	add_to_group("traffic_signal_network")
	_build_signals()
	_refresh_lights()

func _process(delta: float) -> void:
	_elapsed += delta
	_refresh_t += delta
	if _refresh_t >= 0.2:
		_refresh_t = 0.0
		_refresh_lights()

## État d'un feu en fonction du temps écoulé depuis le lancement de la ville.
## heading est le sens d'arrivée au carrefour. Deux sens opposés d'un même axe partagent la phase.
static func state_at(intersection: Vector2i, heading: Vector2i, elapsed: float) -> String:
	if heading == Vector2i.ZERO:
		return "red"
	var offset := float(posmod(intersection.x * 13 + intersection.y * 7, int(HALF_CYCLE)))
	var phase := fposmod(elapsed + offset, CYCLE_SECONDS)
	if heading.y == 0:
		if phase < GREEN_SECONDS:
			return "green"
		if phase < GREEN_SECONDS + AMBER_SECONDS:
			return "yellow"
		return "red"
	var cross_start := HALF_CYCLE
	if phase >= cross_start and phase < cross_start + GREEN_SECONDS:
		return "green"
	if phase >= cross_start + GREEN_SECONDS and phase < cross_start + GREEN_SECONDS + AMBER_SECONDS:
		return "yellow"
	return "red"

func state_for(intersection: Vector2i, heading: Vector2i) -> String:
	return state_at(intersection, heading, _elapsed)

func _build_signals() -> void:
	_heads.clear()
	if city == null:
		push_error("TrafficSignalNetwork : CityDef absente")
		return
	var pitch := city.block_size + city.road_width
	for x in range(1, city.blocks_x):
		for z in range(1, city.blocks_z):
			var intersection := Vector2i(x, z)
			var center := Vector3(-pitch * 0.5 + float(x) * pitch, 0.0, -pitch * 0.5 + float(z) * pitch)
			for heading in SIGNAL_DIRECTIONS:
				_create_head(intersection, center, heading)

func _create_head(intersection: Vector2i, center: Vector3, heading: Vector2i) -> void:
	var forward := Vector3(float(heading.x), 0.0, float(heading.y))
	var right := Vector3(-float(heading.y), 0.0, float(heading.x))
	var post_position := center - forward * STOP_OFFSET + right * CURB_OFFSET
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.1
	pole_mesh.height = 3.6
	var pole := MeshInstance3D.new()
	pole.mesh = pole_mesh
	pole.position = post_position + Vector3(0, 1.8, 0)
	pole.material_override = _material(Color(0.16, 0.17, 0.19), false)
	add_child(pole)

	var yaw := atan2(-float(heading.x), -float(heading.y))
	var head := Node3D.new()
	head.position = post_position + Vector3(0, 3.0, 0)
	head.rotation.y = yaw
	add_child(head)
	var housing := MeshInstance3D.new()
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(0.38, 0.9, 0.3)
	housing.mesh = housing_mesh
	housing.material_override = _material(Color(0.055, 0.06, 0.07), false)
	head.add_child(housing)

	var bulbs: Array[MeshInstance3D] = []
	var colors: Array[Color] = [Color(1.0, 0.12, 0.08), Color(1.0, 0.68, 0.08), Color(0.12, 0.95, 0.28)]
	for i in 3:
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.105
		sphere.height = 0.21
		bulb.mesh = sphere
		bulb.position = Vector3(0, 0.27 - float(i) * 0.27, 0.17)
		bulb.material_override = _material(colors[i], false)
		head.add_child(bulb)
		bulbs.append(bulb)
	_heads.append({"intersection": intersection, "heading": heading, "bulbs": bulbs})

func _material(color: Color, lit: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color if lit else color.darkened(0.78)
	material.roughness = 0.35
	material.emission_enabled = lit
	material.emission = color
	material.emission_energy_multiplier = 2.0 if lit else 0.0
	return material

func _refresh_lights() -> void:
	for entry in _heads:
		var state := state_for(entry["intersection"], entry["heading"])
		var lit_index := 0 if state == "red" else (1 if state == "yellow" else 2)
		var bulbs: Array = entry["bulbs"]
		for i in bulbs.size():
			var bulb := bulbs[i] as MeshInstance3D
			var material := bulb.material_override as StandardMaterial3D
			var color := Color(1.0, 0.12, 0.08) if i == 0 else (Color(1.0, 0.68, 0.08) if i == 1 else Color(0.12, 0.95, 0.28))
			var lit := i == lit_index
			material.albedo_color = color if lit else color.darkened(0.78)
			material.emission_enabled = lit
			material.emission_energy_multiplier = 2.0 if lit else 0.0
