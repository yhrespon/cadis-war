class_name PoliceController
extends EnemyController
## Policier (faction « police »). Patrouille sur les trottoirs comme un civil ; n'attaque le joueur que s'il est RECHERCHÉ
## (CrimeManager.hostile) ; attaque toujours gangs / trafiquants / méchants. Quand le joueur est recherché mais hors de vue, il
## fonce vers la dernière position connue (CrimeManager.last_known). Armement selon le niveau : 1-2 pistolet, 3-4 pistolet-mitrailleur,
## 5 fusil à pompe. Même chaîne que le joueur : GameCharacter + armes + take_damage + AnimationTree. [NON TESTÉ DANS GODOT]

var ring_center := Vector3.ZERO
var ring_half := 24.0
var ring_t := 0.0
var ring_dir := 1.0
var patrol_level := 0               # niveau de recherche à la création (choix de l'arme)
var reinforcement := false          # renfort envoyé par CrimeManager : disparaît quand la recherche est finie et le joueur loin
var _wp := Vector3.ZERO
var _pause := 0.0

func _preferred_chars() -> Array:
	return ["mx_remy", "mx_ch21"]

func _groups() -> Array:
	return ["police"]

func _palette() -> Array:
	return [Color(0.08, 0.12, 0.28)]

func _base_hp() -> float:
	return 70.0 * GameManager.enemy_hp_mult()

func _report_death(_from: Node) -> void:
	pass

func _crime_kind(killed: bool) -> String:
	return "cop_murder" if killed else "cop_assault"

func _setup_role() -> void:
	faction = "police"
	if weapon_id == "pistol":
		weapon_id = "bat" if patrol_level <= 0 and randf() < 0.3 else ("shotgun" if patrol_level >= 5 else ("smg" if patrol_level >= 3 else "pistol"))
	super._setup_role()
	corpse_time = 20.0
	ring_dir = 1.0 if randf() < 0.5 else -1.0
	_wp = CivilianController.ring_point(ring_center, ring_half, ring_t)

func _think_idle(dt: float) -> void:
	_notice(dt)
	if state != S.IDLE:
		return
	if CrimeManager.is_wanted() and CrimeManager.last_known != Vector3.INF:
		var d := _flat_dist(CrimeManager.last_known)
		if d > 9.0:
			_go(CrimeManager.last_known, sprint_v if d > 25.0 else run_v)
			return
		_stop()
		_face_dir = Vector3.FORWARD.rotated(Vector3.UP, Time.get_ticks_msec() * 0.0015)
		return
	if reinforcement:
		_stop()                         # agent de renfort : pas d'anneau de patrouille, reste sur place
		return
	if _pause > 0.0:
		_pause -= dt
		_stop()
		return
	if _flat_dist(_wp) < 1.3:
		if randf() < 0.3:
			_pause = randf_range(2.0, 6.0)
		ring_t += ring_dir * randf_range(6.0, 14.0)
		_wp = CivilianController.ring_point(ring_center, ring_half, ring_t)
	else:
		_go(_wp, walk_v)

func _on_stuck() -> void:
	ring_dir = -ring_dir
	ring_t += ring_dir * 4.0
	_wp = CivilianController.ring_point(ring_center, ring_half, ring_t)
