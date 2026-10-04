class_name GangController
extends EnemyController
## Bandit (faction « gang ») ou trafiquant (faction « dealer ») de la rue. Reste dans sa zone (home), flâne, surveille.
## NEUTRE envers le joueur tant qu'il n'est pas provoqué : provoqué = frappé / tiré dessus / coup de feu du joueur à ~22 m (50 %)
## ou joueur à pied qui reste dans la « zone » (turf_radius) plus de 3 s. Hostile en permanence à la police (et inversement).
## Quand un membre est provoqué, ses camarades à moins de 25 m le suivent (EnemyController._raise_alarm).
## Armes : gang = pistolet / PM / batte / poignard ; trafiquants = PM / fusil à pompe. [NON TESTÉ DANS GODOT]

const GANG_COLORS: Array = [Color(0.55, 0.08, 0.1), Color(0.1, 0.35, 0.18), Color(0.35, 0.12, 0.5), Color(0.8, 0.5, 0.05)]

var turf_radius := 8.0
var gang_color := Color(0.55, 0.08, 0.1)
var _turf_t := 0.0
var _wander_t := 3.0
var _wander_to := Vector3.ZERO
var _warned := false

func _preferred_chars() -> Array:
	return ["mx_brute", "mx_remy", "mx_ch21"] if faction == "dealer" else ["mx_remy", "mx_brute", "mx_ch21", "mx_eve"]

func _groups() -> Array:
	return [faction]

func _palette() -> Array:
	return [gang_color, Color(0.1, 0.1, 0.12)] if faction == "gang" else [Color(0.07, 0.07, 0.08), Color(0.2, 0.18, 0.15)]

func _base_hp() -> float:
	return (55.0 if faction == "gang" else 75.0) * GameManager.enemy_hp_mult()

func _report_death(_from: Node) -> void:
	pass

func _setup_role() -> void:
	if faction != "dealer":
		faction = "gang"
	turf_radius = 11.0 if faction == "dealer" else 8.0
	super._setup_role()
	_wander_to = home

func _think_idle(dt: float) -> void:
	_notice(dt)
	if state != S.IDLE:
		return
	_turf_check(dt)
	if state != S.IDLE:
		return
	_wander_t -= dt
	if _wander_t <= 0.0:
		_wander_t = randf_range(3.0, 8.0)
		if randf() < 0.5:
			_wander_to = home + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
		else:
			_wander_to = global_position
			_idle_face = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	if _flat_dist(_wander_to) > 0.6:
		_go(_wander_to, walk_v * 0.8)
	else:
		_stop()
		_face_dir = _idle_face

func _turf_check(dt: float) -> void:
	var p := _player()
	if p == null or p.dead or provoked or p.driving != null:
		_turf_t = 0.0
		_warned = false
		return
	if _flat_dist(p.global_position) > turf_radius or not _los(p):
		_turf_t = maxf(0.0, _turf_t - dt)
		if _turf_t <= 0.0:
			_warned = false
		return
	_turf_t += dt
	if not _warned and _turf_t > 0.8:
		_warned = true
		VoiceManager.say(self, "gang_warn")
	if _turf_t > 3.0:
		provoked = true
		_raise_alarm(p)
