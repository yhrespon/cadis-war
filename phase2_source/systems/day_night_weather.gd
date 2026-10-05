extends Node3D
## Cycle jour/nuit léger et météo de base pour la vertical slice.

@export var time_of_day: float = 9.0
@export var cycle_duration_seconds: float = 900.0
@export var cycle_enabled: bool = true
@export var weather: String = "clear"

var sun: DirectionalLight3D
var rain: GPUParticles3D
var rain_audio: AudioStreamPlayer
var world_environment: WorldEnvironment

func _ready() -> void:
	world_environment = get_parent().get_node_or_null("WorldEnvironment")
	_create_sun()
	_create_rain()
	_create_rain_audio()
	_apply_weather(weather)
	_update_lighting()

func _process(delta: float) -> void:
	if cycle_enabled:
		time_of_day = fmod(time_of_day + delta * 24.0 / cycle_duration_seconds, 24.0)
		_update_lighting()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_1: set_weather("clear")
		KEY_2: set_weather("rain")
		KEY_3: set_weather("storm")

func _create_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "DynamicSun"
	sun.light_color = Color(1.0, 0.91, 0.76)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

func _create_rain() -> void:
	rain = GPUParticles3D.new()
	rain.name = "RainParticles"
	rain.amount = 1200
	rain.lifetime = 1.2
	rain.visibility_aabb = AABB(Vector3(-80, -25, -80), Vector3(160, 60, 160))
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(70, 1, 70)
	process_material.direction = Vector3(0, -1, 0)
	process_material.initial_velocity_min = 28.0
	process_material.initial_velocity_max = 38.0
	process_material.gravity = Vector3(0, -12, 0)
	var rain_mesh := BoxMesh.new()
	rain_mesh.size = Vector3(0.018, 0.7, 0.018)
	var rain_material := StandardMaterial3D.new()
	rain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_material.albedo_color = Color(0.55, 0.72, 1.0, 0.38)
	rain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mesh.material = rain_material
	rain.process_material = process_material
	rain.draw_pass_1 = rain_mesh
	rain.position = Vector3(0, 22, 0)
	rain.emitting = false
	add_child(rain)

func _create_rain_audio() -> void:
	rain_audio = AudioStreamPlayer.new()
	rain_audio.name = "RainWindAudio"
	rain_audio.stream = load("res://audio/ambience/rain_wind_loop.mp3") as AudioStream
	rain_audio.volume_db = -14.0
	rain_audio.autoplay = false
	add_child(rain_audio)

func _update_lighting() -> void:
	var daylight := clampf(sin((time_of_day - 6.0) / 12.0 * PI), 0.0, 1.0)
	sun.rotation_degrees = Vector3((time_of_day / 24.0) * 360.0 - 90.0, -35.0, 0.0)
	sun.light_energy = lerpf(0.12, 2.2, daylight)
	sun.light_color = Color(1.0, 0.55, 0.30).lerp(Color(1.0, 0.94, 0.82), daylight)
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.ambient_light_energy = lerpf(0.16, 0.8, daylight)

func set_weather(next_weather: String) -> void:
	weather = next_weather
	_apply_weather(weather)

func _apply_weather(current_weather: String) -> void:
	if rain == null:
		return
	rain.emitting = current_weather == "rain" or current_weather == "storm"
	if rain_audio != null:
		if rain.emitting and not rain_audio.playing:
			rain_audio.play()
		elif not rain.emitting:
			rain_audio.stop()
	if current_weather == "storm":
		rain.amount = 2200
		rain.lifetime = 0.9
	else:
		rain.amount = 1200
		rain.lifetime = 1.2
