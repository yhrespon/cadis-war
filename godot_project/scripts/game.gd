extends Node3D
## Scène de jeu : ville (WorldManager), joueur, commandes tactiles, HUD réel (scripts/ui/hud.gd), missions, respawn, autosave.
## Remplace l'ancien game_world.gd (ancienne API Player/Weapon).
## v13 : scène lancée en smoke-test sous Godot 4.3 ; parcours interactif non déroulé.
## Modes (GameManager.mode) : « story » (autosave, panneau, voyage), « secret » (site d'infiltration + SecretMission, aucune sauvegarde de partie), « test ».
## Restauration au chargement : position/santé, voitures possédées et voiture conduite (voir _restore_vehicles). [NON TESTÉ]

var player: Player
var touch: TouchControls
var hud: Hud
var _respawning := false

func _ready() -> void:
	GameInput.setup()
	GameManager.in_game = true
	GameManager.set_paused(false)
	var secret := GameManager.mode == "secret"
	var story_city := GameManager.current_city
	if not WorldManager.load_city("secret_site" if secret else story_city, self):
		UIManager.toast("Ville introuvable : %s" % story_city, Color(1, 0.4, 0.4))
		GameManager.go_main_menu()
		return
	GameManager.current_city = story_city          # load_city() l'a écrasée : la ville d'histoire ne doit pas changer (sauvegarde)
	_build_environment()
	NPCManager.clear()
	var spawner := NPCSpawner.new()
	spawner.name = "NPCSpawner"
	add_child(spawner)
	MissionManager.spawner = spawner
	var start := _spawn_position()
	var data: Dictionary = GameManager.pending_load
	var restoring := data.has("player")
	if restoring:
		var a: Array = data["player"]["pos"]
		start = Vector3(float(a[0]), float(a[1]), float(a[2]))
	WorldManager.update_around(start)

	player = Player.new()
	add_child(player)
	player.global_position = start
	if restoring:
		player.restore(start, float(data["player"].get("yaw", 0.0)), float(data["player"].get("health", 100.0)))
	touch = TouchControls.new()
	add_child(touch)
	player.set_touch(touch)
	player.died.connect(_on_player_died)

	if not secret:
		var board := MissionBoard.new()
		WorldManager.entities.add_child(board)
		board.global_position = WorldManager.poi_position("spawn") + Vector3(3.0, 0.0, 3.0)
		if WorldManager.poi_exists("travel"):
			var tp := TravelPoint.new()
			WorldManager.entities.add_child(tp)
			tp.global_position = WorldManager.poi_position("travel") + Vector3(0.0, 0.0, 3.0)

	hud = Hud.new()
	add_child(hud)
	hud.setup(player)

	if restoring:
		_restore_vehicles(data)
		MissionManager.resume_after_load()
	GameManager.pending_load = {}
	if secret:
		var sm := SecretMission.new()
		sm.name = "SecretMission"
		add_child(sm)
		sm.start(player)

	var t := Timer.new()
	t.wait_time = 60.0
	t.autostart = true
	t.timeout.connect(func() -> void: SaveManager.autosave(player))
	add_child(t)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _respawning and player != null and is_instance_valid(player):
		PauseMenu.open(self)

func _exit_tree() -> void:
	MissionManager.spawner = null
	NPCManager.clear()

func _spawn_position() -> Vector3:
	return WorldManager.poi_position("spawn") + Vector3(0.0, 0.1, 0.0)

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = WorldManager.city.sky_color
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.add_to_group("sun")
	sun.shadow_enabled = bool(SettingsManager.get_value("graphics", "shadows"))
	add_child(sun)

# ------------------------------------------------------------------ mort / respawn
func _on_player_died() -> void:
	if _respawning or GameManager.mode == "secret":      # Mission secrète : la mort = échec (SecretMission affiche le résultat), pas de respawn
		return
	_respawning = true
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	var hosp := WorldManager.poi_position("hospital") + Vector3(0.0, 0.1, 0.0)
	WorldManager.update_around(hosp)
	player.respawn(hosp)
	_respawning = false
	SaveManager.autosave(player)

# ------------------------------------------------------------------ restauration des véhicules
func _restore_vehicles(data: Dictionary) -> void:
	for d in Array(data.get("parked_vehicles", [])):
		_spawn_saved_vehicle(Dictionary(d))
	var drv: Dictionary = Dictionary(data.get("vehicle", {}))
	if not drv.is_empty():
		var v := _spawn_saved_vehicle(drv)
		if v != null and player != null:
			player.enter_vehicle(v)

func _spawn_saved_vehicle(d: Dictionary) -> Vehicle:
	if not d.has("id") or not d.has("pos"):
		return null
	var a: Array = d["pos"]
	var pos := Vector3(float(a[0]), float(a[1]), float(a[2]))
	if float(d.get("hp", 1.0)) <= 0.0:
		return null                      # épave : non restaurée
	# la voiture garée générée par le secteur au même endroit est retirée (sinon doublon)
	for other in VehicleManager.vehicles:
		if is_instance_valid(other) and not other.persistent and other.driver == null and other.global_position.distance_to(pos) < 1.5:
			other.queue_free()
	var xf := Transform3D(Basis(Vector3.UP, float(d.get("yaw", 0.0))), pos)
	var v := VehicleManager.spawn(str(d["id"]), xf, WorldManager.entities)
	if v == null:
		return null
	v.apply_dict(d)
	v.persistent = true
	return v

# ------------------------------------------------------------------ interfaces appelées par d'autres scripts
func open_shop() -> void:
	# ShopPoint.interact() appelle cette méthode.
	ShopUI.open(self)

func on_back() -> void:
	# appelé par UIManager quand aucun écran ouvert ne traite le « retour » : ouvre la pause (ne quitte plus directement)
	if not _respawning:
		PauseMenu.open(self)

func quit_to_menu() -> void:
	SaveManager.autosave(player)
	GameManager.go_main_menu()
