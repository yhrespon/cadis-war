class_name Hud
extends CanvasLayer
## HUD réel : vie, armure, argent, arme + chargeur/réserve, rechargement, objectif + distance + chrono, invite d'interaction,
## réticule (armes à feu), chiffres de dégâts (projetés à l'écran), marqueur de touche, flash de dégâts, vitesse en véhicule, minimap.
## Tout vient de l'état réel (Player, InventoryManager, GameManager, MissionManager, WorldManager) : rien n'est codé en dur.
## Dessiné par code dans un seul Control (peu de noeuds, adapté mobile). Résolution de base 1280x720 (stretch canvas_items). [NON TESTÉ SUR APPAREIL]

const MARGIN := 24.0
const GOLD := Color(1.0, 0.85, 0.3)

var player: Player = null
var _panel: Control
var _map: Minimap
var _prompt := ""
var _hurt_t := 0.0
var _hit_t := 0.0
var _hit_head := false
var _last_hp := 100.0
var _acc := 0.0
var _numbers: Array = []        # {pos: Vector3, text: String, head: bool, age: float}
var _zone := ""
var _zone_t := 0.0

func _ready() -> void:
	layer = 5                       # sous les boutons tactiles (calque 10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_hud)
	add_child(_panel)
	_map = Minimap.new()
	_panel.add_child(_map)

func setup(p: Player) -> void:
	player = p
	_map.player = p
	_last_hp = p.health
	p.health_changed.connect(_on_health)
	p.prompt_changed.connect(func(t: String) -> void: _prompt = t)
	p.hud_damage_number.connect(_on_damage_number)

func _on_health() -> void:
	if player.health < _last_hp - 0.5:
		_hurt_t = 0.45
	_last_hp = player.health

func _on_damage_number(pos: Vector3, amount: float, head: bool) -> void:
	_numbers.append({"pos": pos, "text": str(int(round(amount))), "head": head, "age": 0.0})
	if _numbers.size() > 12:
		_numbers.pop_front()
	_hit_t = 0.2
	_hit_head = head

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_hit_t = maxf(0.0, _hit_t - delta)
	for n in _numbers:
		n["age"] = float(n["age"]) + delta
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return float(n["age"]) < 0.9)
	var z := WorldManager.sector_name_at(player.global_position)
	if z != _zone:
		_zone = z
		_zone_t = 3.0
	_zone_t = maxf(0.0, _zone_t - delta)
	# mise en page de la minimap (toujours carrée, ~26 % de la hauteur)
	var vp := _panel.size
	var s := clampf(vp.y * 0.26, 150.0, 230.0)
	_map.size = Vector2(s, s)
	_map.position = Vector2(vp.x - s - MARGIN, MARGIN)
	_acc += delta
	var busy := not _numbers.is_empty() or _hurt_t > 0.0 or _hit_t > 0.0 or player.health < player.max_health * 0.3
	if busy or _acc >= 0.1:
		_acc = 0.0
		_panel.queue_redraw()

func _text(s: String, pos: Vector2, size: int, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	_panel.draw_string_outline(font, pos, s, align, width, size, 5, Color(0, 0, 0, 0.9))
	_panel.draw_string(font, pos, s, align, width, size, color)

func _bar(pos: Vector2, w: float, h: float, ratio: float, color: Color) -> void:
	_panel.draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.55))
	_panel.draw_rect(Rect2(pos + Vector2(2, 2), Vector2(maxf(0.0, (w - 4.0) * clampf(ratio, 0.0, 1.0)), h - 4.0)), color)
	_panel.draw_rect(Rect2(pos, Vector2(w, h)), Color(1, 1, 1, 0.5), false, 1.5)

