extends Node
## Système « GTA » (v17) : factions, niveau de recherche (0 à 5 étoiles), témoins, envoi de la police.
##
## Factions (NPCActor.faction) : « civil », « police », « gang » (bandits), « dealer » (trafiquants), « boss » (méchants de mission),
## « player ». Les PNJ et le joueur partagent la même chaîne : GameCharacter + armes + take_damage() + véhicules.
##
## Règles de crime (report_crime) : un crime n'a d'effet que s'il est VU : par un policier à portée et en ligne de vue, ou par un
## civil témoin (qui « appelle la police » après un délai). Chaque crime ajoute de la « chaleur » ; les étoiles découlent de la chaleur.
## La chaleur retombe quand aucun policier ne voit le joueur (cooldown plus long si recherché).
##
## Hostilité (hostile) : police <-> gang/dealer ; boss (méchants de mission) -> joueur seulement ;
## gang/dealer -> joueur : hostiles si le joueur les a agressés ou entre dans leur zone (« turf ») ; police -> joueur si recherché.
## [NON TESTÉ DANS GODOT]

signal wanted_changed(level: int)
signal busted()
signal crime_reported(kind: String)

const HEAT_PER_STAR := 25.0
const MAX_HEAT := 125.0
const SEE_RANGE := 42.0
const POLICE_COOLDOWN := 18.0         # secondes sans être vu avant que la chaleur ne retombe
const CRIMES := {
	"gunfire": 10.0,        # coup de feu en public
	"assault": 18.0,        # agression d'un civil
	"murder": 40.0,         # meurtre d'un civil
	"cop_assault": 45.0,    # agression d'un policier
	"cop_murder": 75.0,     # meurtre d'un policier
	"carjack": 22.0,        # vol de voiture avec conducteur
	"hit_and_run": 28.0,    # civil renversé
	"vehicle_theft": 5.0,   # voiture garée prise devant témoin
	"explosion": 30.0,
}

var heat := 0.0
var _level := 0
var _unseen_t := 0.0
var _dispatch_t := 4.0
var _calls: Array = []                 # {t: float, pos: Vector3, kind: String} appels de civils en attente
var last_known := Vector3.INF          # dernière position connue du joueur par la police
var _last_crime: Dictionary = {}       # kind -> instant (s) du dernier signalement (anti-répétition)
const COOLDOWNS := {"gunfire": 6.0, "assault": 2.0, "hit_and_run": 2.5, "vehicle_theft": 10.0, "cop_assault": 2.0}

func reset() -> void:
	_last_crime.clear()
	heat = 0.0
	_level = 0
	_unseen_t = 0.0
	_calls.clear()
	last_known = Vector3.INF
	wanted_changed.emit(0)

func wanted_level() -> int:
	return _level

func is_wanted() -> bool:
	return _level > 0

# ---------------------------------------------------------------- hostilité entre factions
## true si `a` (faction) attaque `b` (faction). `provoked` : a déjà été attaqué par b ou b est armé et menaçant.
func hostile(a: String, b: String, provoked := false) -> bool:
	if a == b:
		return false
	match a:
		"police":
			if b == "player":
				return _level > 0
			return b == "gang" or b == "dealer"     # les méchants de mission (« boss ») ignorent la police : pas d'interférence avec les missions
		"gang", "dealer":
			if b == "police":
				return true
			return b == "player" and provoked
		"boss":
			return b == "player"
		"civil":
			return false
	return false

# ---------------------------------------------------------------- signalement de crimes
## Appelé par NPCActor.take_damage / Vehicle / PlayerCombat. `pos` : lieu du crime ; `perp` : auteur (Player ou PNJ).
func report_crime(kind: String, pos: Vector3, perp: Node) -> void:
	if not CRIMES.has(kind):
		return
	if not (perp is Player):
		return                                   # seul le joueur est recherché ; les PNJ se règlent entre eux par la provocation
	var now := Time.get_ticks_msec() / 1000.0
	if COOLDOWNS.has(kind) and now - float(_last_crime.get(kind, -999.0)) < float(COOLDOWNS[kind]):
		return
	_last_crime[kind] = now
	var seen_by_cop := _cop_sees(pos)
	var witnessed := seen_by_cop or _civil_witness(pos)
	if not witnessed:
		return
	if seen_by_cop:
		_add_heat(float(CRIMES[kind]), pos)
		crime_reported.emit(kind)
	else:
		# un civil appelle la police : l'effet est différé (il faut qu'il survive et ne soit pas en fuite totale)
		_calls.append({"t": randf_range(2.5, 5.0), "pos": pos, "kind": kind})

