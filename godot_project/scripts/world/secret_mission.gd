class_name SecretMission
extends Node
## MISSION SECRÈTE — infiltration chronométrée sur le site data/cities/secret_site.tres (3x3 blocs).
## Déroulé : (1) voler le dossier au centre (poi « depot »), (2) rejoindre la sortie (poi « far_a ») avant la fin du temps. 6 gardes (3 postes de 2) en mode
## infiltration (EnemyController.stealth : portée 16 m, cône 70°, ligne de vue, ouïe) ; un garde qui vous repère donne l'alerte (MissionManager.alert_raised),
## ses voisins < 25 m passent en combat. Mort, abandon ou temps écoulé = échec.
## Score = 1000 + 10 × secondes restantes + 1500 si aucune alerte − 250 × alertes (jamais < 0). Meilleur score : GameManager.secret_best_score (sauvegardé).
## Utilise MissionManager.start_custom : objectif/chrono/flèche du HUD réels ; rien n'est ajouté à la progression de l'histoire. [NON TESTÉ DANS GODOT]

const MISSION_ID := "secret_run"
const TIME_LIMIT := 180.0
const POSTS := ["hideout_a", "hideout_b", "hideout_c"]

var player: Player = null
var alerts := 0
var _over := false

func start(p: Player) -> void:
	player = p
	var def := MissionDef.new()
	def.id = MISSION_ID
	def.title = "Mission secrète : le dossier"
	def.category = "secret"
	def.mission_type = "infiltration chronométrée"
	def.city = "secret_site"
	def.time_limit = TIME_LIMIT
	def.fail_on_death = true
	def.reward_money = 0
	def.objectives = [
		{"type": "collect", "poi": "depot", "items": 1, "item_name": "Dossier confidentiel", "spread": 3.0, "text": "Volez le dossier au centre du site"},
		{"type": "goto", "poi": "far_a", "radius": 4.5, "text": "Rejoignez la sortie"}]
	MissionManager.mission_completed.connect(_on_completed)
	MissionManager.mission_failed.connect(_on_failed)
	MissionManager.alert_raised.connect(_on_alert)
	var sp: Node = MissionManager.spawner
	if sp == null:
		push_error("SecretMission : spawner absent")
		return
	for poi in POSTS:
		sp.spawn_enemies(2, WorldManager.poi_position(poi), "pistol", "secret_guard", {"stealth": true})
	if not MissionManager.start_custom(def):
		push_error("SecretMission : une mission est déjà active")
	UIManager.toast("Évitez les gardes. Volez le dossier, puis fuyez.", Color(1, 0.85, 0.3), 4.0)

func _exit_tree() -> void:
	MissionManager.drop_custom()

func _on_alert() -> void:
	if _over:
		return
	alerts += 1
	UIManager.toast("ALERTE !", Color(1, 0.4, 0.4), 2.0)

func _on_completed(id: String) -> void:
	if id != MISSION_ID or _over:
		return
	_over = true
	var left := maxf(MissionManager.time_left, 0.0)
	var bonus := 1500 if alerts == 0 else 0
	var score := maxi(0, 1000 + int(left) * 10 + bonus - alerts * 250)
	var best := GameManager.secret_best_score
	var new_best := score > best
	if new_best:
		GameManager.secret_best_score = score
		SaveManager.save_profile()
	var detail: Array = ["Score : %d" % score, "Temps restant : %d s" % int(left), "Alertes : %d%s" % [alerts, "  (bonus discrétion +1500)" if alerts == 0 else ""],
		"Meilleur score : %d%s" % [maxi(score, best), "  — NOUVEAU RECORD" if new_best else ""]]
	_show.call_deferred("Mission secrète", detail, true)

func _on_failed(id: String, reason: String) -> void:
	if id != MISSION_ID or _over:
		return
	_over = true
	_show.call_deferred("Mission secrète", [reason, "Alertes : %d" % alerts, "Meilleur score : %d" % GameManager.secret_best_score], false)

func _show(title: String, detail: Array, success: bool) -> void:
	if not is_inside_tree():
		return
	if BasePanel._active != null and is_instance_valid(BasePanel._active):
		BasePanel._active.close()
	ResultUI.open(get_tree().current_scene, title, detail, success, func() -> void: GameManager.start_secret_mission())
