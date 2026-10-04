extends Node
## Voix des PNJ (v14) : réplique courte selon l'activité (marche, attente, fuite, coup reçu, combat).
## Deux canaux : (1) bulle de texte 3D au-dessus du PNJ, toujours affichée ; (2) synthèse vocale du téléphone
## (DisplayServer.tts_*), voix française choisie d'après le personnage. Sans moteur vocal installé, seule la bulle s'affiche.
## [NON TESTÉ SUR APPAREIL]

const LINES := {
	"walk": ["Belle journée, non ?", "Il fait frais ce soir.", "Je dois rentrer.", "Quelle ville agitée…", "J'ai rendez-vous dans dix minutes."],
	"idle": ["Je t'attends depuis une heure…", "Allô ? Oui, je suis en route.", "Où est-ce qu'il est passé ?", "Un peu de calme enfin."],
	"flee": ["Au secours !", "Appelez la police !", "Ne me faites pas de mal !", "Courez !"],
	"hurt": ["Aïe !", "Arrête !", "Ça fait mal !"],
	"enemy": ["Je t'ai vu !", "Reste où tu es !", "Il est là, tirez !", "Tu n'iras pas loin."],
	"enemy_hurt": ["Argh !", "Il m'a touché !"],
	"police": ["Police ! Ne bougez plus !", "Jetez votre arme !", "Suspect en vue !", "Rendez-vous, c'est fini !"],
	"police_calm": ["Circulez.", "R.A.S. dans le secteur.", "Tout est calme."],
	"gang": ["Tu cherches quoi, toi ?", "C'est notre quartier.", "Fais pas le malin.", "On t'a déjà vu ici."],
	"gang_warn": ["Dégage d'ici !", "T'as rien à faire ici !", "Un pas de plus et...", "Tu t'es perdu ?"],
	"dealer": ["Pas de témoins.", "Circule, on bosse.", "Passe ton chemin.", "Rien à voir ici."],
}

var _t := 3.0
var _voices: PackedStringArray = PackedStringArray()
var _next: Dictionary = {}

func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = randf_range(3.0, 5.5)
	if not GameManager.in_game or get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var best: Node3D = null
	var bd := 14.0
	for n in NPCManager.npcs:
		if not is_instance_valid(n) or bool(n.get("dead")):
			continue
		var d := (n as Node3D).global_position.distance_to(player.global_position)
		if d < bd and float(_next.get(n.get_instance_id(), 0.0)) <= now:
			bd = d
			best = n
	if best != null:
		say(best, _category(best))

func _category(n: Node) -> String:
	if n.is_in_group("police"):
		return "police" if CrimeManager.is_wanted() else "police_calm"
	if n.is_in_group("gang"):
		return "gang"
	if n.is_in_group("dealer"):
		return "dealer"
	if n.is_in_group("enemy"):
		return "enemy"
	var st := int(n.get("state")) if n.get("state") != null else 0
	if st == CivilianController.S.FLEE:
		return "flee"
	if st == CivilianController.S.IDLE:
		return "idle"
	return "walk"

## Appelé par NPCActor.take_damage : réaction vocale à un coup.
func react(n: Node3D) -> void:
	if not is_instance_valid(n) or randf() > 0.6:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if float(_next.get(n.get_instance_id(), 0.0)) > now + 6.0:
		return
	say(n, "enemy_hurt" if (n.is_in_group("enemy") or n.is_in_group("police") or n.is_in_group("gang") or n.is_in_group("dealer")) else "hurt")

func say(n: Node3D, cat: String) -> void:
	var lines: Array = LINES.get(cat, [])
	if lines.is_empty() or not is_instance_valid(n):
		return
	var text: String = lines[randi() % lines.size()]
	_next[n.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + randf_range(9.0, 16.0)
	_bubble(n, text)
	_speak(n, text)

func _bubble(n: Node3D, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.0045
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	var h := float(n.get("height")) if n.get("height") != null else 1.75
	l.position = Vector3(0, h + 0.45, 0)
	n.add_child(l)
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())

func _speak(n: Node3D, text: String) -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if _voices.is_empty():
		_voices = DisplayServer.tts_get_voices_for_language("fr")
	if _voices.is_empty() or DisplayServer.tts_is_speaking():
		return
	var vol := clampf(float(SettingsManager.get_value("audio", "voice")) * float(SettingsManager.get_value("audio", "master")), 0.0, 1.0)
	if vol <= 0.01:
		return
	var cid := ""
	var v: Variant = n.get("char_id")
	if v != null:
		cid = str(v)
	var pitch := 0.85 + float(absi(hash(cid)) % 20) / 100.0
	if cid.contains("enfant") or cid.contains("fille_queue"):
		pitch = 1.6
	elif cid.contains("ado"):
		pitch = 1.2
	elif cid.contains("femme") or cid.contains("fille"):
		pitch = 1.25
	var ent: Dictionary = GameManager.character_entry(cid)
	if str(ent.get("age", "adulte")) == "adulte":
		pitch = 1.25 if str(ent.get("gender", "m")) == "f" else (0.8 if cid == "mx_brute" else pitch)
	var vid := _voices[absi(hash(cid)) % _voices.size()]
	DisplayServer.tts_speak(text, vid, int(vol * 100.0), pitch, 1.0, 0, false)
