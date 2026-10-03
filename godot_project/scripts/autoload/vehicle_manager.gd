extends Node
## Registre des véhicules (VehicleDef) + suivi des véhicules actifs (sauvegarde, trafic).

var _defs: Dictionary = {}
var vehicles: Array = []

func _ready() -> void:
	var f := FileAccess.open("res://data/registry.json", FileAccess.READ)
	var reg: Dictionary = JSON.parse_string(f.get_as_text())
	for id in reg["vehicles"]:
		var d := load("res://data/vehicles/%s.tres" % id) as VehicleDef
		if d != null:
			_defs[id] = d

func reset() -> void:
	vehicles.clear()

func get_def(id: String) -> VehicleDef:
	return _defs.get(id) as VehicleDef

func def_ids() -> Array:
	return _defs.keys()

func spawn(id: String, xf: Transform3D, parent: Node) -> Vehicle:
	var d := get_def(id)
	if d == null:
		return null
	var v := Vehicle.new()
	v.def = d
	v.transform = xf
	parent.add_child(v)
	vehicles.append(v)
	v.tree_exited.connect(func() -> void: vehicles.erase(v))
	return v

func driven_vehicle() -> Vehicle:
	for v in vehicles:
		if is_instance_valid(v) and v.driver != null:
			return v
	return null
