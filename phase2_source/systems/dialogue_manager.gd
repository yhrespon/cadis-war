extends Node
## Gestionnaire simple de dialogues : sous-titres toujours disponibles, voix si le fichier existe.

var layer: CanvasLayer
var panel: PanelContainer
var label: Label
var audio: AudioStreamPlayer
var hide_timer: Timer

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.name = "DialogueLayer"
	add_child(layer)
	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.78
	panel.anchor_bottom = 0.94
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	label = Label.new()
	label.name = "Subtitle"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	panel.add_child(label)
	audio = AudioStreamPlayer.new()
	audio.name = "VoicePlayer"
	add_child(audio)
	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_hide_subtitle)
	add_child(hide_timer)
	_hide_subtitle()

func play_line(text: String, voice_path: String = "", duration: float = 5.0) -> void:
	label.text = text
	panel.show()
	hide_timer.start(duration)
	if voice_path.is_empty():
		return
	var stream := load(voice_path) as AudioStream
	if stream != null:
		audio.stream = stream
		audio.play()

func _hide_subtitle() -> void:
	if panel != null:
		panel.hide()
