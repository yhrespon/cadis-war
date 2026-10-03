extends Node
## Sauvegarde JSON robuste : écriture dans un fichier temporaire, relecture/validation, puis remplacement (+ .bak).
## Emplacements : autosave, slot1, slot2, slot3. Contient : position, ville, zone, mission, progression, argent,
## inventaire, armes, munitions, tenue, véhicule, difficulté. Les paramètres sont dans user://settings.cfg.

const VERSION := 3
const SLOTS: Array = ["autosave", "slot1", "slot2", "slot3"]

func path_of(slot: String) -> String:
	return "user://save_%s.json" % slot

func has_save(slot: String) -> bool:
	return FileAccess.file_exists(path_of(slot))

func any_save() -> bool:
	for s in SLOTS:
		if has_save(s):
			return true
	return false

## Retourne le slot le plus récent (selon l'horodatage stocké), "" si aucun.
func latest_slot() -> String:
	var best := ""
	var best_t := -1
	for s in SLOTS:
		var d := read(s)
		if not d.is_empty() and int(d.get("timestamp", 0)) > best_t:
			best_t = int(d["timestamp"])
			best = s
	return best

func read(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(path_of(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and int(parsed.get("version", 0)) >= 1:
		return parsed
	# fichier corrompu : essayer la copie .bak
	var bak := FileAccess.open(path_of(slot) + ".bak", FileAccess.READ)
	if bak != null:
		var p2: Variant = JSON.parse_string(bak.get_as_text())
		if p2 is Dictionary:
			return p2
	return {}

## Instantané de l'état courant (le joueur peut être absent : on garde alors la partie « monde » existante).
func snapshot(player: Node = null) -> Dictionary:
	var d: Dictionary = {
		"version": VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"money": GameManager.money,
		"character_id": GameManager.character_id,
		"city": GameManager.current_city,
		"unlocked_cities": GameManager.unlocked_cities.duplicate(),
		"play_time": GameManager.play_time,
		"kills": GameManager.kills,
		"deaths": GameManager.deaths,
		"difficulty": GameManager.difficulty(),
		"secret_best_score": GameManager.secret_best_score,
		"inventory": InventoryManager.to_dict(),
		"missions": MissionManager.to_dict(),
		"has_world": false,
	}
	if player != null and is_instance_valid(player):
		var p: Player = player as Player
		d["has_world"] = true
		d["player"] = {"pos": [p.global_position.x, p.global_position.y, p.global_position.z], "yaw": p.yaw,
			"health": p.health}
		d["zone"] = WorldManager.sector_name_at(p.global_position)
		var v := VehicleManager.driven_vehicle()
		if v != null:
			d["vehicle"] = v.to_dict()
		var owned: Array = []
		for veh in VehicleManager.vehicles:
			if is_instance_valid(veh) and veh.driver == null and veh.persistent:
				owned.append(veh.to_dict())
		d["parked_vehicles"] = owned
	return d

func write(slot: String, d: Dictionary) -> bool:
	var final_path := path_of(slot)
	var tmp := final_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Sauvegarde impossible : %s" % tmp)
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	# validation : le fichier relu doit être un JSON valide avec la bonne version
	var chk := FileAccess.open(tmp, FileAccess.READ)
	var back: Variant = JSON.parse_string(chk.get_as_text())
	chk.close()
	if not (back is Dictionary) or int(back.get("version", 0)) != VERSION:
		push_error("Sauvegarde invalide après écriture")
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(final_path):
		DirAccess.copy_absolute(final_path, final_path + ".bak")
		DirAccess.remove_absolute(final_path)
	return DirAccess.rename_absolute(tmp, final_path) == OK

func save_game(slot: String, player: Node = null) -> bool:
	var d := snapshot(player)
	if not bool(d["has_world"]):
		# hors partie (ex. achat depuis le menu) : conserver la position de l'ancienne sauvegarde
		var old := read(slot)
		if str(old.get("city", "")) == GameManager.current_city:      # position/véhicules valables seulement dans la même ville
			for k in ["player", "zone", "vehicle", "parked_vehicles", "has_world"]:
				if old.has(k):
					d[k] = old[k]
	return write(slot, d)

## Sauvegarde du profil depuis le menu (argent, inventaire, tenue, personnage) sans monde.
func save_profile() -> bool:
	return save_game("autosave", null)

func autosave(player: Node) -> void:
	if GameManager.mode == "story":
		save_game("autosave", player)

func autosave_if_playing() -> void:
	if GameManager.in_game and GameManager.mode == "story":
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null:
			save_game("autosave", pl)

## Applique la partie « profil » (tout sauf la position, restaurée par la scène de jeu via pending_load).
func apply_profile(d: Dictionary) -> void:
	GameManager.money = int(d.get("money", 300))
	GameManager.character_id = str(d.get("character_id", "homme_barbu"))
	GameManager.current_city = str(d.get("city", "port_alpha"))
	GameManager.unlocked_cities = Array(d.get("unlocked_cities", ["port_alpha"]))
	GameManager.play_time = float(d.get("play_time", 0.0))
	GameManager.kills = int(d.get("kills", 0))
	GameManager.deaths = int(d.get("deaths", 0))
	GameManager.secret_best_score = int(d.get("secret_best_score", 0))
	InventoryManager.from_dict(Dictionary(d.get("inventory", {})))
	MissionManager.from_dict(Dictionary(d.get("missions", {})))
	GameManager.money_changed.emit(GameManager.money)

## Au démarrage : charge le profil de la sauvegarde la plus récente pour que menus/magasins affichent l'état réel.
func load_latest_profile() -> bool:
	var s := latest_slot()
	if s == "":
		return false
	apply_profile(read(s))
	return true

func slot_label(slot: String) -> String:
	var d := read(slot)
	if d.is_empty():
		return "Vide"
	var t := Time.get_datetime_string_from_unix_time(int(d.get("timestamp", 0)), true)
	var city := str(d.get("city", "?"))
	return "%s · %s · %d $ · %d missions" % [t, city, int(d.get("money", 0)), Array(Dictionary(d.get("missions", {})).get("completed", [])).size()]
