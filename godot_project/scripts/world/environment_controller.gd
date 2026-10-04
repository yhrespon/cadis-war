class_name EnvironmentController
extends Node
## Ambiance de la ville (v17) : cycle jour / nuit + météo (ensoleillé, nuageux, pluie, orage, brouillard).
## Pilote : ciel (ProceduralSkyMaterial), soleil/lune (DirectionalLight3D du groupe « sun »), lumière ambiante, brouillard,
## pluie (GPUParticles3D qui suit la caméra), routes mouillées et fenêtres/lampadaires allumés (CityBuilder.set_night / set_wet),
## phares des véhicules (groupe « headlight »), son de pluie (rain_loop) et éclairs.
## L'heure et la météo sont sauvegardées (GameManager.world_hour / world_weather). [NON TESTÉ DANS GODOT]

signal weather_changed(weather: String)

const WEATHERS: Array = ["clear", "cloudy", "rain", "storm", "fog"]
const WEATHER_LABEL := {"clear": "Ensoleillé", "cloudy": "Nuageux", "rain": "Pluie", "storm": "Orage", "fog": "Brouillard"}
const DAY_SECONDS := 720.0           # 12 minutes réelles = 24 h de jeu
const WEATHER_MIN := 150.0           # durée mini d'une météo (s)
const WEATHER_MAX := 330.0

# profils [ciel haut, horizon, soleil, énergie soleil, ambiant, énergie ambiante] par plage horaire
const KEYS: Array = [
	[0.0, Color(0.02, 0.03, 0.09), Color(0.06, 0.07, 0.15), Color(0.55, 0.65, 1.0), 0.20, Color(0.30, 0.34, 0.55), 0.35],
	[5.0, Color(0.04, 0.05, 0.12), Color(0.18, 0.12, 0.2), Color(0.7, 0.7, 1.0), 0.25, Color(0.34, 0.34, 0.5), 0.40],
	[6.5, Color(0.28, 0.38, 0.6), Color(0.95, 0.6, 0.4), Color(1.0, 0.65, 0.4), 0.8, Color(0.6, 0.55, 0.6), 0.5],
	[9.0, Color(0.22, 0.45, 0.82), Color(0.68, 0.8, 0.92), Color(1.0, 0.96, 0.88), 1.15, Color(0.72, 0.76, 0.85), 0.62],
	[14.0, Color(0.2, 0.45, 0.85), Color(0.72, 0.82, 0.93), Color(1.0, 0.97, 0.9), 1.2, Color(0.74, 0.78, 0.86), 0.65],
	[18.0, Color(0.26, 0.38, 0.65), Color(0.95, 0.62, 0.38), Color(1.0, 0.7, 0.45), 0.95, Color(0.66, 0.58, 0.58), 0.5],
	[20.0, Color(0.08, 0.1, 0.22), Color(0.35, 0.2, 0.28), Color(0.6, 0.5, 0.8), 0.3, Color(0.4, 0.38, 0.55), 0.38],
	[22.0, Color(0.02, 0.03, 0.09), Color(0.06, 0.07, 0.15), Color(0.55, 0.65, 1.0), 0.2, Color(0.30, 0.34, 0.55), 0.35],
	[24.0, Color(0.02, 0.03, 0.09), Color(0.06, 0.07, 0.15), Color(0.55, 0.65, 1.0), 0.20, Color(0.30, 0.34, 0.55), 0.35],
]

var hour := 10.0
var weather := "clear"
var time_scale := 1.0

var _env: Environment = null
var _sky_mat: ProceduralSkyMaterial = null
var _sun: DirectionalLight3D = null
var _rain: GPUParticles3D = null
var _rain_audio: AudioStreamPlayer = null
var _weather_t := 200.0
var _cur_wet := 0.0
var _cur_rain := 0.0           # 0..1 (intensité lissée)
var _cur_cloud := 0.0          # 0..1 (assombrissement + brouillard)
var _cur_fog := 0.0
var _flash := 0.0
var _thunder_t := 8.0
var _apply_t := 0.0
var _flash_light_boost := 0.0

func _ready() -> void:
	add_to_group("environment")
	hour = fposmod(GameManager.world_hour, 24.0)
	weather = GameManager.world_weather if WEATHERS.has(GameManager.world_weather) else "clear"
	_cur_rain = _target_rain()
	_cur_cloud = _target_cloud()
	_cur_fog = _target_fog()
	_cur_wet = _cur_rain
	_build()
	_apply(true)

