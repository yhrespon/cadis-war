extends Node
## Missions : disponibilité, acceptation, objectifs, chronomètre, échec, récompense, déblocage de ville, sauvegarde.
## v13 : script chargé sous Godot 4.3 ; comportement gameplay non testé.
##
## Structure d'une mission (MissionDef.objectives) : liste d'ÉTAPES jouées dans l'ordre.
## Une étape = un Dictionary (un objectif) OU un Array de Dictionary (objectifs en parallèle, tous requis).
##
## Types gérés directement ici (aucun PNJ requis) : goto, collect, interact (marqueur temporaire), vehicle_goto, survive (minuteur).
## Types qui ont besoin d'un PNJ armé/allié : kill, chase, escort, protect, stealth_goto, vagues de survive.
## Ils passent par `spawner` (node posé par game.gd) qui doit fournir :
##   spawn_enemies(count: int, pos: Vector3, weapon: String, tag: String, opts: Dictionary) -> Array
##   spawn_friendly(npc_name: String, pos: Vector3) -> Node
## et l'EnemyController appelle MissionManager.report_kill(tag) à sa mort (et report_alert() en infiltration).
## Sans spawner, ces objectifs sont marqués BLOQUÉS (toast + erreur console) : pas de faux succès.

signal mission_started(id: String)
signal objective_changed(text: String)
signal mission_completed(id: String)
signal mission_failed(id: String, reason: String)
signal alert_raised()                  # un garde d'infiltration a repéré le joueur (Mission secrète : score)

const DEF_PATH := "res://data/missions/%s.tres"
const REGISTRY := "res://data/registry.json"

var defs: Dictionary = {}              # id -> MissionDef
var completed: Array = []              # ids terminés
var active_id := ""
var step := 0                          # étape courante dans def.objectives
var time_left := 0.0                   # 0 = pas de limite
var spawner: Node = null               # posé par game.gd

var _states: Array = []                # objectifs de l'étape courante (runtime)
var _spawned: Array = []               # noeuds créés pour la mission (nettoyés à la fin)
var _resume_progress: Array = []       # progression partielle de l'étape, lue dans la sauvegarde (consommée par _begin_step)
var _resume_timers: Array = []

func _ready() -> void:
	var f := FileAccess.open(REGISTRY, FileAccess.READ)
	if f == null:
		push_error("registry.json introuvable")
		return
	var reg: Dictionary = JSON.parse_string(f.get_as_text())
	for id in reg.get("missions", []):
		var d := load(DEF_PATH % str(id)) as MissionDef
		if d != null:
			defs[str(id)] = d
		else:
			push_error("Mission illisible : %s" % str(id))

# ------------------------------------------------------------------ état / sauvegarde
func reset() -> void:
	_cleanup()
	completed = []
	active_id = ""
	step = 0
	time_left = 0.0
	_states = []

func to_dict() -> Dictionary:
	var prog: Array = []
	var tim: Array = []
	for st in _states:
		prog.append(int(st["progress"]))
		tim.append(float(st["timer"]))
	var a := active_id
	if a != "" and defs.has(a) and (defs[a] as MissionDef).category == "secret":
		a = ""                          # une Mission secrète en cours n'est jamais sauvegardée
	return {"completed": completed.duplicate(), "active": a, "step": step, "time_left": time_left, "progress": prog, "timers": tim}

func from_dict(d: Dictionary) -> void:
	_cleanup()
	completed = Array(d.get("completed", []))
	active_id = str(d.get("active", ""))
	step = int(d.get("step", 0))
	time_left = float(d.get("time_left", 0.0))
	_states = []
	_resume_progress = Array(d.get("progress", []))
	_resume_timers = Array(d.get("timers", []))
	if not defs.has(active_id):
		active_id = ""
		_resume_progress = []
		_resume_timers = []

