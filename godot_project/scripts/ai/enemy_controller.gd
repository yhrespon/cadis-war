class_name EnemyController
extends NPCActor
## Ennemi : IDLE / PATROL / ALERT / COMBAT / SEARCH / FLEE. Vue (portée, cône, ligne de vue), ouïe (NPCManager.emit_noise),
## tir hitscan avec précision dégressive, rechargement, mêlée (batte), mode infiltration (stealth), poursuite (chase), fuite (chase objective).
## Appelle MissionManager.report_kill(tag) à sa mort et MissionManager.report_alert() quand un garde d'infiltration repère le joueur.
## v13 : script chargé sous Godot 4.3 ; comportement gameplay non testé. Valeurs d'équilibrage (DMG_SCALE, précision, portées) à régler en jeu.

enum S { IDLE, PATROL, ALERT, COMBAT, SEARCH, FLEE }

const DMG_SCALE := 0.45          # fraction des dégâts d'arme appliquée au joueur (équilibrage)
const OUTFIT_PALETTE: Array = [Color(0.12, 0.12, 0.14), Color(0.3, 0.1, 0.1), Color(0.14, 0.2, 0.3), Color(0.25, 0.25, 0.22), Color(0.4, 0.38, 0.3)]

var weapon_id := "pistol"
var tag := ""
var stealth := false
var chase := false              # connaît toujours la position du joueur (vagues « chase », poursuite)
var flee_to := Vector3.INF      # objectif « chase » : fuit vers ce point puis se bat

var state: int = S.IDLE
var def: WeaponDef = null
var weapon: Weapon = null
var home := Vector3.ZERO
var target: Node3D = null
var last_known := Vector3.ZERO
var reload_left := 0.0

var _mag := 10
var _cooldown := 0.0
var _state_t := 0.0
var _lost_t := 0.0
var _spot := 0.0
var _alarm_sent := false
var _strafe := 1.0
var _strafe_t := 2.0
var _alert_pos := Vector3.ZERO
var _patrol: Array = []
var _patrol_i := 0
var _idle_turn_t := 3.0
var _idle_face := Vector3(0, 0, 1)
var _melee_busy := false

func _allowed_ages() -> Array:
	return ["adulte", "ado"]

func _setup_role() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8 | 16
	max_hp = 60.0 * GameManager.enemy_hp_mult()
	def = WeaponManager.get_def(weapon_id)
	if def == null:
		def = WeaponManager.get_def("pistol")
	if def != null and gc != null and gc.model != null:
		weapon = Weapon.make(def)
		weapon.apply_grip(gc.manifest_entry)
		gc.attach_to_bone(weapon, "RightHand")
		_mag = def.mag_size
	randomize_outfit(OUTFIT_PALETTE)
	home = global_position
	_idle_face = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	if flee_to != Vector3.INF:
		_set_state(S.FLEE)
	elif chase:
		target = _player()
		_set_state(S.COMBAT)
	elif stealth:
		for k in 3:
			var a := TAU * float(k) / 3.0 + randf() * 0.5
			_patrol.append(home + Vector3(cos(a), 0, sin(a)) * randf_range(5.0, 8.0))
		_set_state(S.PATROL)

func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

# ---------------------------------------------------------------- perception
func _sight_range() -> float:
	return 16.0 if stealth else 38.0

func _fov_deg() -> float:
	return 70.0 if stealth else 130.0

func _targets() -> Array:
	var out: Array = []
	var p := _player()
	if p != null and not p.dead:
		out.append(p)
	for f in get_tree().get_nodes_in_group("friendly"):
		if f is Node3D and not bool(f.get("dead")):
			out.append(f)
	return out

func _in_fov(p: Vector3) -> bool:
	var fwd := Vector3(sin(gc.rotation.y), 0, cos(gc.rotation.y)) if gc != null else Vector3(0, 0, 1)
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return true
	return fwd.angle_to(to.normalized()) <= deg_to_rad(_fov_deg() * 0.5)

func _los(t: Node3D) -> bool:
	var from := global_position + Vector3(0, height * 0.88, 0)
	var th := float(t.get("height")) if t.get("height") != null else 1.75
	var to := t.global_position + Vector3(0, th * 0.7, 0)
	var excl: Array[RID] = [get_rid()]
	if t is Player and (t as Player).driving != null:
		excl.append((t as Player).driving.get_rid())
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 16, excl)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _visible_target() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for t in _targets():
		var t3 := t as Node3D
		var d := _flat_dist(t3.global_position)
		if d > _sight_range():
			continue
		if d > 5.0 and not _in_fov(t3.global_position):
			continue
		if not _los(t3):
			continue
		if d < best_d:
			best_d = d
			best = t3
	return best

