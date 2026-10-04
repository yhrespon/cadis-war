class_name PlayerCombat
extends Node
## Combat du joueur : arme en main (WeaponDef), tir hitscan avec dispersion/recul/ADS/aide à la visée, rechargement,
## mêlée. Les munitions viennent de InventoryManager. Les dégâts passent par take_damage() des cibles (« damageable »).

const RAY_MASK := 1 | 4 | 8 | 16      # monde, ennemis, civils, véhicules

var p: Player
var def: WeaponDef = null
var weapon: Weapon = null
var _cooldown := 0.0
var reload_left := 0.0
var _tracers: Array = []
var _tracer_mat := StandardMaterial3D.new()
var attack_timer := 0.0
var melee_face := NAN          # cap (radians) vers la cible visée automatiquement pendant un coup de mêlée
var _melee_target: Node3D = null

func setup(player: Player) -> void:
	p = player
	_tracer_mat.albedo_color = Color(1.0, 0.9, 0.5)
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	InventoryManager.weapon_equipped.connect(func(_id: String) -> void: refresh_weapon())
	refresh_weapon()

## Reconstruit le modèle d'arme tenu (os main droite) d'après l'inventaire.
func refresh_weapon() -> void:
	if is_instance_valid(weapon):
		var par := weapon.get_parent()
		weapon.queue_free()
		if par is BoneAttachment3D:
			par.queue_free()
		weapon = null
	def = WeaponManager.get_def(InventoryManager.equipped)
	reload_left = 0.0
	if def == null or p.gc == null:
		return
	weapon = Weapon.make(def)
	weapon.apply_grip(p.gc.manifest_entry)
	p.gc.attach_to_bone(weapon, "RightHand")

func hud_text() -> String:
	if def == null:
		return "Mains nues"
	if def.melee:
		return def.display_name
	return "%s" % def.display_name

func ready_to_attack() -> bool:
	return _cooldown <= 0.0 and reload_left <= 0.0

func is_reloading() -> bool:
	return reload_left > 0.0

func update(delta: float, can_act: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			InventoryManager.do_reload(def.id)
	if not can_act or def == null:
		return
	if Input.is_action_just_pressed("reload") and not def.melee:
		start_reload()
	var want_fire := Input.is_action_pressed("fire") if (def.auto_fire or def.melee) else Input.is_action_just_pressed("fire")
	if want_fire and _cooldown <= 0.0 and reload_left <= 0.0:
		if def.melee:
			melee_attack(def.damage, maxf(1.5, def.range_m + 0.1), p.gc.melee_anim_for(def.model))
		else:
			shoot()

func start_reload() -> void:
	if def == null or def.melee or reload_left > 0.0:
		return
	if InventoryManager.mag_for(def.id) >= def.mag_size or InventoryManager.reserve_for(def.id) <= 0:
		return
	reload_left = p.gc.duration("reload") * 0.85
	p.gc.play_upper("reload")
	AudioManager.play_sfx("reload", "Reload", p.global_position)

func shoot() -> void:
	if not InventoryManager.consume_bullet(def.id):
		_cooldown = 0.25
		UIManager.toast("Chargeur vide : rechargez (R)", Color(1, 0.6, 0.3), 1.2)
		if InventoryManager.reserve_for(def.id) > 0:
			start_reload()
		return
	_cooldown = 1.0 / def.rate
	p.gc.play_upper("shoot")
	if weapon != null:
		weapon.flash()
	var cam := p.cam
	# Rayon passant par le centre exact de l'écran (= le réticule). Camera3D.h_offset décale l'origine de rendu de la caméra :
	# cam.global_position l'ignore, project_ray_origin/normal en tiennent compte (get_camera_transform()).
	var ctr := p.get_viewport().get_visible_rect().size * 0.5
	var origin := cam.project_ray_origin(ctr)
	var fwd := cam.project_ray_normal(ctr)
	# on avance l'origine jusqu'au plan de la tête du joueur : un obstacle/ennemi situé entre la caméra et le joueur ne bloque pas le tir
	origin += fwd * maxf(0.0, (p.rig.global_position - origin).dot(fwd))
	fwd = _assist(origin, fwd)
	var spread := def.spread_deg
	if p.aiming:
		spread *= def.aim_spread_mult
	if p.velocity.length() > 0.5 and p.is_on_floor():
		spread += def.spread_move
	var muzzle_pos := weapon.muzzle.global_position if (weapon != null and weapon.muzzle != null) else p.global_position + Vector3(0, 1.4, 0)
	var space := p.get_world_3d().direct_space_state
	for i in def.pellets:
		var d := _spread(fwd, deg_to_rad(spread))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * def.range_m, RAY_MASK, [p.get_rid()])
		var hit := space.intersect_ray(q)
		var end := origin + d * def.range_m
		if not hit.is_empty():
			end = hit["position"]
			_apply_hit(hit, def.damage)
		_tracer(muzzle_pos, end)
	NPCManager.emit_noise(muzzle_pos, def.noise_radius, p)
	CrimeManager.report_crime("gunfire", muzzle_pos, p)
	AudioManager.play_sfx("shot_" + def.id, "Shots", muzzle_pos)
	p.add_recoil(def.recoil_deg)
	SettingsManager.vibrate(18)