## À appeler par game.gd une fois la ville chargée : reconstruit l'étape en cours (la progression PARTIELLE d'une étape n'est pas sauvegardée).
func resume_after_load() -> void:
	if active_id == "":
		return
	var def: MissionDef = defs[active_id]
	if def.city != GameManager.current_city:
		active_id = ""
		_resume_progress = []
		_resume_timers = []
		return
	_begin_step(step)

# ------------------------------------------------------------------ disponibilité
func is_completed(id: String) -> bool:
	return completed.has(id)

func is_available(id: String) -> bool:
	if not defs.has(id) or id == active_id:
		return false
	var def: MissionDef = defs[id]
	if def.category == "secret":
		return false
	if completed.has(id) and def.category != "contract":      # seuls les contrats sont répétables
		return false
	if def.city != GameManager.current_city or not GameManager.unlocked_cities.has(def.city):
		return false
	for r in def.requires:
		if not completed.has(str(r)):
			return false
	return true

func available_missions() -> Array:
	var out: Array = []
	for id in defs:
		if is_available(str(id)):
			out.append(defs[id])
	return out

func def_of(id: String) -> MissionDef:
	return defs.get(id) as MissionDef

# ------------------------------------------------------------------ cycle de vie
## Lance une mission construite à l'exécution (Mission secrète). Ne passe pas par la disponibilité, n'est jamais sauvegardée,
## ne va pas dans `completed` et ne verse aucune récompense (le score est géré par SecretMission).
func start_custom(def: MissionDef) -> bool:
	if active_id != "":
		return false
	defs[def.id] = def
	active_id = def.id
	step = 0
	time_left = def.time_limit
	_resume_progress = []
	_resume_timers = []
	mission_started.emit(def.id)
	_begin_step(0)
	return true

## Abandon silencieux d'une mission personnalisée (quitter la Mission secrète) : pas de toast, pas de signal d'échec.
func drop_custom() -> void:
	if active_id != "" and defs.has(active_id) and (defs[active_id] as MissionDef).category == "secret":
		var id := active_id
		_cleanup()
		active_id = ""
		time_left = 0.0
		_forget_custom(id)

func _forget_custom(id: String) -> void:
	if defs.has(id) and (defs[id] as MissionDef).category == "secret":
		defs.erase(id)

func accept(id: String) -> bool:
	if active_id != "" or not is_available(id):
		return false
	var def: MissionDef = defs[id]
	active_id = id
	step = 0
	time_left = def.time_limit
	_resume_progress = []
	_resume_timers = []
	UIManager.toast("Mission : " + def.title, Color(1, 0.85, 0.3), 3.5)
	mission_started.emit(id)
	_begin_step(0)
	return true

func abandon() -> void:
	if active_id != "":
		_fail("Mission abandonnée")

func _complete() -> void:
	var def: MissionDef = defs[active_id]
	var id := active_id
	_cleanup()
	active_id = ""
	if def.category == "secret":
		time_left = maxf(time_left, 0.0)
		mission_completed.emit(id)
		_forget_custom(id)
		return
	if not completed.has(id):
		completed.append(id)
	var money := int(round(float(def.reward_money) * GameManager.reward_mult()))
	GameManager.add_money(money)
	if def.reward_item != "":
		InventoryManager.grant_item(def.reward_item)
	if def.unlocks_city != "":
		GameManager.unlock_city(def.unlocks_city)
		UIManager.toast("Nouvelle ville débloquée !", Color(0.5, 1, 0.6), 4.0)
	UIManager.toast("Mission réussie : +%d $" % money, Color(0.5, 1, 0.6), 4.0)
	mission_completed.emit(id)
	SaveManager.autosave_if_playing()

func _fail(reason: String) -> void:
	var id := active_id
	_cleanup()
	active_id = ""
	time_left = 0.0
	UIManager.toast("Mission échouée : " + reason, Color(1, 0.4, 0.4), 4.0)
	mission_failed.emit(id, reason)
	_forget_custom(id)

