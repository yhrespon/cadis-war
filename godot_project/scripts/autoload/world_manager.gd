extends Node
## Ville courante : une seule ville chargée à la fois, découpée en secteurs (un secteur = un bloc) chargés/déchargés
## autour du joueur. Le sol est un unique StaticBody permanent ; seuls bâtiments/props/PNJ civils sont streamés.

signal city_loaded(city_id: String)
signal sector_loaded(key: Vector2i)

const CITY_PATH := "res://data/cities/%s.tres"

var city: CityDef = null
var root: Node3D = null              # parent des secteurs
var entities: Node3D = null          # PNJ, véhicules, objets (hors secteurs)
var sectors: Dictionary = {}         # Vector2i -> Node3D
var _t := 0.0
var _poi_cache: Dictionary = {}
var load_radius := 2                 # en blocs (Chebyshev)

func pitch() -> float:
	return city.block_size + city.road_width

func block_center(b: Vector2i) -> Vector3:
	return Vector3(float(b.x) * pitch(), 0.0, float(b.y) * pitch())

func block_of(pos: Vector3) -> Vector2i:
	return Vector2i(int(round(pos.x / pitch())), int(round(pos.z / pitch())))

func in_bounds(b: Vector2i) -> bool:
	return b.x >= 0 and b.y >= 0 and b.x < city.blocks_x and b.y < city.blocks_z

func poi_position(name: String) -> Vector3:
	if city == null or not city.pois.has(name):
		return Vector3.ZERO
	return block_center(city.pois[name])

func poi_exists(name: String) -> bool:
	return city != null and city.pois.has(name)

func sector_name_at(pos: Vector3) -> String:
	if city == null:
		return ""
	var b := block_of(pos)
	for k in city.pois:
		if city.pois[k] == b:
			return "%s · %s" % [city.display_name, str(k)]
	return "%s · secteur %d-%d" % [city.display_name, b.x, b.y]

func city_extent() -> Rect2:
	var p := pitch()
	return Rect2(-p * 0.5, -p * 0.5, p * float(city.blocks_x), p * float(city.blocks_z))

func load_city(id: String, parent: Node3D) -> bool:
	unload_city()
	city = load(CITY_PATH % id) as CityDef
	if city == null:
		push_error("Ville introuvable : %s" % id)
		return false
	root = Node3D.new()
	root.name = "City_" + id
	parent.add_child(root)
	entities = Node3D.new()
	entities.name = "Entities"
	parent.add_child(entities)
	CityBuilder.build_ground(city, root, city_extent())
	var signal_network := TrafficSignalNetwork.new()
	signal_network.name = "TrafficSignalNetwork"
	signal_network.configure(city)
	root.add_child(signal_network)
	GameManager.current_city = id
	city_loaded.emit(id)
	return true

func unload_city() -> void:
	for k in sectors.keys():
		_unload_sector(k)
	sectors.clear()
	if root != null and is_instance_valid(root):
		root.queue_free()
	if entities != null and is_instance_valid(entities):
		entities.queue_free()
	root = null
	entities = null
	city = null

func update_around(pos: Vector3, force_all := false) -> void:
	if city == null or root == null:
		return
	var c := block_of(pos)
	var want: Dictionary = {}
	var r := load_radius if not force_all else 99
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var b := Vector2i(c.x + dx, c.y + dz)
			if in_bounds(b):
				want[b] = true
	for b in want:
		if not sectors.has(b):
			_load_sector(b)
	for b in sectors.keys():
		if not want.has(b):
			_unload_sector(b)

func _load_sector(b: Vector2i) -> void:
	var n := Node3D.new()
	n.name = "S_%d_%d" % [b.x, b.y]
	n.position = block_center(b)
	root.add_child(n)
	sectors[b] = n
	CityBuilder.build_block(city, b, n, _poi_at(b))
	_spawn_parked_cars(b, n)
	sector_loaded.emit(b)

## Voitures garées pilotables (1 à 2 par secteur, voie côté trottoir). Pas de civils ici : CivilianController pas encore écrit.
## Déterministe (graine ville + bloc) : un secteur rechargé retrouve les mêmes voitures. Les dégâts/positions ne sont PAS persistés.
func _spawn_parked_cars(b: Vector2i, n: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city.seed_value * 7919 + b.x * 131 + b.y * 17
	var ids: Array = VehicleManager.def_ids().filter(func(i: Variant) -> bool: return i != "truck" and i != "plane" and i != "heli")
	if rng.randf() < 0.06:
		ids = ["heli"] if rng.randf() < 0.5 else ["plane"]       # rares : un hélicoptère / un avion garés
	if ids.is_empty():
		return
	var lane := city.block_size * 0.5 + 2.1 + 0.55     # v17 : contre la bordure (le trafic roule sur la voie à 1,1 m de l'axe de la route)
	var count := 1 + (rng.randi() % 2)
	for i in count:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var along := rng.randf_range(-city.block_size * 0.35, city.block_size * 0.35)
		var on_x_road := rng.randf() < 0.5
		var local := Vector3(side * lane, 0.1, along) if on_x_road else Vector3(along, 0.1, side * lane)
		var yaw := 0.0 if on_x_road else PI * 0.5
		var xf := Transform3D(Basis(Vector3.UP, yaw), local)      # local au secteur (VehicleManager.spawn assigne transform avant add_child)
		VehicleManager.spawn(str(ids[rng.randi() % ids.size()]), xf, n)

func _unload_sector(b: Vector2i) -> void:
	var n: Node3D = sectors.get(b)
	if n != null and is_instance_valid(n):
		# un véhicule conduit ou possédé ne doit pas disparaître avec son secteur
		for v in n.get_children():
			if v is Vehicle and (v.driver != null or v.persistent):
				v.reparent(entities)
		n.queue_free()
	sectors.erase(b)

func _poi_at(b: Vector2i) -> String:
	for k in city.pois:
		if city.pois[k] == b:
			return str(k)
	return ""

func _physics_process(delta: float) -> void:
	if city == null:
		return
	_t += delta
	if _t < 0.4:
		return
	_t = 0.0
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	if pl != null:
		update_around(pl.global_position)

## Rectangles (monde, plan XZ) des blocs proches : utilisés par la minimap réelle.
func block_rects_near(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	if city == null:
		return out
	var hs := city.block_size * 0.5
	var c := block_of(pos)
	var n := int(ceil(radius / pitch())) + 1
	for dx in range(-n, n + 1):
		for dz in range(-n, n + 1):
			var b := Vector2i(c.x + dx, c.y + dz)
			if in_bounds(b):
				var ctr := block_center(b)
				out.append(Rect2(ctr.x - hs, ctr.z - hs, city.block_size, city.block_size))
	return out