func _apply_hit(hit: Dictionary, dmg: float) -> void:
	var col: Object = hit["collider"]
	var pos: Vector3 = hit["position"]
	var head := false
	if col is Node3D and col.has_method("take_damage"):
		var n3 := col as Node3D
		var h: float = float(col.get("height")) if col.get("height") != null else 1.75
		head = pos.y - n3.global_position.y > h * 0.82
		var final := dmg * (2.0 if head else 1.0)
		col.call("take_damage", final, p, head)
		if SettingsManager.get_value("gameplay", "show_damage"):
			p.hud_damage_number.emit(pos, final, head)
		AudioManager.play_sfx("impact_flesh", "Impacts", pos)
	else:
		AudioManager.play_sfx("impact_world", "Impacts", pos)
	_spark(pos)

## Aide à la visée : infléchit le tir vers l'ennemi vivant le plus proche du réticule (force réglable).
func _assist(origin: Vector3, fwd: Vector3) -> Vector3:
	var strength := float(SettingsManager.get_value("controls", "aim_assist"))
	if strength <= 0.01:
		return fwd
	var best: Node3D = null
	var best_ang := deg_to_rad(2.0 + 6.0 * strength)
	var groups: Array = ["enemy", "gang", "dealer"]
	if CrimeManager.is_wanted():
		groups.append("police")
	var cands: Array = []
	for g in groups:
		cands.append_array(get_tree().get_nodes_in_group(str(g)))
	for e in cands:
		var n := e as Node3D
		if n == null or bool(n.get("dead")):
			continue
		var to := (n.global_position + Vector3(0, 1.25, 0)) - origin
		if to.length() > 30.0:
			continue
		var ang := fwd.angle_to(to)
		if ang < best_ang:
			best_ang = ang
			best = n
	if best == null:
		return fwd
	var target := ((best.global_position + Vector3(0, 1.25, 0)) - origin).normalized()
	return fwd.slerp(target, 0.35 + 0.5 * strength).normalized()

func _spread(dir: Vector3, rad: float) -> Vector3:
	if rad <= 0.0001:
		return dir
	var b := Basis.looking_at(dir, Vector3.UP)
	var a := randf() * TAU
	var r := sqrt(randf()) * rad
	return (b * Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))).normalized()

