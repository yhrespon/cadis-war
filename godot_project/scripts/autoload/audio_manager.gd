extends Node
## Bus audio séparés + lecture de sons. Les fichiers sont cherchés dans res://audio/<nom>.(ogg|wav|mp3).
## Fichier absent = SILENCE (aucun faux fichier n'est fourni). Voir audio/LISEZMOI.txt pour les noms attendus.

const BUS_TREE := {
	"Music": "Master", "MusicMenu": "Music", "MusicExplore": "Music", "MusicCombat": "Music",
	"SFX": "Master", "Shots": "SFX", "Reload": "SFX", "Impacts": "SFX", "Steps": "SFX", "Vehicles": "SFX",
	"UI": "Master", "Voice": "Master", "Dialogue": "Voice",
}
const EXTS: Array = [".ogg", ".wav", ".mp3"]

var missing: Dictionary = {}
var _cache: Dictionary = {}
var _pool3d: Array = []
var _pool2d: Array = []
var _music: AudioStreamPlayer
var _music_name := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in BUS_TREE:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_TREE[bus_name])
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 80.0
		add_child(p)
		_pool3d.append(p)
	for i in 6:
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		_pool2d.append(p2)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(func() -> void: _music.play())      # boucle de secours si le fichier n'a pas de marqueur de boucle

## group : master | music | sfx | voice (valeur linéaire 0..1). "ui" suit sfx.
func set_group_volume(group: String, v: float) -> void:
	var names: Array = []
	match group:
		"master": names = ["Master"]
		"music": names = ["Music"]
		"sfx": names = ["SFX", "UI"]
		"voice": names = ["Voice"]
	for n in names:
		var idx := AudioServer.get_bus_index(n)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, -80.0 if v <= 0.001 else linear_to_db(v))
			AudioServer.set_bus_mute(idx, v <= 0.001)

func find_stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var st: AudioStream = null
	for e in EXTS:
		var path := "res://audio/%s%s" % [sound, e]
		if ResourceLoader.exists(path):
			st = load(path) as AudioStream
			break
	if st == null:
		missing[sound] = true
	_cache[sound] = st
	return st

func play_ui(sound: String) -> void:
	_play_2d(sound, "UI")

func play_sfx(sound: String, bus := "SFX", pos: Variant = null, volume_db := 0.0) -> void:
	var st := find_stream(sound)
	if st == null:
		return
	if pos is Vector3:
		var p := _free_player(_pool3d) as AudioStreamPlayer3D
		if p == null:
			return
		p.stream = st
		p.bus = bus
		p.volume_db = volume_db
		p.global_position = pos
		p.play()
	else:
		_play_2d(sound, bus, volume_db)

func _play_2d(sound: String, bus: String, volume_db := 0.0) -> void:
	var st := find_stream(sound)
	if st == null:
		return
	var p := _free_player(_pool2d) as AudioStreamPlayer
	if p == null:
		return
	p.stream = st
	p.bus = bus
	p.volume_db = volume_db
	p.play()

func _free_player(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	return null

## Musique : track = menu | explore | combat (bus dédiés). Fondu enchaîné simple.
func play_music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	var st := find_stream("music_" + track)
	var bus := "Music" + track.capitalize()
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, 0.4)
	tw.tween_callback(func() -> void:
		_music.stop()
		if st != null:
			_music.stream = st
			_music.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Music"
			_music.play())
	if st != null:
		tw.tween_property(_music, "volume_db", 0.0, 0.6)

## Boucle 3D rattachée à un nœud (moteur de véhicule...). Retourne null si le fichier n'existe pas.
func make_loop_3d(sound: String, bus: String) -> AudioStreamPlayer3D:
	var st := find_stream(sound)
	if st == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = bus
	p.max_distance = 60.0
	return p
