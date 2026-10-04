extends Node
## Paramètres persistants (user://settings.cfg), application réelle (audio, FPS, graphismes) et qualité dynamique.
## v13 : autoload chargé sous Godot 4.3 ; réglages/interactions non testés.

signal changed(section: String, key: String)

const PATH := "user://settings.cfg"
const QUALITIES: Array = ["Auto", "Low", "Medium", "High", "Ultra"]

const PRESETS := {
	"Low":    {"res_scale": 0.6,  "shadows": false, "view_distance": 70.0,  "effects": false, "lod": 0.5, "textures": 2, "fps": 30},
	"Medium": {"res_scale": 0.8,  "shadows": false, "view_distance": 100.0, "effects": true,  "lod": 0.8, "textures": 1, "fps": 45},
	"High":   {"res_scale": 1.0,  "shadows": true,  "view_distance": 130.0, "effects": true,  "lod": 1.0, "textures": 0, "fps": 60},
	"Ultra":  {"res_scale": 1.0,  "shadows": true,  "view_distance": 180.0, "effects": true,  "lod": 1.3, "textures": 0, "fps": 60},
}

const DEFAULTS := {
	"audio": {"master": 1.0, "music": 0.7, "sfx": 1.0, "voice": 1.0},
	"controls": {"sensitivity": 1.0, "touch_scale": 1.0, "touch_opacity": 0.55, "touch_offset_x": 0.0, "touch_offset_y": 0.0,
		"vibration": true, "invert_y": false, "aim_assist": 0.5},
	"graphics": {"quality": "Auto", "textures": 0, "shadows": true, "view_distance": 150.0, "effects": true, "lod": 1.0,
		"res_scale": 1.0, "fps": 60, "dynamic_quality": true},
	"gameplay": {"difficulty": 1, "show_damage": true},
}

var data: Dictionary = {}
var _dyn_scale := 1.0
var _acc_t := 0.0
var _acc_frames := 0
var _good_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	call_deferred("apply_all")

func _load() -> void:
	data = DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		_apply_preset("Auto")      # premier lancement : préréglage selon l'appareil
		return
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			if cf.has_section_key(section, key):
				data[section][key] = cf.get_value(section, key)
	# v18 : anciens réglages enregistrés = trop lourds : on réapplique le préréglage de l'appareil une fois
	if int(cf.get_value("meta", "v", 0)) < 18 and str(data["graphics"]["quality"]) == "Auto":
		_apply_preset("Auto")
		save()

func save() -> void:
	var cf := ConfigFile.new()
	for section in data:
		for key in data[section]:
			cf.set_value(section, key, data[section][key])
	cf.set_value("meta", "v", 18)
	cf.save(PATH)

func get_value(section: String, key: String) -> Variant:
	return data[section][key]

func set_value(section: String, key: String, value: Variant) -> void:
	data[section][key] = value
	if section == "graphics" and key == "quality":
		_apply_preset(str(value))
	save()
	if section == "graphics" and key == "quality":
		apply_all()                # le préréglage a réécrit fps, résolution, ombres... : tout appliquer
	else:
		_apply_one(section, key)
	changed.emit(section, key)

func _auto_quality() -> String:
	if not OS.has_feature("mobile"):
		return "High"
	return "Medium"      # v18 : sur mobile on démarre en Medium (modifiable dans Réglages)

func _apply_preset(q: String) -> void:
	var name := _auto_quality() if q == "Auto" else q
	if not PRESETS.has(name):
		return
	var p: Dictionary = PRESETS[name]
	for k in p:
		data["graphics"][k] = p[k]
	_dyn_scale = float(p["res_scale"])
	var fps_list := available_fps()
	if not fps_list.has(int(data["graphics"]["fps"])):
		data["graphics"]["fps"] = fps_list[fps_list.size() - 1]

func available_fps() -> Array:
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz <= 0.0:
		hz = 60.0
	var out: Array = [30]
	for f in [45, 60, 90]:
		if float(f) <= hz + 1.0:
			out.append(f)
	return out

func apply_all() -> void:
	for section in data:
		for key in data[section]:
			_apply_one(section, key)



func _apply_one(section: String, key: String) -> void:
	if section == "audio":
		AudioManager.set_group_volume(key, float(data["audio"][key]))
	elif section == "graphics":
		match key:
			"fps":
				Engine.max_fps = int(data["graphics"]["fps"])
			"res_scale":
				_dyn_scale = float(data["graphics"]["res_scale"])
				_set_scale(_dyn_scale)
			"shadows", "view_distance", "lod", "textures":
				apply_to_scene()

func _set_scale(s: float) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.scaling_3d_scale = clampf(s, 0.4, 1.0)

## Applique ombres, distance de vue et biais de mipmap à la scène courante (appelé aussi par la scène de jeu).
func apply_to_scene() -> void:
	var g: Dictionary = data["graphics"]
	for n in get_tree().get_nodes_in_group("sun"):
		var l := n as DirectionalLight3D
		if l != null:
			l.shadow_enabled = bool(g["shadows"])
			l.directional_shadow_max_distance = minf(float(g["view_distance"]), 80.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.far = float(g["view_distance"]) + 40.0
	var vp := get_viewport()
	vp.mesh_lod_threshold = 4.0 if float(g["view_distance"]) <= 100.0 else 2.5     # v18 : modèles simplifiés plus tôt (LOD auto des .glb)
	WorldManager.load_radius = 1 if float(g["view_distance"]) <= 100.0 else 2       # v18 : moins de secteurs de ville chargés
	if "texture_mipmap_bias" in vp:
		vp.set("texture_mipmap_bias", float(g["textures"]) * 0.75)

func _process(delta: float) -> void:
	if not bool(data["graphics"]["dynamic_quality"]):
		return
	_acc_t += delta
	_acc_frames += 1
	if _acc_t < 2.0:
		return
	var fps := float(_acc_frames) / _acc_t
	_acc_t = 0.0
	_acc_frames = 0
	var target := float(int(data["graphics"]["fps"]))
	if fps < target * 0.82 and _dyn_scale > 0.5:
		_dyn_scale = maxf(0.5, _dyn_scale - 0.1)
		_set_scale(_dyn_scale)
		_good_time = 0.0
	elif fps > target * 0.97:
		_good_time += 2.0
		var cap := float(data["graphics"]["res_scale"])
		if _good_time >= 10.0 and _dyn_scale < cap:
			_dyn_scale = minf(cap, _dyn_scale + 0.1)
			_set_scale(_dyn_scale)
			_good_time = 0.0
	else:
		_good_time = 0.0

## Facteur de densité des PNJ selon la qualité (0.5 à 1.3).
func npc_density() -> float:
	return clampf(float(data["graphics"]["lod"]), 0.5, 1.3)

func vibrate(ms: int) -> void:
	if bool(data["controls"]["vibration"]) and (OS.has_feature("mobile") or OS.has_feature("android")):
		Input.vibrate_handheld(maxi(ms, 45))      # < ~40 ms : ignoré par beaucoup de moteurs de vibration Android