# ---------------------------------------------------------------- IA
func _think(dt: float) -> void:
	_cooldown = maxf(0.0, _cooldown - dt)
	_state_t += dt
	if reload_left > 0.0:
		reload_left -= dt
		if reload_left <= 0.0 and def != null:
			_mag = def.mag_size
	_face_dir = Vector3.ZERO
	match state:
		S.IDLE:
			_think_idle(dt)
		S.PATROL:
			_think_patrol(dt)
		S.ALERT:
			_think_alert(dt)
		S.SEARCH:
			_think_search(dt)
		S.COMBAT:
			_think_combat(dt)
		S.FLEE:
			_think_flee(dt)

func _notice(dt: float) -> void:
	var seen := _visible_target()
	if seen == null:
		_spot = maxf(0.0, _spot - dt * 0.5)
		return
	var need := 0.5 if _flat_dist(seen.global_position) < 8.0 else 1.1
	if not stealth:
		need = 0.25
	_spot += dt
	if _spot >= need:
		_raise_alarm(seen)

func _raise_alarm(t: Node3D) -> void:
	if stealth and not _alarm_sent:
		_alarm_sent = true
		MissionManager.report_alert()
	_enter_combat(t)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e is EnemyController and (e as EnemyController).state != S.COMBAT and (e as Node3D).global_position.distance_to(global_position) < 25.0:
			(e as EnemyController).alert_to(t)

## Appelé par un allié qui a repéré une cible.
func alert_to(t: Node3D) -> void:
	if dead or state == S.COMBAT or state == S.FLEE:
		return
	_enter_combat(t)

func _enter_combat(t: Node3D) -> void:
	target = t
	if t != null:
		last_known = t.global_position
	_lost_t = 0.0
	_set_state(S.COMBAT)

func _think_idle(dt: float) -> void:
	_stop()
	_idle_turn_t -= dt
	if _idle_turn_t <= 0.0:
		_idle_turn_t = randf_range(3.0, 7.0)
		_idle_face = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_face_dir = _idle_face
	_notice(dt)

func _think_patrol(dt: float) -> void:
	_notice(dt)
	if state != S.PATROL or _patrol.is_empty():
		return
	var wp: Vector3 = _patrol[_patrol_i]
	if _flat_dist(wp) < 1.2:
		_patrol_i = (_patrol_i + 1) % _patrol.size()
		wp = _patrol[_patrol_i]
	_go(wp, walk_v * 0.9)

func _think_alert(dt: float) -> void:
	_notice(dt)
	if state != S.ALERT:
		return
	if _flat_dist(_alert_pos) < 1.5 or _state_t > 9.0:
		_set_state(S.SEARCH)
		return
	_go(_alert_pos, walk_v * 1.3)

func _think_search(dt: float) -> void:
	_notice(dt)
	if state != S.SEARCH:
		return
	_stop()
	_face_dir = Vector3.FORWARD.rotated(Vector3.UP, _state_t * 1.2)
	if _state_t > 5.0:
		_set_state(S.PATROL if (stealth and not _patrol.is_empty()) else S.IDLE)

func _think_flee(_dt: float) -> void:
	if _flat_dist(flee_to) < 3.0 or _state_t > 30.0:
		_enter_combat(_player())
		return
	_go(flee_to, sprint_v)

func _think_combat(dt: float) -> void:
	if target == null or not is_instance_valid(target) or bool(target.get("dead")):
		target = _visible_target()
		if target == null:
			var p := _player()
			if p != null and not p.dead and (chase or _lost_t < 4.0):
				target = p
			else:
				_set_state(S.SEARCH)
				return
	var see := _los(target)
	if see:
		last_known = target.global_position
		_lost_t = 0.0
	elif chase:
		last_known = target.global_position
	else:
		_lost_t += dt
		if _lost_t > 7.0:
			_set_state(S.SEARCH)
			return
	var to_dir := _flat_dir_to(target.global_position)
	var dist := _flat_dist(target.global_position)
	_strafe_t -= dt
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.5, 3.0)
		_strafe = -_strafe
	if def != null and def.melee:
		_combat_melee(dist, to_dir)
	else:
		_combat_ranged(dist, to_dir, see)

