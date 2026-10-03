extends Node
## État global du profil/partie : argent, personnage, ville, difficulté, modes, chargement en attente.

signal money_changed(value: int)
signal paused_changed(paused: bool)

const MODES := ["story", "secret", "test"]

var manifest: Dictionary = {}
var money := 300
var character_id := "homme_barbu"
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://characters/manifest.json", FileAccess.READ)
	if f != null:
		manifest = JSON.parse_string(f.get_as_text())

func _process(delta: float) -> void:
	if in_game and not paused:
		play_time += delta

func character_ids() -> Array:
	var out: Array = []
	for c in manifest["characters"]:
		out.append(c["id"])
	return out

func character_entry(id: String) -> Dictionary:
	for c in manifest["characters"]:
		if c["id"] == id:
			return c
	return manifest["characters"][0]

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