func _draw_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	var vp := _panel.size
	# --- flash de dégâts / faible vie
	var vig := 0.0
	if _hurt_t > 0.0:
		vig = _hurt_t / 0.45 * 0.35
	if player.health < player.max_health * 0.3 and not player.dead:
		vig = maxf(vig, 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.008))
	if vig > 0.0:
		var t := 38.0
		var c := Color(0.85, 0.0, 0.0, vig)
		_panel.draw_rect(Rect2(0, 0, vp.x, t), c)
		_panel.draw_rect(Rect2(0, vp.y - t, vp.x, t), c)
		_panel.draw_rect(Rect2(0, t, t, vp.y - 2.0 * t), c)
		_panel.draw_rect(Rect2(vp.x - t, t, t, vp.y - 2.0 * t), c)
	# --- vie / armure / argent / arme (haut gauche)
	var x := MARGIN
	var y := MARGIN
	var hp_ratio := player.health / player.max_health
	_bar(Vector2(x, y), 240, 20, hp_ratio, Color(0.25, 0.8, 0.35) if hp_ratio > 0.3 else Color(0.9, 0.25, 0.2))
	_text("%d" % int(ceil(player.health)), Vector2(x + 8, y + 17), 16)
	if InventoryManager.armor > 0.0:
		_bar(Vector2(x, y + 24), 240, 10, InventoryManager.armor / 100.0, Color(0.35, 0.7, 1.0))
	_text("%d $" % GameManager.money, Vector2(x, y + 62), 24, GOLD)
	var wid := InventoryManager.equipped
	var wd := WeaponManager.get_def(wid)
	var wtxt := "Mains nues"
	if wd != null:
		wtxt = wd.display_name
		if not wd.melee:
			wtxt += "   %d / %d" % [InventoryManager.mag_for(wid), InventoryManager.reserve_for(wid)]
	_text(wtxt, Vector2(x, y + 92), 22)
	if player.combat != null and player.combat.is_reloading():
		_text("RECHARGEMENT...", Vector2(x, y + 118), 18, Color(1, 0.7, 0.3))
	var kits := int(InventoryManager.items.get("heal_kit", 0))
	if kits > 0:
		_text("Soins x%d" % kits, Vector2(x, y + 142), 16, Color(0.6, 1, 0.7))
	# --- objectif (haut centre)
	if MissionManager.active_id != "":
		var mid := vp.x * 0.5
		var line := MissionManager.objective_text()
		var op := MissionManager.objective_position()
		if op != Vector3.INF:
			var d := Vector2(op.x - player.global_position.x, op.z - player.global_position.z).length()
			line += "  ·  %d m" % int(round(d))
		_text(line, Vector2(mid - 330.0, MARGIN + 22), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 660.0)
		var md := MissionManager.def_of(MissionManager.active_id)
		if md != null:
			_text(md.title, Vector2(mid - 330.0, MARGIN + 48), 15, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 660.0)
		if MissionManager.time_left > 0.0:
			var tl := int(ceil(MissionManager.time_left))
			_text("%d:%02d" % [int(tl / 60.0), tl % 60], Vector2(mid - 60.0, MARGIN + 82), 28, Color(1, 0.5, 0.4) if tl <= 30 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 120.0)
	# --- zone (sous la minimap, 3 s à chaque changement)
	if _zone_t > 0.0:
		_text(_zone, Vector2(vp.x - MARGIN - 330.0, MARGIN + _map.size.y + 24.0), 18, Color(1, 1, 1, clampf(_zone_t, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_RIGHT, 330.0)
	# --- réticule (armes à feu, à pied) / marqueur de touche
	var ranged := wd != null and not wd.melee
	var ctr := vp * 0.5      # centre exact : le tir (PlayerCombat.shoot) passe par ce point via cam.project_ray_origin/normal (h_offset inclus)
	if ranged and player.driving == null and not player.dead:
		var gap := 6.0 + (-4.0 if player.aiming else 0.0)
		var rc := Color(1, 1, 1, 0.85)
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_panel.draw_line(ctr + dir * gap, ctr + dir * (gap + 9.0), rc, 2.0)
		_panel.draw_circle(ctr, 1.5, rc)
	if _hit_t > 0.0:
		var hc := Color(1, 0.2, 0.2, 0.95) if _hit_head else Color(1, 1, 1, 0.95)
		for dd in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_panel.draw_line(ctr + dd * 8.0, ctr + dd * 15.0, hc, 2.5)
	# --- chiffres de dégâts
	for n in _numbers:
		if is_instance_valid(player.cam) and not player.cam.is_position_behind(n["pos"]):
			var sp := player.cam.unproject_position(n["pos"]) + Vector2(0, -float(n["age"]) * 50.0)
			var col := Color(1, 0.3, 0.25) if n["head"] else Color(1, 0.95, 0.6)
			col.a = 1.0 - float(n["age"]) / 0.9
			_text(str(n["text"]) + ("!" if n["head"] else ""), sp, 24 if n["head"] else 20, col, HORIZONTAL_ALIGNMENT_CENTER, 80.0)
	# --- invite d'interaction (au-dessus des boutons tactiles)
	if _prompt != "" and not player.dead:
		var key := "ACTION" if DisplayServer.is_touchscreen_available() else "E"
		_text("[%s]  %s" % [key, _prompt], Vector2(vp.x * 0.5 - 300.0, vp.y - 210.0), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 600.0)
	# --- vitesse en véhicule
	if player.driving != null:
		var kmh := int(round(absf(player.driving.speed) * 3.6))
		_text("%d km/h" % kmh, Vector2(vp.x * 0.5 - 100.0, vp.y - 120.0), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	# --- mort
	if player.dead:
		_panel.draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45))
		_text("VOUS ÊTES MORT", Vector2(vp.x * 0.5 - 300.0, vp.y * 0.5), 48, Color(1, 0.3, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 600.0)
