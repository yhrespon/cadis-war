extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	await get_tree().process_frame
	var secret_def := load("res://data/cities/secret_site.tres") as CityDef
	_check(secret_def != null, "la définition du site secret se charge")
	if secret_def == null:
		get_tree().quit(1)
		return
	_check(secret_def.traffic == 2, "le site secret déclare une densité de trafic modérée")
	_check(TrafficSignalNetwork.state_at(Vector2i(1, 1), Vector2i(1, 0), 0.0) == "yellow", "un feu X passe au jaune avant son rouge")
	_check(TrafficSignalNetwork.state_at(Vector2i(1, 1), Vector2i(0, 1), 0.0) == "red", "l’axe conflictuel est rouge")
	_check(TrafficSignalNetwork.state_at(Vector2i(1, 1), Vector2i(0, 1), 2.0) == "green", "l’axe opposé passe au vert")

	GameManager.mode = "secret"
	GameManager.current_city = "port_alpha"
	GameManager.pending_load = {}
	var game := (load("res://game.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().process_frame
	var network := get_tree().get_first_node_in_group("traffic_signal_network")
	_check(WorldManager.city != null and WorldManager.city.id == "secret_site", "la mission secrète charge bien sa propre ville")
	_check(network != null, "le site secret instancie son réseau de feux visible")
	if network != null:
		_check(network.get_child_count() == 32, "les 4 carrefours possèdent 4 têtes de feux chacun")

	await get_tree().create_timer(8.0).timeout
	var traffic := get_tree().get_nodes_in_group("traffic")
	var civilians := get_tree().get_nodes_in_group("civilian")
	_check(traffic.size() > 0, "des véhicules de trafic apparaissent dans le site secret après 8 s")
	_check(civilians.is_empty(), "aucun civil ambiant n’est ajouté à l’infiltration secrète")
	var start_positions: Array[Vector3] = []
	for vehicle in traffic:
		start_positions.append((vehicle as Node3D).global_position)
	await get_tree().create_timer(2.0).timeout
	var moved := false
	for i in mini(traffic.size(), start_positions.size()):
		var vehicle := traffic[i] as Node3D
		if is_instance_valid(vehicle) and vehicle.global_position.distance_to(start_positions[i]) > 1.0:
			moved = true
			break
	_check(moved, "au moins une voiture du site secret se déplace réellement")

	for vehicle in get_tree().get_nodes_in_group("traffic"):
		(vehicle as Node).queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	# Test physique : un véhicule arrive à 9 m/s au feu rouge et doit s’arrêter avant la ligne.
	var intersection := Vector2i(2, 1)
	var heading := Vector2i(0, 1)
	network.set("_elapsed", 0.0) # À cet instant le sens +Z du carrefour (2,1) est rouge.
	_check(str(network.call("state_for", intersection, heading)) == "red", "le feu de test est rouge avant l’approche")
	var signal_xf := TrafficDriver.spawn_transform(WorldManager.city, intersection, heading, 16.0)
	var signal_car := VehicleManager.spawn("sedan", signal_xf, WorldManager.entities)
	signal_car.add_to_group("traffic")
	var signal_driver := TrafficDriver.new()
	signal_car.add_child(signal_driver)
	signal_driver.setup(signal_car, intersection, heading, "traffic")
	signal_driver._chosen = true
	signal_driver.pending = heading
	signal_car.speed = 9.0
	await get_tree().create_timer(2.0).timeout
	var signal_rem := (TrafficDriver.node_world(WorldManager.city, intersection) - signal_car.global_position).dot(Vector3(0, 0, 1))
	_check(str(network.call("state_for", intersection, heading)) == "red", "le feu reste rouge pendant la mesure d’arrêt")
	_check(signal_rem >= 7.5 and signal_car.speed < 2.0, "la voiture freine et s’arrête avant le feu rouge")
	signal_car.queue_free()
	await get_tree().process_frame

	# Test physique du dégagement : un véhicule arrêté derrière une voiture immobile devient traversable après 7 s.
	network.set("_elapsed", 11.0) # Le sens +Z au carrefour (2,1) est vert sur cet intervalle.
	_check(str(network.call("state_for", intersection, heading)) == "green", "le feu de test est vert pour l’essai de blocage")
	var blocker_xf := TrafficDriver.spawn_transform(WorldManager.city, intersection, heading, 6.0)
	var blocker := VehicleManager.spawn("sedan", blocker_xf, WorldManager.entities)
	var ghost_xf := TrafficDriver.spawn_transform(WorldManager.city, intersection, heading, 15.0)
	var ghost_car := VehicleManager.spawn("sedan", ghost_xf, WorldManager.entities)
	ghost_car.add_to_group("traffic")
	var ghost_driver := TrafficDriver.new()
	ghost_car.add_child(ghost_driver)
	ghost_driver.setup(ghost_car, intersection, heading, "traffic")
	ghost_driver._chosen = true
	ghost_driver.pending = heading
	var wait_elapsed := 0.0
	while wait_elapsed < 13.0 and ghost_driver._ghost_t <= 0.0:
		await get_tree().create_timer(0.25).timeout
		wait_elapsed += 0.25
	_check(ghost_driver._ghost_t > 2.5 and ghost_car.collision_mask == 1, "après 7 s immobile, la voiture passe fantôme (collision mask réduit)")
	await get_tree().create_timer(3.2).timeout
	_check(ghost_driver._ghost_t <= 0.0 and ghost_car.collision_mask == ghost_driver._normal_collision_mask, "le masque de collision normal revient après 3 s")

	ghost_car.queue_free()
	blocker.queue_free()
	for player in AudioManager._pool3d + AudioManager._pool2d:
		player.stop()
		player.stream = null
	AudioManager._music.stop()
	AudioManager._music.stream = null
	AudioManager._cache.clear()
	get_tree().current_scene = null
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if failures.is_empty():
		print("RÉSULTAT: TOUS LES TESTS DE TRAFIC SONT PASSÉS")
		get_tree().quit(0)
	else:
		print("RÉSULTAT: ", failures.size(), " ÉCHEC(S)")
		get_tree().quit(1)
