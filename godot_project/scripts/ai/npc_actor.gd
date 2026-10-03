class_name NPCActor
extends CharacterBody3D
## Base commune des PNJ (ennemis, civils, allié) : capsule, GameCharacter (AnimationTree comme le joueur), déplacement par
## steering + raycasts (pas de navmesh), dégâts / mort, LOD d'IA via NPCManager (ai_lod, on_lod_changed, hear_noise).
## Les sous-classes surchargent _setup_role(), _think(dt), _on_hurt(), _on_died(), hear_noise().
## v13 : script chargé ; comportements de déplacement, dégâts, LOD et mort non testés en parcours gameplay.
##
## Contrat : le spawner fixe `position` (le parent est à l'origine) AVANT add_child ; tout le reste se fait dans _ready().
## Attributs lus par d'autres scripts : `dead` et `height` (PlayerCombat), `ai_lod` (NPCManager), take_damage(amount, from, head).

const GRAVITY := 20.0

@export var char_id := ""
var display_name := ""
var max_hp := 60.0
var hp := 60.0
var dead := false
var height := 1.75
var ai_lod := 0
var gc: GameCharacter = null
var speed_now := 0.0
var walk_v := 1.1
var run_v := 3.6
var sprint_v := 5.2
var corpse_time := 8.0
var hold_anim := ""            # animation de base maintenue (ex. « crouch »), vide = locomotion

var _want_dir := Vector3.ZERO
var _want_speed := 0.0
var _face_dir := Vector3.ZERO
var _think_acc := 0.0
var _stagger := 0.0
var _side := 1.0
var _stuck_t := 0.0
var _stuck_check := 0.0
var _last_pos := Vector3.ZERO
var _layer := 0
var _asleep := false
var _cs: CollisionShape3D = null
var _loco_name := ""
static var _tracer_mat: StandardMaterial3D = null

# ---------------------------------------------------------------- construction
## Choisit un personnage du manifest dont l'âge est dans `ages` (« adulte », « ado », « enfant »).
static func pick_character(ages: Array) -> String:
	var ids: Array = []
	for id in GameManager.character_ids():
		var age := str(GameManager.character_entry(str(id)).get("age", "adulte"))
		if ages.has(age):
			ids.append(str(id))
	if ids.is_empty():
		return GameManager.character_id
	return str(ids[randi() % ids.size()])

func _allowed_ages() -> Array:
	return ["adulte", "ado"]

func _ready() -> void:
	if char_id == "":
		char_id = pick_character(_allowed_ages())
	var entry := GameManager.character_entry(char_id)
	height = float(entry["height_m"])
	var sc := clampf(height / 1.75, 0.55, 1.0)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28 * clampf(sc, 0.7, 1.0)
	cap.height = height
	_cs = CollisionShape3D.new()
	_cs.shape = cap
	_cs.position.y = height * 0.5
	add_child(_cs)

	gc = GameCharacter.new()
	add_child(gc)
	if gc.setup(entry):
		gc.apply_root_motion = false
		if not gc.build_tree():
			push_warning("NPC %s : AnimationTree indisponible, repli sur AnimationPlayer" % char_id)
		var w := gc.anim_speed("walk")
		walk_v = w if w > 0.3 else walk_v
		var r := gc.anim_speed("run")
		run_v = r if r > walk_v else run_v
		var s := gc.anim_speed("sprint")
		sprint_v = s if s > run_v else sprint_v
	else:
		push_error("NPC : personnage %s non chargé" % char_id)
	_setup_role()
	hp = max_hp
	_layer = collision_layer
	_last_pos = global_position
	NPCManager.register(self)

## À surcharger : groupes, couches de collision, points de vie, arme.
func _setup_role() -> void:
	pass

## Recolore haut / bas (palette = tableau de Color) via les pastilles d'atlas ; les cheveux gardent leur couleur.
func randomize_outfit(palette: Array) -> void:
	if gc == null or palette.is_empty():
		return
	gc.apply_outfit(palette[randi() % palette.size()], palette[randi() % palette.size()], null)

# ---------------------------------------------------------------- boucle
func _think_interval() -> float:
	return [0.1, 0.25, 0.6][clampi(ai_lod, 0, 2)]

func _physics_process(delta: float) -> void:
	if dead or _asleep:
		return
	_think_acc += delta
	if _think_acc >= _think_interval():
		var dt := _think_acc
		_think_acc = 0.0
		_think(dt)
	_move(delta)

## À surcharger : décide _want_dir / _want_speed / _face_dir (appelé à fréquence réduite selon ai_lod).
func _think(_dt: float) -> void:
	pass