# ---------------------------------------------------------------- construction
func _build() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	_env = Environment.new()
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_curve = 0.18
	_sky_mat.ground_curve = 0.05
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var effects_enabled := bool(SettingsManager.get_value("graphics", "effects"))
	_env.fog_enabled = effects_enabled
	_env.fog_light_color = Color(0.7, 0.75, 0.82)
	_env.fog_density = 0.0015
	_env.glow_enabled = effects_enabled
	_env.glow_intensity = 0.5
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.1
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.add_to_group("sun")
	_sun.shadow_enabled = bool(SettingsManager.get_value("graphics", "shadows"))
	_sun.directional_shadow_max_distance = 80.0
	add_child(_sun)

	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 600 if effects_enabled else 180
	_rain.lifetime = 0.9
	_rain.preprocess = 0.9
	_rain.visibility_aabb = AABB(Vector3(-22, -14, -22), Vector3(44, 28, 44))
	_rain.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20.0, 0.5, 20.0)
	pm.direction = Vector3(0.12, -1.0, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 17.0
	pm.initial_velocity_max = 21.0
	pm.gravity = Vector3(0, -6.0, 0)
	_rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.018, 0.55)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.75, 0.82, 0.95, 0.38)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	rm.billboard_keep_scale = true
	qm.material = rm
	_rain.draw_pass_1 = qm
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)

	var rs := AudioManager.find_stream("rain_loop")
	if rs != null:
		_rain_audio = AudioStreamPlayer.new()
		_rain_audio.stream = rs
		_rain_audio.volume_db = -80.0
		_rain_audio.bus = "SFX"
		add_child(_rain_audio)
		_rain_audio.play()

# ---------------------------------------------------------------- API
func night_factor() -> float:
	## 0 = plein jour, 1 = nuit noire (lissé autour du coucher / lever du soleil).
	var h := hour
	var n := 0.0
	if h < 5.0 or h >= 21.0:
		n = 1.0
	elif h < 7.0:
		n = 1.0 - (h - 5.0) / 2.0
	elif h >= 19.0:
		n = (h - 19.0) / 2.0
	return clampf(n + _cur_cloud * 0.18, 0.0, 1.0)

func is_night() -> bool:
	return night_factor() > 0.55

func is_raining() -> bool:
	return weather == "rain" or weather == "storm"

func weather_label() -> String:
	return str(WEATHER_LABEL.get(weather, ""))

func clock_text() -> String:
	var hh := int(floor(hour))
	var mm := int(floor((hour - float(hh)) * 60.0))
	return "%02d:%02d" % [hh, mm]

func set_time(h: float) -> void:
	hour = fposmod(h, 24.0)
	GameManager.world_hour = hour
	_apply(true)

func set_weather(w: String) -> void:
	if not WEATHERS.has(w) or w == weather:
		return
	weather = w
	GameManager.world_weather = w
	_weather_t = randf_range(WEATHER_MIN, WEATHER_MAX)
	weather_changed.emit(w)

## Visibilité utile pour l'IA (police / gangs) : réduite par la pluie, la nuit et le brouillard (1.0 = normale).
func visibility_mult() -> float:
	return clampf(1.0 - 0.45 * night_factor() - 0.25 * _cur_rain - 0.35 * _cur_fog, 0.35, 1.0)

# ---------------------------------------------------------------- boucle
func _target_rain() -> float:
	return 1.0 if weather == "storm" else (0.6 if weather == "rain" else 0.0)

func _target_cloud() -> float:
	match weather:
		"storm":
			return 1.0
		"rain":
			return 0.75
		"cloudy":
			return 0.5
		"fog":
			return 0.55
	return 0.0

func _target_fog() -> float:
	return 1.0 if weather == "fog" else (0.35 if weather == "rain" or weather == "storm" else 0.0)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	hour = fposmod(hour + delta * 24.0 / DAY_SECONDS * time_scale, 24.0)
	GameManager.world_hour = hour
	_weather_t -= delta
	if _weather_t <= 0.0:
		_pick_next_weather()
	_cur_rain = move_toward(_cur_rain, _target_rain(), delta * 0.08)
	_cur_cloud = move_toward(_cur_cloud, _target_cloud(), delta * 0.07)
	_cur_fog = move_toward(_cur_fog, _target_fog(), delta * 0.06)
	_cur_wet = move_toward(_cur_wet, 1.0 if _cur_rain > 0.05 else 0.0, delta * (0.15 if _cur_rain > 0.05 else 0.02))
	if weather == "storm":
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(6.0, 16.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 2.2)).timeout.connect(func() -> void: AudioManager.play_sfx("thunder", "SFX"))
	_flash = maxf(0.0, _flash - delta * 3.0)
	_apply_t -= delta
	if _apply_t <= 0.0 or _flash > 0.0:
		_apply_t = 0.25
		_apply(false)
	_follow_camera()