## Mêlée : coup de poing/pied/batte/poignard sur la cible la plus proche devant le joueur.
## Le poignard joue « stab » (double coup : deux touches à ~20 % et ~60 % de l'animation) ; les autres un seul coup.
func melee_attack(dmg: float, reach: float, anim: String) -> void:
	var stab := anim == "stab"
	_cooldown = 0.95 if stab else 0.55
	attack_timer = 0.5
	# v18 : visée automatique au corps à corps (sur mobile on ne peut pas viser précisément) : on se tourne vers la cible la plus proche
	_melee_target = _nearest_melee_target(reach + 1.8)
	melee_face = NAN
	if _melee_target != null:
		var to := _melee_target.global_position - p.global_position
		melee_face = atan2(to.x, to.z)
	p.start_melee(anim)
	var dur: float = p.gc.duration(anim)
	if stab:
		await get_tree().create_timer(dur * 0.22).timeout
		_melee_hit(dmg, reach)
		await get_tree().create_timer(dur * 0.38).timeout
		_melee_hit(dmg, reach)
		return
	await get_tree().create_timer(dur * 0.3).timeout
	if not _melee_hit(dmg, reach):
		await get_tree().create_timer(dur * 0.15).timeout      # cible qui bouge : deuxième essai
		_melee_hit(dmg, reach)

## Cible de mêlée valide (vivante, touchable, pas un allié) : renvoie la distance horizontale au joueur, ou -1.
func _melee_dist(t: Node3D) -> float:
	if t == null or not is_instance_valid(t) or t == p or not t.has_method("take_damage") or bool(t.get("dead")):
		return -1.0
	if str(t.get("faction")) == "friend" or t.is_in_group("friendly"):
		return -1.0
	var to := t.global_position - p.global_position
	if absf(to.y) > 2.2:
		return -1.0
	to.y = 0.0
	return to.length()

func _melee_candidates() -> Array:
	var out: Array = []
	for n in NPCManager.npcs:
		if is_instance_valid(n):
			out.append(n)
	for n in get_tree().get_nodes_in_group("damageable"):
		if not out.has(n):
			out.append(n)
	return out

## PNJ le plus proche dans un grand cône devant la caméra (ou très proche, quelle que soit la direction).
func _nearest_melee_target(max_d: float) -> Node3D:
	var cam_fwd := Basis(Vector3.UP, p.yaw + PI) * Vector3(0, 0, 1)
	var best: Node3D = null
	var best_d := max_d
	for n in _melee_candidates():
		var t := n as Node3D
		var d := _melee_dist(t)
		if d < 0.0 or d > best_d:
			continue
		var to := t.global_position - p.global_position
		to.y = 0.0
		if d > 1.2 and cam_fwd.dot(to.normalized()) < -0.1:
			continue
		best_d = d
		best = t
	return best

## Renvoie true si une cible a été touchée.
func _melee_hit(dmg: float, reach: float) -> bool:
	if not is_instance_valid(p) or p.dead:
		return false
	var best: Node3D = null
	# 1) la cible verrouillée au début du coup, si elle est encore à portée
	if _melee_target != null and _melee_dist(_melee_target) >= 0.0 and _melee_dist(_melee_target) <= reach + 1.4:
		best = _melee_target
	# 2) sinon la plus proche autour de nous (portée généreuse : rayon de la capsule + marge)
	if best == null:
		best = _nearest_melee_target(reach + 1.0)
	if best != null:
		best.call("take_damage", dmg, p, false)
		if SettingsManager.get_value("gameplay", "show_damage"):
			p.hud_damage_number.emit(best.global_position + Vector3(0, 1.5, 0), dmg, false)
		p.add_recoil(1.2)
		NPCManager.emit_noise(best.global_position, 10.0, p)
		AudioManager.play_sfx("melee_hit", "Impacts", best.global_position)
		SettingsManager.vibrate(25)
		return true
	AudioManager.play_sfx("melee_swing", "Impacts", p.global_position)
	return false

func _tracer(a: Vector3, b: Vector3) -> void:
	var seg := a.distance_to(b)
	if seg < 0.2:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, seg)
	mi.mesh = bm
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.get_tree().current_scene.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.RIGHT if absf((b - a).normalized().y) > 0.99 else Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())

func _spark(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	mi.mesh = sm
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(0.08).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())
