extends Node
## Registre des PNJ actifs, budget (limites), IA à fréquence adaptée (LOD d'IA par distance) et diffusion du bruit.
## npc.ai_lod : 0 = chaque frame physique, 1 = 5 Hz, 2 = 2 Hz, 3 = endormi (invisible, sans physique).

var npcs: Array = []
var _t := 0.0
var _player: Node3D = null

func clear() -> void:
	npcs.clear()
	_player = null

func register(n: Node) -> void:
	if not npcs.has(n):
		npcs.append(n)
		n.tree_exited.connect(func() -> void: npcs.erase(n))

func max_enemies() -> int:
	return int(round(22.0 * SettingsManager.npc_density()))

func max_civilians(city: CityDef) -> int:
	return int(round(float(city.civilians) * SettingsManager.npc_density()))

func count_of(group: String) -> int:
	var c := 0
	for n in npcs:
		if is_instance_valid(n) and n.is_in_group(group):
			c += 1
	return c

func _physics_process(delta: float) -> void:
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	var pp := _player.global_position
	for n in npcs:
		if not is_instance_valid(n):
			continue
		var d: float = n.global_position.distance_to(pp)
		var lod := 0
		if d > 95.0:
			lod = 3
		elif d > 55.0:
			lod = 2
		elif d > 25.0:
			lod = 1
		if n.get("ai_lod") != lod:
			n.set("ai_lod", lod)
			if n.has_method("on_lod_changed"):
				n.call("on_lod_changed", lod)

## Bruit (tir, explosion, collision) : les PNJ dans le rayon l'entendent.
func emit_noise(pos: Vector3, radius: float, source: Node = null) -> void:
	for n in npcs:
		if not is_instance_valid(n) or not n.has_method("hear_noise"):
			continue
		if n.global_position.distance_to(pos) <= radius:
			n.call("hear_noise", pos, source)