func _range_band() -> Vector2:
	if def == null:
		return Vector2(7, 16)
	match def.model:
		"shotgun":
			return Vector2(3.5, 9.0)
		"smg":
			return Vector2(5.0, 12.0)
	return Vector2(7.0, 16.0)

func _combat_ranged(dist: float, to_dir: Vector3, see: bool) -> void:
	var band := _range_band()
	_face_dir = to_dir
	if not see:
		_go(last_known, run_v)
		_face_dir = Vector3.ZERO
		return
	if dist > band.y:
		_want_dir = to_dir
		_want_speed = run_v
	elif dist < band.x:
		_want_dir = -to_dir
		_want_speed = walk_v
	else:
		_want_dir = Vector3(-to_dir.z, 0, to_dir.x) * _strafe
		_want_speed = walk_v * 0.8
	if def != null and dist <= def.range_m * 0.8 and _cooldown <= 0.0 and reload_left <= 0.0 and _stagger <= 0.0:
		_fire()

func _combat_melee(dist: float, to_dir: Vector3) -> void:
	_face_dir = to_dir
	if dist > 1.4:
		_want_dir = to_dir
		_want_speed = run_v
	else:
		_stop()
	if dist < 1.8 and _cooldown <= 0.0 and not _melee_busy and _stagger <= 0.0:
		_cooldown = 1.1
		_melee_busy = true
		if gc != null:
			if gc.tree_active:
				gc.tree_travel("punch", true)
			else:
				gc.play("punch", 0.05)
		await get_tree().create_timer(0.35).timeout
		_melee_busy = false
		if dead or target == null or not is_instance_valid(target) or bool(target.get("dead")):
			return
		if _flat_dist(target.global_position) < 2.3 and target.has_method("take_damage"):
			target.call("take_damage", def.damage * DMG_SCALE * GameManager.enemy_damage_mult(), self, false)
			NPCManager.emit_noise(global_position, 10.0, self)

func _fire() -> void:
	if _mag <= 0:
		reload_left = (gc.duration("reload") * 0.85) if (gc != null and gc.model != null) else 1.8
		if gc != null and gc.model != null:
			gc.play_upper("reload")
		return
	_mag -= 1
	_cooldown = 1.6 / maxf(def.rate, 0.5)
	if gc != null and gc.model != null:
		gc.play_upper("shoot")
	if weapon != null:
		weapon.flash()
	var th := float(target.get("height")) if target.get("height") != null else 1.75
	var tpos := target.global_position + Vector3(0, th * 0.62, 0)
	var muzzle := weapon.muzzle.global_position if (weapon != null and weapon.muzzle != null) else global_position + Vector3(0, height * 0.8, 0)
	var dist := muzzle.distance_to(tpos)
	var chance := clampf(0.7 - dist * 0.012, 0.15, 0.7)
	if target is Player:
		var pl := target as Player
		if pl.speed_now > 3.0:
			chance *= 0.75
		if pl.crouching:
			chance *= 0.8
	if def.pellets > 1:
		chance *= 0.55
	for i in def.pellets:
		var hit := randf() < chance
		if hit and target.has_method("take_damage"):
			target.call("take_damage", def.damage * DMG_SCALE * GameManager.enemy_damage_mult(), self, false)
		var end := tpos if hit else tpos + Vector3(randf_range(-1.2, 1.2), randf_range(-0.8, 0.8), randf_range(-1.2, 1.2))
		NPCActor.spawn_tracer(self, muzzle, end)
	NPCManager.emit_noise(muzzle, def.noise_radius * 0.6, self)
	AudioManager.play_sfx("shot_" + def.id, "Shots", muzzle)

# ---------------------------------------------------------------- réactions
func hear_noise(pos: Vector3, source: Node) -> void:
	if dead or source == self or source is EnemyController or source is AllyController:
		return
	if state == S.IDLE or state == S.PATROL or state == S.SEARCH:
		if stealth and source is Player:
			_raise_alarm(source as Node3D)
		else:
			_alert_pos = pos
			_set_state(S.ALERT)

func _on_hurt(from: Node, _amount: float) -> void:
	if state == S.COMBAT or state == S.FLEE:
		return
	var t := from as Node3D
	if t == null:
		t = _player()
	if t != null:
		_raise_alarm(t)

func _on_died(from: Node) -> void:
	remove_from_group("enemy")
	if from is Player:
		GameManager.add_money(randi_range(8, 40))
	MissionManager.report_kill(tag)