func _cop_sees(pos: Vector3) -> bool:
	for c in get_tree().get_nodes_in_group("police"):
		var c3 := c as Node3D
		if c3 == null or bool(c3.get("dead")):
			continue
		if c3.global_position.distance_to(pos) <= SEE_RANGE * visibility():
			return true
	return false

func _civil_witness(pos: Vector3) -> bool:
	for c in get_tree().get_nodes_in_group("civilian"):
		var c3 := c as Node3D
		if c3 == null or bool(c3.get("dead")):
			continue
		if c3.global_position.distance_to(pos) <= 26.0 * visibility() and _clear_line(c3.global_position + Vector3(0, 1.5, 0), pos + Vector3(0, 1.2, 0), c3):
			return true
	return false

func _clear_line(a: Vector3, b: Vector3, ex: Node3D) -> bool:
	var space := ex.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, [ex.get_rid()])
	return space.intersect_ray(q).is_empty()

func visibility() -> float:
	var env := get_tree().get_first_node_in_group("environment")
	if env != null and env.has_method("visibility_mult"):
		return float(env.call("visibility_mult"))
	return 1.0

func _add_heat(amount: float, pos: Vector3) -> void:
	heat = minf(MAX_HEAT, heat + amount)
	last_known = pos
	_unseen_t = 0.0
	_refresh_level()

func _refresh_level() -> void:
	var lv := 0 if heat < 9.0 else clampi(int(heat / HEAT_PER_STAR) + 1, 1, 5)
	if lv != _level:
		var up := lv > _level
		_level = lv
		wanted_changed.emit(_level)
		if up and _level > 0:
			AudioManager.play_sfx("police_whistle", "SFX")
			UIManager.toast("RECHERCHÉ  niveau %d / 5" % _level, Color(1.0, 0.45, 0.4), 2.0)
		elif _level == 0:
			UIManager.toast("Recherche terminée", Color(0.6, 1.0, 0.7), 2.0)

## Efface la recherche (hôpital, planque...).
func clear_wanted() -> void:
	heat = 0.0
	_refresh_level()
	for c in get_tree().get_nodes_in_group("police"):
		if c.has_method("stand_down"):
			c.call("stand_down")

## Le joueur a été arrêté / est mort : amende, fin de la recherche.
func bust_player() -> int:
	var fine := mini(GameManager.money, 60 * maxi(_level, 1))
	if fine > 0:
		GameManager.spend_money(fine)
	clear_wanted()
	busted.emit()
	return fine

# ---------------------------------------------------------------- boucle
func _physics_process(delta: float) -> void:
	if not GameManager.in_game or get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	# appels de témoins
	for c in _calls:
		c["t"] = float(c["t"]) - delta
	var due: Array = _calls.filter(func(c: Dictionary) -> bool: return float(c["t"]) <= 0.0)
	_calls = _calls.filter(func(c: Dictionary) -> bool: return float(c["t"]) > 0.0)
	for c in due:
		_add_heat(float(CRIMES[str(c["kind"])]) * 0.8, Vector3(c["pos"]))
		crime_reported.emit(str(c["kind"]))
	if _level <= 0:
		if heat > 0.0:
			heat = maxf(0.0, heat - delta * 1.5)
		return
	# la police voit-elle le joueur ?
	var seen := false
	for c in get_tree().get_nodes_in_group("police"):
		var c3 := c as Node3D
		if c3 != null and not bool(c3.get("dead")) and c3.global_position.distance_to(player.global_position) < SEE_RANGE * visibility() and bool(c3.call("sees_target", player)):
			seen = true
			break
	if seen:
		_unseen_t = 0.0
		last_known = player.global_position
	else:
		_unseen_t += delta
		if _unseen_t > POLICE_COOLDOWN:
			heat = maxf(0.0, heat - delta * (3.0 + float(5 - _level)))
			_refresh_level()
	# envoi de renforts
	_dispatch_t -= delta
	if _dispatch_t <= 0.0:
		_dispatch_t = 5.0 if _level >= 3 else 7.5
		_dispatch(player)

func _dispatch(player: Player) -> void:
	var spawner := MissionManager.spawner
	if spawner == null or not spawner.has_method("spawn_police"):
		return
	var want_foot := 1 + _level * 2                 # 3, 5, 7, 9, 11 agents à pied au maximum
	var want_cars := 0 if _level < 2 else (_level - 1)   # 1..4 voitures de patrouille
	var have_foot := NPCManager.count_of("police")
	if have_foot < want_foot:
		spawner.call("spawn_police", mini(2, want_foot - have_foot), player.global_position, _level)
	if want_cars > 0 and get_tree().get_nodes_in_group("police_car").size() < want_cars:
		spawner.call("spawn_police_car", player.global_position, _level)
