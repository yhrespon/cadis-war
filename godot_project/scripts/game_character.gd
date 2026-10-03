class_name GameCharacter
extends Node3D
## Enveloppe d'un personnage .glb : charge le modèle, règle les boucles (d'après manifest.json), joue les animations.

var model: Node3D
var player: AnimationPlayer
var manifest_entry: Dictionary
## true : le nœud se déplace tout seul avec le root motion (visionneuse).
## false : lire consume_root_motion() et l'appliquer à un CharacterBody3D.
var apply_root_motion := true
var last_motion := Vector3.ZERO

static func load_manifest() -> Dictionary:
	var f := FileAccess.open("res://characters/manifest.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func setup(entry: Dictionary) -> bool:
	manifest_entry = entry
	var scene := load("res://characters/%s" % entry["file"]) as PackedScene
	if scene == null:
		push_error("glb introuvable/non importé : %s" % entry["file"])
		return false
	model = scene.instantiate()
	add_child(model)
	player = _find_player(model)
	if player == null:
		push_error("AnimationPlayer absent dans %s" % entry["file"])
		return false
	# Root motion : le déplacement est stocké sur le joint _rootJoint ; Godot l'extrait et laisse l'os en place.
	var skel := _find_skeleton(model)
	if skel and skel.find_bone("_rootJoint") >= 0:
		var base_node := player.get_node(player.root_node)
		player.root_motion_track = NodePath("%s:_rootJoint" % base_node.get_path_to(skel))
	else:
		push_warning("Skeleton3D/_rootJoint introuvable : pas de root motion")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for anim_name in entry["animations"]:
		var lib_anim := _get_anim(anim_name)
		if lib_anim:
			lib_anim.loop_mode = Animation.LOOP_LINEAR if entry["animations"][anim_name]["loop"] else Animation.LOOP_NONE
	return true

func _physics_process(_dt: float) -> void:
	if player == null:
		return
	# déplacement local au modèle (+Z = avant du modèle) -> repère monde
	last_motion = global_transform.basis * player.get_root_motion_position()
	if apply_root_motion:
		global_position += last_motion

## Déplacement (monde) produit par l'animation depuis la dernière frame physique.
## Pour un CharacterBody3D : velocity = gc.consume_root_motion() / delta ; move_and_slide().
func consume_root_motion() -> Vector3:
	return last_motion

func play(anim_name: String, blend := 0.15) -> void:
	if player and player.has_animation(anim_name):
		player.play(anim_name, blend)

## Durée (s) d'une animation d'après le manifest.
func duration(anim_name: String) -> float:
	return float(manifest_entry["animations"][anim_name]["duration"])

## Vitesse horizontale (m/s) du root motion d'une animation en boucle (0 si aucune).
func anim_speed(anim_name: String) -> float:
	var rm: Dictionary = manifest_entry["animations"][anim_name].get("root_motion", {})
	if not rm.has("speed_mps"):
		return 0.0
	var v: Array = rm["speed_mps"]
	return Vector2(float(v[0]), float(v[2])).length()

## Distance horizontale (m) parcourue par une animation (roulade, saut...).
func anim_distance(anim_name: String) -> float:
	var rm: Dictionary = manifest_entry["animations"][anim_name].get("root_motion", {})
	if not rm.has("distance_m"):
		return 0.0
	var d: Array = rm["distance_m"]
	return Vector2(float(d[0]), float(d[2])).length()

## Attache un nœud à l'os dont le nom finit par bone_suffix (ex. "RightHand").
## Godot peut renommer « mixamorig:RightHand » en « mixamorig_RightHand » : on compare donc la fin du nom.
func attach_to_bone(node: Node3D, bone_suffix: String) -> BoneAttachment3D:
	var skel := _find_skeleton(model)
	if skel == null:
		return null
	for i in skel.get_bone_count():
		var bn := skel.get_bone_name(i)
		if bn.ends_with(bone_suffix):
			var ba := BoneAttachment3D.new()
			ba.bone_name = bn
			skel.add_child(ba)
			ba.add_child(node)
			return ba
	push_warning("os introuvable : %s" % bone_suffix)
	return null

func animation_names() -> Array:
	return manifest_entry["animations"].keys()

func _get_anim(n: String) -> Animation:
	if player.has_animation(n):
		return player.get_animation(n)
	return null

func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_player(c)
		if r:
			return r
	return null

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null