func _move(delta: float) -> void:
	var dir := _want_dir
	var spd := _want_speed
	if _stagger > 0.0:
		_stagger -= delta
		spd = 0.0
	if spd > 0.05 and dir.length() > 0.01:
		dir = _avoid(dir)
	else:
		dir = Vector3.ZERO
	speed_now = move_toward(speed_now, spd, 14.0 * delta)
	velocity.x = dir.x * speed_now
	velocity.z = dir.z * speed_now
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

	_stuck_t = maxf(0.0, _stuck_t - delta)
	_stuck_check += delta
	if _stuck_check >= 0.6:
		var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
		if spd > 0.8 and moved < 0.12:
			_side = -_side
			_stuck_t = 0.8
			_on_stuck()
		_last_pos = global_position
		_stuck_check = 0.0

	var f := _face_dir
	if f.length() < 0.01:
		f = dir
	if f.length() > 0.05 and gc != null:
		gc.rotation.y = lerp_angle(gc.rotation.y, atan2(f.x, f.z), 1.0 - exp(-10.0 * delta))
	_play_loco()

func _on_stuck() -> void:
	pass

## Évitement d'obstacles : 3 rayons horizontaux (monde + véhicules). Pas de navmesh : les cul-de-sac se règlent par la détection de blocage.
func _avoid(dir: Vector3) -> Vector3:
	if _stuck_t > 0.0:
		return dir.rotated(Vector3.UP, 1.3 * _side)
	var from := global_position + Vector3(0, 0.6, 0)
	var look := 1.2 + speed_now * 0.25
	if not _ray_hit(from, dir * look):
		return dir
	var left := dir.rotated(Vector3.UP, 0.9)
	var right := dir.rotated(Vector3.UP, -0.9)
	var free_l := not _ray_hit(from, left * look)
	var free_r := not _ray_hit(from, right * look)
	if free_l and not free_r:
		return left
	if free_r and not free_l:
		return right
	if free_l and free_r:
		return left if _side > 0.0 else right
	return dir.rotated(Vector3.UP, PI * 0.5 * _side)

func _ray_hit(from: Vector3, vec: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + vec, 1 | 16, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _play_loco() -> void:
	if gc == null or gc.model == null or dead:
		return
	if gc.tree_active:
		if hold_anim != "":
			if gc.current_base_state() != hold_anim:
				gc.play(hold_anim)
			return
		if _stagger <= 0.0 and gc.current_base_state() != "loco":
			gc.play("idle")
		gc.set_loco_speed(speed_now)
	else:
		var n := "idle"
		if hold_anim != "":
			n = hold_anim
		elif speed_now > (run_v + walk_v) * 0.5:
			n = "run"
		elif speed_now > 0.3:
			n = "walk"
		if n != _loco_name:
			_loco_name = n
			gc.play(n)

# ---------------------------------------------------------------- aides de déplacement
func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()

func _flat_dir_to(p: Vector3) -> Vector3:
	var d := p - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.ZERO

func _go(p: Vector3, speed: float) -> void:
	if _flat_dist(p) < 0.35:
		_stop()
		return
	_want_dir = _flat_dir_to(p)
	_want_speed = speed

func _stop() -> void:
	_want_dir = Vector3.ZERO
	_want_speed = 0.0

# ---------------------------------------------------------------- dégâts / mort
func take_damage(amount: float, from: Node = null, _head := false) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	_on_hurt(from, amount)
	if hp <= 0.0:
		_die(from)
	elif amount >= 15.0 and _stagger <= 0.0 and gc != null:
		_stagger = 0.45
		if gc.tree_active:
			gc.tree_travel("damage", true)
		else:
			gc.play("damage", 0.05)

func _on_hurt(_from: Node, _amount: float) -> void:
	pass

func _on_died(_from: Node) -> void:
	pass

func _die(from: Node) -> void:
	dead = true
	hp = 0.0
	collision_layer = 0
	velocity = Vector3.ZERO
	_want_speed = 0.0
	if gc != null:
		if gc.tree_active:
			gc.tree_travel("death", true)
		else:
			gc.play("death", 0.1)
	_on_died(from)
	await get_tree().create_timer(corpse_time).timeout
	if is_inside_tree():
		queue_free()

# ---------------------------------------------------------------- NPCManager
func on_lod_changed(lod: int) -> void:
	var sleep := lod >= 3
	if dead or sleep == _asleep:
		return
	_asleep = sleep
	visible = not sleep
	collision_layer = 0 if sleep else _layer
	if gc != null and gc.tree != null:
		gc.tree.active = not sleep

## Bruit (tir, impact) entendu dans le rayon d'émission : à surcharger.
func hear_noise(_pos: Vector3, _source: Node) -> void:
	pass

# ---------------------------------------------------------------- effets
static func spawn_tracer(host: Node, a: Vector3, b: Vector3) -> void:
	var seg := a.distance_to(b)
	if seg < 0.2 or host == null or not host.is_inside_tree():
		return
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.albedo_color = Color(1.0, 0.55, 0.3)
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, seg)
	mi.mesh = bm
	mi.material_override = _tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.RIGHT if absf((b - a).normalized().y) > 0.99 else Vector3.UP)
	host.get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free())