func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned = []
	_states = []

# ------------------------------------------------------------------ étapes
func _begin_step(i: int) -> void:
	var def: MissionDef = defs[active_id]
	if i >= def.objectives.size():
		_complete()
		return
	step = i
	_states = []
	var raw: Variant = def.objectives[i]
	var specs: Array = raw if raw is Array else [raw]
	var k := 0
	for s in specs:
		var st := _make_state(Dictionary(s))
		if k < _resume_progress.size() and _resume_progress.size() == specs.size():
			st["progress"] = int(_resume_progress[k])           # reprise après chargement
			if k < _resume_timers.size() and float(_resume_timers[k]) > 0.0:
				st["resume_timer"] = float(_resume_timers[k])
		_states.append(st)
		k += 1
	_resume_progress = []
	_resume_timers = []
	for st in _states:
		_start_objective(st)
	objective_changed.emit(objective_text())

func _make_state(spec: Dictionary) -> Dictionary:
	var pos := Vector3.ZERO
	if spec.has("poi"):
		pos = WorldManager.poi_position(str(spec["poi"]))
	return {"spec": spec, "done": false, "blocked": false, "progress": 0, "target": 1, "pos": pos,
		"timer": 0.0, "waves_done": 0, "npc": null, "vehicle": null, "talk_line": 0}

func _start_objective(st: Dictionary) -> void:
	var spec: Dictionary = st["spec"]
	var t := str(spec.get("type", ""))
	var pos: Vector3 = st["pos"]
	match t:
		"goto":
			pass
		"kill", "chase":
			st["target"] = int(spec.get("count", 1))
			if int(st["progress"]) >= int(st["target"]):
				st["done"] = true
				return
			var opts: Dictionary = {}
			if t == "chase":
				opts = {"flee_to": WorldManager.poi_position(str(spec.get("flee_to", "")))}
			if not _spawn_enemies(st, int(st["target"]) - int(st["progress"]), pos, str(spec.get("weapon", "pistol")), str(spec.get("tag", "")), opts):
				pass
		"collect":
			_start_collect(st)
		"interact":
			_spawn_marker(pos, "talk", str(spec.get("npc", "")), st)
		"vehicle_goto":
			_start_vehicle_goto(st)
		"survive":
			st["timer"] = float(spec.get("seconds", 30.0))
			_apply_resume_timer(st)
			_spawn_wave(st)
		"protect":
			st["timer"] = float(spec.get("seconds", 30.0))
			_apply_resume_timer(st)
			st["npc"] = _spawn_friendly(st, str(spec.get("npc", "")), pos)
			_spawn_wave(st)
		"escort":
			var from := WorldManager.poi_position(str(spec.get("from_poi", "")))
			st["npc"] = _spawn_friendly(st, str(spec.get("npc", "")), from)
		"stealth_goto":
			var guards := int(spec.get("guards", 2))
			_spawn_enemies(st, guards, pos, "pistol", "stealth_guard", {"stealth": true})
		_:
			push_error("Type d'objectif inconnu : %s" % t)
			st["blocked"] = true

## Reprise : rétablit le temps restant et évite de rejouer en rafale les vagues déjà écoulées.
func _apply_resume_timer(st: Dictionary) -> void:
	if not st.has("resume_timer"):
		return
	var total: float = float(st["spec"].get("seconds", 30.0))
	var waves: int = maxi(1, int(st["spec"].get("waves", 2)))
	st["timer"] = clampf(float(st["resume_timer"]), 1.0, total)
	var elapsed: float = total - float(st["timer"])
	st["waves_done"] = clampi(int(ceil(elapsed / total * float(waves))), 0, waves - 1)      # _spawn_wave ajoute 1

func _block(st: Dictionary, why: String) -> void:
	st["blocked"] = true
	push_error("Objectif BLOQUÉ (%s) : %s" % [str(st["spec"].get("type", "?")), why])
	UIManager.toast("Objectif indisponible : " + why, Color(1, 0.6, 0.2), 4.0)