func _pick_next_weather() -> void:
	_weather_t = randf_range(WEATHER_MIN, WEATHER_MAX)
	var roll := randf()
	var nw := "clear"
	if roll < 0.38:
		nw = "clear"
	elif roll < 0.60:
		nw = "cloudy"
	elif roll < 0.80:
		nw = "rain"
	elif roll < 0.90:
		nw = "fog"
	else:
		nw = "storm"
	if nw != weather:
		weather = nw
		GameManager.world_weather = nw
		weather_changed.emit(nw)

func _follow_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _rain == null or not _rain.is_inside_tree():
		return
	_rain.global_position = cam.global_position + Vector3(0, 9.0, 0)
	_rain.emitting = _cur_rain > 0.05
	_rain.amount_ratio = clampf(_cur_rain, 0.1, 1.0)
	if _rain_audio != null:
		_rain_audio.volume_db = linear_to_db(maxf(_cur_rain * 0.55, 0.0001)) if _cur_rain > 0.03 else -80.0

# ---------------------------------------------------------------- application visuelle
func _sample(col: int) -> Variant:
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i in KEYS.size() - 1:
		var k0: Array = KEYS[i]
		var k1: Array = KEYS[i + 1]
		if hour >= float(k0[0]) and hour <= float(k1[0]):
			a = k0
			b = k1
			break
	var span := maxf(float(b[0]) - float(a[0]), 0.001)
	var u := clampf((hour - float(a[0])) / span, 0.0, 1.0)
	var va: Variant = a[col]
	var vb: Variant = b[col]
	if va is Color:
		return (va as Color).lerp(vb as Color, u)
	return lerpf(float(va), float(vb), u)

func _apply(force: bool) -> void:
	if _env == null or _sky_mat == null:
		return
	var top: Color = _sample(1)
	var hor: Color = _sample(2)
	var sun_col: Color = _sample(3)
	var sun_e: float = _sample(4)
	var amb: Color = _sample(5)
	var amb_e: float = _sample(6)
	var grey := Color(0.5, 0.52, 0.56).lerp(Color(0.12, 0.13, 0.16), night_factor())
	var cl := _cur_cloud
	top = top.lerp(grey, cl * 0.8)
	hor = hor.lerp(grey, cl * 0.9)
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = hor
	_sky_mat.ground_horizon_color = hor.darkened(0.15)
	_sky_mat.ground_bottom_color = hor.darkened(0.55)
	_sky_mat.sun_angle_max = 30.0 if cl < 0.6 else 1.0
	_env.ambient_light_color = amb.lerp(grey, cl * 0.5)
	_env.ambient_light_energy = amb_e * (1.0 - 0.15 * cl) + _flash * 1.4
	# soleil le jour, « lune » la nuit : même lumière, orientation et couleur différentes
	var day_u := clampf((hour - 6.0) / 12.0, 0.0, 1.0)           # 6 h -> 0, 18 h -> 1
	var elev := sin(day_u * PI)                                   # 0..1..0
	var is_day := hour >= 5.5 and hour <= 19.5
	if is_day:
		_sun.rotation_degrees = Vector3(-(8.0 + 62.0 * elev), -70.0 + 140.0 * day_u, 0.0)
	else:
		var nh := fposmod(hour - 19.5, 24.0) / 10.0               # 0 -> 1 pendant la nuit
		_sun.rotation_degrees = Vector3(-(20.0 + 40.0 * sin(clampf(nh, 0.0, 1.0) * PI)), 110.0 - 100.0 * clampf(nh, 0.0, 1.0), 0.0)
	_sun.light_color = sun_col
	_sun.light_energy = sun_e * (1.0 - 0.7 * cl) + _flash * 2.0
	var fog_d := 0.0012 + 0.006 * _cur_fog + 0.002 * _cur_rain
	_env.fog_density = fog_d
	_env.fog_light_color = hor.lerp(grey, 0.5)
	_env.fog_sun_scatter = 0.1 if is_day and cl < 0.5 else 0.0
	CityBuilder.set_night(night_factor())
	CityBuilder.set_wet(_cur_wet)
	if force:
		_update_headlights()
	else:
		_headlight_t_tick()

var _hl_t := 0.0
func _headlight_t_tick() -> void:
	_hl_t -= 0.25
	if _hl_t <= 0.0:
		_hl_t = 1.0
		_update_headlights()

## Phares : seulement ceux des voitures à moins de 45 m de la caméra (le rendu mobile limite le nombre de lumières par objet).
func _update_headlights() -> void:
	var on := night_factor() > 0.35 or _cur_rain > 0.4 or _cur_fog > 0.5
	var cam := get_viewport().get_camera_3d()
	for n in get_tree().get_nodes_in_group("headlight"):
		var l := n as Light3D
		if l != null:
			l.visible = on and (cam == null or l.global_position.distance_to(cam.global_position) < 45.0)
