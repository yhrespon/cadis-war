extends Node
## État global du profil/partie : argent, personnage, ville, difficulté, modes, chargement en attente.

signal money_changed(value: int)
signal paused_changed(paused: bool)

const MODES := ["story", "secret", "test"]

var manifest: Dictionary = {}
var money := 300
var character_id := "mx_remy"
var current_city := "port_alpha"
var unlocked_cities: Array = ["port_alpha"]
var play_time := 0.0
var kills := 0
var deaths := 0
var mode := "story"
var pending_load: Dictionary = {}     # état à restaurer à l'entrée dans game.tscn
var secret_best_score := 0
var in_game := false
var paused := false
var world_hour := 10.0               # heure de jeu (0..24), pilotée par EnvironmentController
var world_weather := "clear"         # clear | cloudy | rain | storm | fog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://characters/manifest.json", FileAccess.READ)
	if f != null:
		manifest = JSON.parse_string(f.get_as_text())

func _process(delta: float) -> void:
	if in_game and not paused:
		play_time += delta

## Personnages actifs : les 4 modèles Mixamo (humains). Les 10 anciens (« legacy ») ne sont proposés que si manifest["use_legacy"] = true.
func _active_characters() -> Array:
	var use_legacy := bool(manifest.get("use_legacy", false))
	var out: Array = []
	for c in manifest["characters"]:
		if use_legacy or not bool(c.get("legacy", false)):
			out.append(c)
	if out.is_empty():
		return manifest["characters"]
	return out

func character_ids() -> Array:
	var out: Array = []
	for c in _active_characters():
		out.append(c["id"])
	return out

## Retourne l'entrée du manifest. Un identifiant ancien (sauvegarde v15 ou antérieure) ou inconnu est remplacé par un personnage actif
## du même genre (repli déterministe) : jamais d'erreur ni de personnage manquant.
func character_entry(id: String) -> Dictionary:
	var active := _active_characters()
	for c in active:
		if c["id"] == id:
			return c
	var gender := "m"
	for c in manifest["characters"]:
		if c["id"] == id:
			gender = str(c.get("gender", "m"))
	var same: Array = active.filter(func(c: Dictionary) -> bool: return str(c.get("gender", "m")) == gender)
	if same.is_empty():
		same = active
	return same[absi(hash(id)) % same.size()]

## Identifiant actif correspondant à `id` (après repli), à utiliser pour mettre à jour GameManager.character_id d'une vieille sauvegarde.
func resolve_character_id(id: String) -> String:
	return str(character_entry(id)["id"])

func add_money(n: int) -> void:
	money = maxi(0, money + n)
	money_changed.emit(money)

func spend_money(n: int) -> bool:
	if n > money:
		return false
	money -= n
	money_changed.emit(money)
	return true

## Multiplicateurs selon la difficulté (0 facile, 1 normal, 2 difficile).
func difficulty() -> int:
	return int(SettingsManager.get_value("gameplay", "difficulty"))

func enemy_damage_mult() -> float:
	return [0.6, 1.0, 1.5][difficulty()]

func enemy_hp_mult() -> float:
	return [0.8, 1.0, 1.3][difficulty()]

func reward_mult() -> float:
	return [0.8, 1.0, 1.25][difficulty()]

func new_game() -> void:
	money = 300
	current_city = "port_alpha"
	unlocked_cities = ["port_alpha"]
	play_time = 0.0
	kills = 0
	deaths = 0
	pending_load = {}
	world_hour = 10.0
	world_weather = "clear"
	CrimeManager.reset()
	InventoryManager.reset()
	MissionManager.reset()
	VehicleManager.reset()

func set_paused(p: bool) -> void:
	paused = p
	get_tree().paused = p
	paused_changed.emit(p)

## Lance la partie Histoire. data vide = nouvelle partie.
func start_story(data: Dictionary = {}) -> void:
	mode = "story"
	if data.is_empty():
		new_game()
	else:
		SaveManager.apply_profile(data)
		pending_load = data
	UIManager.change_scene("res://game.tscn")

## Mission secrète : même scène de jeu (game.tscn) en mode « secret » (site d'infiltration data/cities/secret_site.tres, SecretMission).
func start_secret_mission() -> void:
	mode = "secret"
	pending_load = {}
	UIManager.change_scene("res://game.tscn")

func start_test_level() -> void:
	mode = "test"
	pending_load = {}
	UIManager.change_scene("res://game.tscn")

## Voyage vers une ville débloquée (depuis le point de voyage). Refusé pendant une mission. Sauvegarde le profil puis recharge la scène de jeu.
func travel_to(id: String) -> bool:
	if mode != "story" or not unlocked_cities.has(id) or MissionManager.active_id != "":
		return false
	current_city = id
	pending_load = {}
	SaveManager.save_profile()
	UIManager.change_scene("res://game.tscn")
	return true

func go_main_menu() -> void:
	set_paused(false)
	in_game = false
	NPCManager.clear()
	WorldManager.unload_city()
	UIManager.change_scene("res://main_menu.tscn")

func unlock_city(id: String) -> void:
	if id != "" and not unlocked_cities.has(id):
		unlocked_cities.append(id)