func _spawn_enemies(st: Dictionary, count: int, pos: Vector3, weapon: String, tag: String, opts: Dictionary) -> bool:
	if spawner == null or not spawner.has_method("spawn_enemies"):
		_block(st, "EnemyController / spawner absent")
		return false
	var made: Array = spawner.spawn_enemies(count, pos, weapon, tag, opts)
	_spawned.append_array(made)
	return true

func _spawn_friendly(st: Dictionary, npc_name: String, pos: Vector3) -> Node:
	if spawner == null or not spawner.has_method("spawn_friendly"):
		_block(st, "PNJ allié absent")
		return null
	var n: Node = spawner.spawn_friendly(npc_name, pos)
	if n != null:
		_spawned.append(n)
	return n

func _spawn_wave(st: Dictionary) -> void:
	var spec: Dictionary = st["spec"]
	var per: int = int(spec.get("per_wave", 2))
	var opts: Dictionary = {"chase": bool(spec.get("chase", false))}
	if _spawn_enemies(st, per, st["pos"], str(spec.get("weapon", "pistol")), "wave", opts):
		st["waves_done"] = int(st["waves_done"]) + 1

func _start_collect(st: Dictionary) -> void:
	var spec: Dictionary = st["spec"]
	var name_txt := str(spec.get("item_name", "Objet"))
	if spec.has("pois"):
		var list: Array = spec["pois"]
		st["target"] = list.size()
		var skip := int(st["progress"])                      # l'ordre de ramassage n'est pas sauvegardé : on retire les premiers de la liste
		for p in list:
			if skip > 0:
				skip -= 1
				continue
			_spawn_marker(WorldManager.poi_position(str(p)), "collect", name_txt, st)
	else:
		var n := int(spec.get("items", 1))
		var spread: float = float(spec.get("spread", 5.0))
		st["target"] = n
		if int(st["progress"]) >= n:
			st["done"] = true
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(active_id + name_txt)
		for k in n:
			var off := Vector3(rng.randf_range(-spread, spread), 0.0, rng.randf_range(-spread, spread))
			if k < int(st["progress"]):
				continue                                    # déjà ramassé avant la sauvegarde
			_spawn_marker(st["pos"] + off, "collect", name_txt, st)

func _start_vehicle_goto(st: Dictionary) -> void:
	var spec: Dictionary = st["spec"]
	if WorldManager.entities == null:
		_block(st, "monde non chargé")
		return
	var car_pos := WorldManager.poi_position(str(spec.get("car_poi", "")))
	var v := VehicleManager.spawn(str(spec.get("vehicle", "sedan")), Transform3D(Basis.IDENTITY, car_pos + Vector3(0, 0.5, 0)), WorldManager.entities)
	if v == null:
		_block(st, "véhicule introuvable")
		return
	v.persistent = false
	st["vehicle"] = v
	_spawned.append(v)

func _spawn_marker(pos: Vector3, kind: String, label: String, st: Dictionary) -> void:
	if WorldManager.entities == null:
		_block(st, "monde non chargé")
		return
	var m := MissionItem.new()
	m.kind = kind
	m.label = label
	m.state = st
	WorldManager.entities.add_child(m)
	m.global_position = pos
	_spawned.append(m)

# ------------------------------------------------------------------ rapports (appelés par le gameplay)
func report_kill(tag: String) -> void:
	for st in _states:
		var t := str(st["spec"].get("type", ""))
		if (t == "kill" or t == "chase") and not st["done"] and str(st["spec"].get("tag", "")) == tag:
			st["progress"] = int(st["progress"]) + 1
			if int(st["progress"]) >= int(st["target"]):
				st["done"] = true
	_check_step()

