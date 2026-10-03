extends Node
## Registre des armes (WeaponDef .tres) + fabrique des modèles d'arme (primitives à l'échelle de la main des personnages).

var _defs: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open("res://data/registry.json", FileAccess.READ)
	var reg: Dictionary = JSON.parse_string(f.get_as_text())
	for id in reg["weapons"]:
		var d := load("res://data/weapons/%s.tres" % id) as WeaponDef
		if d != null:
			_defs[id] = d

func get_def(id: String) -> WeaponDef:
	return _defs.get(id) as WeaponDef

func all_ids() -> Array:
	return _defs.keys()
