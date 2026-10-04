extends Node
## Réseau online C.A.D.I.S WARS : salons par code, matchmaking et fallback IA.
## Le serveur Railway est prioritaire ; en cas d’échec, la recherche démarre un duel local IA.

signal status_changed(text: String)
signal room_changed(room: Dictionary)
signal match_started(match: Dictionary)
signal profile_changed(profile: Dictionary, leaderboard: Array)
signal clan_created(clan: Dictionary)
signal remote_state_received(player_id: String, state: Dictionary)
signal game_event_received(player_id: String, event: String, data: Variant)

const DEFAULT_HTTP := "https://cadis-war.up.railway.app"
const DEFAULT_WS := "wss://cadis-war.up.railway.app/ws"
const INTERNAL_HTTP := "http://127.0.0.1:3000"
const INTERNAL_WS := "ws://127.0.0.1:3000/ws"
const FALLBACK_DELAY := 6.0

var server_http := DEFAULT_HTTP
var server_ws := DEFAULT_WS
var player_name := "Joueur"
var player_id := ""
var room: Dictionary = {}
var last_profile: Dictionary = {"wins": 0, "losses": 0, "rewards": 0}
var last_leaderboard: Array = []
var socket: WebSocketPeer
var _http: HTTPRequest
var _pending_action: Dictionary = {}
var _fallback_timer := 0.0
var _state_tick := 0.0
var _search_mode := ""
var _connected := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_name = "Joueur-%04d" % (absi(hash(str(Time.get_unix_time_from_system()))) % 10000)
	if SettingsManager != null:
		var saved := str(SettingsManager.get_value("online", "server_url")) if "online" in SettingsManager.data else ""
		if not saved.is_empty():
			server_http = saved

func _process(delta: float) -> void:
	if socket == null:
		if not _pending_action.is_empty() and _pending_action.get("type", "") == "search":
			_fallback_timer += delta
			if _fallback_timer >= FALLBACK_DELAY:
				_start_ai_fallback(_search_mode)
		return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			status_changed.emit("Connecté au serveur online")
			socket.send_text(JSON.stringify({"type": "connect", "code": room.get("code", ""), "playerId": player_id}))
			_run_pending()
			while socket.get_available_packet_count() > 0:
				_handle_message(socket.get_packet().get_string_from_utf8())
			_state_tick += delta
			if _state_tick >= 0.05:
				_state_tick = 0.0
				_send_local_state()
	elif socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if _connected:
			status_changed.emit("Serveur indisponible — mode IA local disponible")
		_connected = false
		if not _pending_action.is_empty() and _pending_action.get("type", "") == "search":
			_fallback_timer += delta
			if _fallback_timer >= FALLBACK_DELAY:
				_start_ai_fallback(_search_mode)

func connect_server(url := "") -> void:
	if not str(url).is_empty():
		server_ws = str(url)
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	socket = WebSocketPeer.new()
	_connected = false
	var err := socket.connect_to_url(server_ws)
	if err != OK:
		status_changed.emit("Connexion impossible — mode IA local disponible")
		_fallback_timer = FALLBACK_DELAY
	else:
		status_changed.emit("Connexion au serveur…")