## Appelé par MissionItem.interact().
func report_item(st: Dictionary) -> void:
	if st["done"]:
		return
	if str(st["spec"].get("type", "")) == "interact":
		var lines: Array = st["spec"].get("lines", [])
		var i: int = int(st["talk_line"])
		if i < lines.size():
			UIManager.toast("%s : %s" % [str(st["spec"].get("npc", "")), str(lines[i])], Color.WHITE, 3.5)
			st["talk_line"] = i + 1
		if int(st["talk_line"]) >= lines.size():
			st["done"] = true
	else:
		st["progress"] = int(st["progress"]) + 1
		if int(st["progress"]) >= int(st["target"]):
			st["done"] = true
	_check_step()

func report_alert() -> void:
	alert_raised.emit()
	for st in _states:
		if str(st["spec"].get("type", "")) == "stealth_goto" and not st["done"]:
			_fail("Vous avez été repéré")
			return

# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if active_id == "":
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	if player.dead:
		if (defs[active_id] as MissionDef).fail_on_death:
			_fail("Vous êtes mort")
		return
	if time_left > 0.0:
		time_left -= delta
		if time_left <= 0.0:
			_fail("Temps écoulé")
			return
	for st in _states:
		if not st["done"] and not st["blocked"]:
			_update_state(st, player, delta)
		if active_id == "":
			return
	_check_step()

func _update_state(st: Dictionary, player: Player, delta: float) -> void:
	var spec: Dictionary = st["spec"]
	var radius: float = float(spec.get("radius", 4.0))
	match str(spec.get("type", "")):
		"goto", "stealth_goto":
			if _flat_dist(player.global_position, st["pos"]) <= radius:
				st["done"] = true
		"vehicle_goto":
			var v: Variant = st["vehicle"]
			if not is_instance_valid(v) or (v as Vehicle).destroyed:
				_fail("Le véhicule a été détruit")
				return
			if VehicleManager.driven_vehicle() == v and _flat_dist((v as Node3D).global_position, st["pos"]) <= radius:
				st["done"] = true
		"survive", "protect":
			st["timer"] = float(st["timer"]) - delta
			if str(spec.get("type", "")) == "protect" and not is_instance_valid(st["npc"]):
				_fail("Le témoin est mort")
				return
			var waves: int = int(spec.get("waves", 2))
			var total: float = float(spec.get("seconds", 30.0))
			var elapsed: float = total - float(st["timer"])
			if int(st["waves_done"]) < waves and elapsed >= total * float(st["waves_done"]) / float(waves):
				_spawn_wave(st)
			if float(st["timer"]) <= 0.0:
				st["done"] = true
		"escort":
			var npc: Variant = st["npc"]
			if not is_instance_valid(npc):
				_fail("L'informateur est mort")
				return
			if _flat_dist((npc as Node3D).global_position, st["pos"]) <= radius:
				st["done"] = true

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _check_step() -> void:
	if active_id == "" or _states.is_empty():
		return
	for st in _states:
		if not st["done"]:
			return
	var next := step + 1
	for n in _spawned:
		if is_instance_valid(n) and n is MissionItem:
			n.queue_free()
	_begin_step(next)

# ------------------------------------------------------------------ données pour le HUD
func objective_text() -> String:
	var parts: Array = []
	for st in _states:
		if st["done"]:
			continue
		var s := str(st["spec"].get("text", ""))
		if int(st["target"]) > 1:
			s += " (%d/%d)" % [int(st["progress"]), int(st["target"])]
		if float(st["timer"]) > 0.0 and not st["blocked"]:
			s += " — %d s" % int(ceil(float(st["timer"])))
		if st["blocked"]:
			s += " [BLOQUÉ]"
		parts.append(s)
	return " · ".join(parts)

## Position du premier objectif non terminé (pour la flèche / minimap) ; Vector3.INF si aucun.
func objective_position() -> Vector3:
	for st in _states:
		if not st["done"]:
			return st["pos"]
	return Vector3.INF
