class_name GameCharacter
extends Node3D
## Enveloppe d'un personnage .glb : modèle, animations (AnimationPlayer simple OU AnimationTree à couches),
## tenue recolorable (pastilles d'atlas), attache d'armes aux os. v13 : setup des 10 modèles et fin du OneShot smoke-testés sous Godot 4.3.
##
## AnimationTree (use build_tree()) : machine d'états « base » (loco = BlendSpace1D idle/walk/run/sprint selon la vitesse,
## crouch, jump, roll, damage, death, climb, drive, interact, dance, kick, punch) + OneShot « upper » filtré sur le haut du corps
## (os sous Spine) jouant shoot/reload : on peut tirer/recharger en marchant, les jambes continuent à marcher.

const LOCO_STATES: Array = ["idle", "walk", "run", "sprint"]
const BASE_STATES: Array = ["crouch", "roll", "damage", "death", "drive", "interact", "dance", "kick", "punch"]
## Animations facultatives (absentes des anciens modèles « legacy ») : ajoutées à l'arbre si le GLB les contient (v17 : « stab », poignard).
const OPTIONAL_STATES: Array = ["stab"]
const OUTFIT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform vec4 top_rect;
uniform vec4 bottom_rect;
uniform vec4 hair_rect;
uniform vec3 top_col : source_color = vec3(1.0);
uniform vec3 bottom_col : source_color = vec3(1.0);
uniform vec3 hair_col : source_color = vec3(1.0);
uniform vec3 use_flags = vec3(0.0);
bool inside(vec2 uv, vec4 r) { return uv.x >= r.x && uv.y >= r.y && uv.x <= r.z && uv.y <= r.w; }
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	if (use_flags.x > 0.5 && inside(UV, top_rect)) c = top_col;
	if (use_flags.y > 0.5 && inside(UV, bottom_rect)) c = bottom_col;
	if (use_flags.z > 0.5 && inside(UV, hair_rect)) c = hair_col;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
}
"""

static var _shader: Shader = null

var model: Node3D
var player: AnimationPlayer
var tree: AnimationTree = null
var manifest_entry: Dictionary
## true : le nœud se déplace tout seul avec le root motion (visionneuse).
var apply_root_motion := true
var last_motion := Vector3.ZERO
var tree_active := false
var _outfit_mat: ShaderMaterial = null
var _started := false

static func load_manifest() -> Dictionary:
	if GameManager != null and not GameManager.manifest.is_empty():
		return GameManager.manifest
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
	if player == null or tree_active:
		return
	last_motion = global_transform.basis * player.get_root_motion_position()
	if apply_root_motion:
		global_position += last_motion

func consume_root_motion() -> Vector3:
	return last_motion

# ---------------------------------------------------------------- animation : API commune
## Joue une animation (mode simple) ou demande l'état correspondant (mode AnimationTree).
func play(anim_name: String, blend := 0.15) -> void:
	if tree_active:
		if LOCO_STATES.has(anim_name):
			tree_travel("loco")
		else:
			tree_travel(anim_name)
		return
	if player and player.has_animation(anim_name):
		player.play(anim_name, blend)

func duration(anim_name: String) -> float:
	return float(manifest_entry["animations"][anim_name]["duration"])

func anim_speed(anim_name: String) -> float:
	var rm: Dictionary = manifest_entry["animations"][anim_name].get("root_motion", {})
	if not rm.has("speed_mps"):
		return 0.0
	var v: Array = rm["speed_mps"]
	return Vector2(float(v[0]), float(v[2])).length()

func anim_distance(anim_name: String) -> float:
	var rm: Dictionary = manifest_entry["animations"][anim_name].get("root_motion", {})
	if not rm.has("distance_m"):
		return 0.0
	var d: Array = rm["distance_m"]
	return Vector2(float(d[0]), float(d[2])).length()

## true si le modèle possède cette animation (les anciens modèles n'ont pas « stab »).
func has_anim(anim_name: String) -> bool:
	return manifest_entry.has("animations") and Dictionary(manifest_entry["animations"]).has(anim_name)

## Animation d'attaque de mêlée adaptée à l'arme (poignard -> « stab » si le modèle l'a, sinon « punch »).
func melee_anim_for(weapon_model: String) -> String:
	if weapon_model == "dagger" and has_anim("stab"):
		return "stab"
	return "punch"

func animation_names() -> Array:
	return manifest_entry["animations"].keys()

# ---------------------------------------------------------------- AnimationTree
func _anim_node(n: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = StringName(n)
	return a

func build_tree() -> bool:
	if player == null:
		return false
	var base_states: Array = BASE_STATES.duplicate()
	for opt in OPTIONAL_STATES:
		if player.has_animation(opt):
			base_states.append(opt)
	for n in LOCO_STATES + base_states + ["jump", "shoot", "reload"]:
		if not player.has_animation(n):
			push_error("Animation manquante pour l'arbre : %s" % n)
			return false
	player.stop()   # l'arbre pilote seul les pistes : aucune animation ne doit tourner en parallèle dans l'AnimationPlayer
	tree = AnimationTree.new()
	tree.name = "AnimTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	# Le root motion est calculé par le mixeur qui joue les pistes : sans ceci, l'arbre APPLIQUERAIT la translation de _rootJoint
	# (le modèle glisserait hors de la capsule à chaque boucle de marche). Même chemin que celui de l'AnimationPlayer (même nœud racine « .. »).
	tree.root_motion_track = player.root_motion_track
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	# --- locomotion : blend selon la vitesse réelle (m/s)
	var walk_v := maxf(anim_speed("walk"), 0.5)
	var run_v := maxf(anim_speed("run"), walk_v + 0.5)
	var sprint_v := maxf(anim_speed("sprint"), run_v + 0.5)
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = sprint_v + 0.5
	loco.sync = true
	loco.add_blend_point(_anim_node("idle"), 0.0)
	loco.add_blend_point(_anim_node("walk"), walk_v)
	loco.add_blend_point(_anim_node("run"), run_v)
	loco.add_blend_point(_anim_node("sprint"), sprint_v)

	# --- saut : durée recalée par un nœud TimeScale
	var jump_bt := AnimationNodeBlendTree.new()
	jump_bt.add_node("anim", _anim_node("jump"), Vector2(0, 0))
	jump_bt.add_node("scale", AnimationNodeTimeScale.new(), Vector2(200, 0))
	jump_bt.connect_node("scale", 0, "anim")
	jump_bt.connect_node("output", 0, "scale")

	var climb_bt := AnimationNodeBlendTree.new()
	climb_bt.add_node("anim", _anim_node("climb"), Vector2(0, 0))
	climb_bt.add_node("scale", AnimationNodeTimeScale.new(), Vector2(200, 0))
	climb_bt.connect_node("scale", 0, "anim")
	climb_bt.connect_node("output", 0, "scale")

	var base := AnimationNodeStateMachine.new()
	var names: Array = ["loco", "jump", "climb"] + base_states
	base.add_node("loco", loco, Vector2(0, 0))
	base.add_node("jump", jump_bt, Vector2(200, 0))
	base.add_node("climb", climb_bt, Vector2(400, 0))
	var i := 3
	for n in base_states:
		base.add_node(n, _anim_node(n), Vector2(200 * (i % 4), 120 * (i >> 2)))
		i += 1
	for a in names:
		for b in names:
			if a != b:
				var trans := AnimationNodeStateMachineTransition.new()
				trans.xfade_time = 0.15
				base.add_transition(a, b, trans)

	var upper_sel := AnimationNodeStateMachine.new()
	upper_sel.add_node("shoot", _anim_node("shoot"), Vector2(0, 0))
	upper_sel.add_node("reload", _anim_node("reload"), Vector2(200, 0))
	for pair in [["shoot", "reload"], ["reload", "shoot"]]:
		var t2 := AnimationNodeStateMachineTransition.new()
		upper_sel.add_transition(pair[0], pair[1], t2)
	for state in ["shoot", "reload"]:
		var to_end := AnimationNodeStateMachineTransition.new()
		to_end.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
		to_end.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		upper_sel.add_transition(state, "End", to_end)

	var os := AnimationNodeOneShot.new()
	os.fadein_time = 0.08
	os.fadeout_time = 0.2
	os.filter_enabled = true
	for p in _upper_track_paths():
		os.set_filter_path(p, true)

	var bt := AnimationNodeBlendTree.new()
	bt.add_node("base", base, Vector2(0, 0))
	bt.add_node("upper_sel", upper_sel, Vector2(0, 200))
	bt.add_node("upper", os, Vector2(300, 100))
	bt.connect_node("upper", 0, "base")
	bt.connect_node("upper", 1, "upper_sel")
	bt.connect_node("output", 0, "upper")
	tree.tree_root = bt
	tree.active = true
	tree_active = true
	_started = false
	return true

func _upper_track_paths() -> Array:
	var out: Array = []
	var skel := _find_skeleton(model)
	if skel == null:
		return out
	var anim_root := player.get_node(player.root_node)
	var skeleton_path: NodePath = anim_root.get_path_to(skel)
	for i in skel.get_bone_count():
		var j := i
		while j >= 0:
			if skel.get_bone_name(j).ends_with("Spine"):
				# Ajouter tout le sous-arbre (y compris mains/doigts) : certaines animations
				# ne keyframent pas toutes ces articulations, mais le filtre reste complet.
				var p := NodePath("%s:%s" % [skeleton_path, skel.get_bone_name(i)])
				if not out.has(p):
					out.append(p)
				break
			j = skel.get_bone_parent(j)
	return out

func _playback(path: String) -> AnimationNodeStateMachinePlayback:
	if tree == null:
		return null
	return tree.get(path) as AnimationNodeStateMachinePlayback

func _ensure_started() -> void:
	if _started or tree == null:
		return
	var pb := _playback("parameters/base/playback")
	if pb != null:
		pb.start("loco")
		_started = true

func tree_travel(state: String, restart := false) -> void:
	_ensure_started()
	var pb := _playback("parameters/base/playback")
	if pb == null:
		return
	if restart or pb.get_current_node() == StringName(state):
		pb.start(state, true)
	else:
		pb.travel(state)

func current_base_state() -> String:
	var pb := _playback("parameters/base/playback")
	return str(pb.get_current_node()) if pb != null else ""

func set_loco_speed(v: float) -> void:
	if tree != null:
		_ensure_started()
		tree.set("parameters/base/loco/blend_position", v)

func set_jump_scale(s: float) -> void:
	if tree != null:
		tree.set("parameters/base/jump/scale/scale", s)

## Vitesse de l'animation d'escalade (0 = figée sur l'échelle).
func set_climb_scale(s: float) -> void:
	if tree != null:
		tree.set("parameters/base/climb/scale/scale", s)

## Joue shoot/reload sur le haut du corps seulement (AnimationTree) ; en mode simple : animation complète.
func play_upper(anim: String, speed := 1.0) -> void:
	if not tree_active:
		play(anim, 0.08)
		return
	var pb := _playback("parameters/upper_sel/playback")
	if pb != null:
		pb.start(anim, true)
	tree.set("parameters/upper/request", 1)   # 1 = FIRE (AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func upper_active() -> bool:
	return tree != null and bool(tree.get("parameters/upper/active"))

# ---------------------------------------------------------------- tenue
## Recolore le haut / bas / cheveux (couleur = Color, null = couleur d'origine) via les pastilles d'atlas.
func apply_outfit(top: Variant, bottom: Variant, hair: Variant) -> void:
	if model == null:
		return
	var tiles: Dictionary = manifest_entry.get("outfit_tiles", {})
	if tiles.is_empty():
		_apply_tint(top, bottom, hair)   # modèles Mixamo : teinte par matériau (pas d'atlas à pastilles)
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = OUTFIT_SHADER
	for mi in _find_meshes(model):
		var src := mi.get_active_material(0) as BaseMaterial3D   # glTF -> StandardMaterial3D à l'import ; BaseMaterial3D couvre aussi ORMMaterial3D
		if src == null and _outfit_mat == null:
			push_warning("apply_outfit : matériau de %s non reconnu (%s) : tenue non recolorée" % [manifest_entry.get("id", "?"), mi.get_active_material(0)])
			continue
		if _outfit_mat == null:
			if src.albedo_texture == null:
				push_warning("apply_outfit : pas de texture d'albedo sur %s : tenue non recolorée" % manifest_entry.get("id", "?"))
				return
			_outfit_mat = ShaderMaterial.new()
			_outfit_mat.shader = _shader
			_outfit_mat.set_shader_parameter("albedo_tex", src.albedo_texture)
			if src.normal_texture != null:
				_outfit_mat.set_shader_parameter("normal_tex", src.normal_texture)
			for k in ["top", "bottom", "hair"]:
				var r: Array = [0.0, 0.0, 0.0, 0.0]
				if tiles.has(k):
					r = tiles[k]["rect"]
				_outfit_mat.set_shader_parameter(k + "_rect", Vector4(r[0], r[1], r[2], r[3]))
		mi.set_surface_override_material(0, _outfit_mat)
	if _outfit_mat == null:
		return
	var flags := Vector3.ZERO
	if top is Color:
		flags.x = 1.0
		_outfit_mat.set_shader_parameter("top_col", top)
	if bottom is Color:
		flags.y = 1.0
		_outfit_mat.set_shader_parameter("bottom_col", bottom)
	if hair is Color and tiles.has("hair"):
		flags.z = 1.0
		_outfit_mat.set_shader_parameter("hair_col", hair)
	_outfit_mat.set_shader_parameter("use_flags", flags)

## Teinte par matériau (modèles Mixamo) : multiplie la couleur d'albedo des matériaux listés dans manifest["tint_materials"][top|bottom|hair].
## null = couleur d'origine (blanc). Les modèles sans matériau séparé (ex. mx_eve) ne sont pas recolorables : l'appel ne fait rien, sans erreur.
func _apply_tint(top: Variant, bottom: Variant, hair: Variant) -> void:
	var groups: Dictionary = manifest_entry.get("tint_materials", {})
	if groups.is_empty():
		return
	var wanted := {"top": top, "bottom": bottom, "hair": hair}
	for mi in _find_meshes(model):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var base := m.mesh.surface_get_material(i)
			if base == null:
				continue
			for k in wanted:
				if not groups.has(k) or not Array(groups[k]).has(base.resource_name):
					continue
				var src: Material = m.get_surface_override_material(i)
				if src == null:
					src = base.duplicate() as Material
					m.set_surface_override_material(i, src)
				var bm := src as BaseMaterial3D
				if bm != null:
					var c: Variant = wanted[k]
					bm.albedo_color = c if c is Color else Color.WHITE

func apply_inventory_outfit() -> void:
	apply_outfit(InventoryManager.outfit_color("top"), InventoryManager.outfit_color("bottom"), InventoryManager.outfit_color("hair"))

func _find_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_meshes(c))
	return out

# ---------------------------------------------------------------- os / armes
## Attache un nœud à l'os dont le nom finit par bone_suffix (« mixamorig:RightHand » peut devenir « mixamorig_RightHand »).
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