func _request_room(path: String, payload: Dictionary) -> void:
	if _http != null and is_instance_valid(_http):
		_http.queue_free()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_room_request_completed)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var err := _http.request(server_http + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		status_changed.emit("Connexion impossible — vérifie le serveur")

func _on_room_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 200 or response_code >= 300 or not parsed is Dictionary or not parsed.get("success", true):
		status_changed.emit("Online : salon introuvable ou serveur indisponible")
		return
	player_id = str(parsed.get("player", {}).get("id", ""))
	room = parsed.get("room", {})
	room_changed.emit(room)
	status_changed.emit("Salon %s — connexion…" % str(room.get("code", "")))
	if socket != null:
		socket.close()
	socket = WebSocketPeer.new()
	_connected = false
	socket.connect_to_url(server_ws)

func disconnect_server() -> void:
	if socket != null:
		socket.close()
	_connected = false

func create_room(mode: String, max_players := 2) -> void:
	_request_room("/rooms", {"name": player_name, "mode": mode, "maxPlayers": clampi(max_players, 2, 6)})

func join_room(code: String) -> void:
	_request_room("/rooms/join", {"name": player_name, "code": code.strip_edges().to_upper()})

func set_ready(value := true) -> void:
	_queue_or_send({"type": "ready", "ready": value})

func start_room() -> void:
	_queue_or_send({"type": "start_game"})

func search_player(mode := "solo_duel") -> void:
	_search_mode = mode
	_fallback_timer = 0.0
	_pending_action = {"type": "search", "mode": mode}
	status_changed.emit("Recherche d’un joueur…")

func submit_result(won: bool, reward := 0) -> void:
	_queue_or_send({"type": "result", "won": won, "reward": reward})

func send_game_event(event_name: String, data: Variant = null) -> void:
	_queue_or_send({"type": "game_event", "event": event_name, "data": data})

func _send_local_state() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var state := {"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z,
		"rx": player.rotation.x, "ry": player.rotation.y, "rz": player.rotation.z}
	if player is CharacterBody3D:
		var body := player as CharacterBody3D
		state["vx"] = body.velocity.x
		state["vy"] = body.velocity.y
		state["vz"] = body.velocity.z
	_send({"type": "player_state", "state": state})

func create_clan(name: String, tag: String) -> void:
	_queue_or_send({"type": "clan_create", "name": name, "tag": tag})

func _queue_or_send(message: Dictionary) -> void:
	_pending_action = message
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		connect_server()
	else:
		_send(message)

func _run_pending() -> void:
	if _pending_action.is_empty():
		return
	var action := _pending_action
	_pending_action = {}
	_send(action)

func _send(message: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))

func _handle_message(raw: String) -> void:
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return
	var msg: Dictionary = parsed
	match str(msg.get("type", "")):
		"connected", "player_joined", "player_ready", "player_connection", "host_changed":
			room = msg.get("room", room)
			room_changed.emit(room)
			status_changed.emit("Salon %s — %d/%d joueurs" % [room.get("code", ""), room.get("players", []).size(), room.get("maxPlayers", 2)])
			if str(msg.get("type", "")) == "connected":
				_send({"type": "ready", "ready": true})
		"game_started":
			room = msg.get("room", room)
			match_started.emit({"type": "match_start", "room": room, "botFallback": false})
			status_changed.emit("Match lancé : %s" % str(room.get("mode", "duel")))
		"profile":
			last_profile = msg.get("profile", last_profile)
			last_leaderboard = msg.get("leaderboard", [])
			profile_changed.emit(last_profile, last_leaderboard)
		"clan":
			clan_created.emit(msg.get("clan", {}))
		"player_state":
			remote_state_received.emit(str(msg.get("playerId", "")), msg.get("state", {}))
		"game_event":
			game_event_received.emit(str(msg.get("playerId", "")), str(msg.get("event", "")), msg.get("data", null))
		"error":
			status_changed.emit("Online : " + str(msg.get("error", "Erreur inconnue")))
		"pong":
			pass

func _start_ai_fallback(mode: String) -> void:
	_pending_action = {}
	var fake_room := {"code": "IA-%04d" % (randi() % 10000), "mode": mode, "maxPlayers": 2, "players": [{"id": player_id, "name": player_name, "ready": true, "bot": false, "team": 0}, {"id": "bot-local", "name": "Éclaireur IA", "ready": true, "bot": true, "team": 1}]}
	room = fake_room
	status_changed.emit("Aucun joueur trouvé — adversaire IA local (mode hors-ligne)")
	match_started.emit({"type": "match_start", "room": fake_room, "botFallback": true, "teams": [{"id": player_id, "team": 0}, {"id": "bot-local", "team": 1}]})
