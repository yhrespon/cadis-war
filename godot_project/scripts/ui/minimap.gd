class_name Minimap
extends Control
## Minimap RÉELLE : blocs de la ville (WorldManager.block_rects_near), ennemis (groupe "enemy"), véhicules (groupe "vehicle"),
## objets de mission (MissionItem), point d'objectif (MissionManager.objective_position, bord de carte si hors portée).
## Orientée selon la caméra du joueur (haut de la carte = direction de vue). Redessinée à 15 Hz. [NON TESTÉ SUR APPAREIL]

const RANGE_M := 80.0            # demi-largeur de la carte en mètres
const REFRESH := 1.0 / 15.0

var player: Player = null
var _acc := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_acc += delta
	if _acc >= REFRESH and visible:
		_acc = 0.0
		queue_redraw()

func _basis_flat() -> Array:
	var b: Basis = player.cam.global_transform.basis if is_instance_valid(player.cam) else Basis.IDENTITY
	var r := Vector3(b.x.x, 0.0, b.x.z)
	var f := Vector3(-b.z.x, 0.0, -b.z.z)
	r = r.normalized() if r.length() > 0.001 else Vector3.RIGHT
	f = f.normalized() if f.length() > 0.001 else Vector3(0, 0, -1)
	return [r, f]

func _to_map(world: Vector3, origin: Vector3, r: Vector3, f: Vector3) -> Vector2:
	var d := world - origin
	var scale := (size.x * 0.5) / RANGE_M
	return size * 0.5 + Vector2(d.dot(r), -d.dot(f)) * scale

func _draw() -> void:
	# Le premier dessin peut arriver avant la mise en page du Control (taille nulle).
	# Le rectangle intérieur et la zone de bord de l'objectif exigent un minimum de 16 px.
	if size.x <= 16.0 or size.y <= 16.0:
		return
	var interior := Rect2(Vector2.ZERO, size).grow(-3.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.1, 0.78))
	if player == null or not is_instance_valid(player) or WorldManager.city == null:
		return
	var rf := _basis_flat()
	var r: Vector3 = rf[0]
	var f: Vector3 = rf[1]
	var o := player.global_position
	# blocs
	for rc in WorldManager.block_rects_near(o, RANGE_M * 1.6):
		var rect := rc as Rect2
		var pts := PackedVector2Array([
			_to_map(Vector3(rect.position.x, 0, rect.position.y), o, r, f),
			_to_map(Vector3(rect.end.x, 0, rect.position.y), o, r, f),
			_to_map(Vector3(rect.end.x, 0, rect.end.y), o, r, f),
			_to_map(Vector3(rect.position.x, 0, rect.end.y), o, r, f)])
		draw_colored_polygon(pts, Color(0.32, 0.34, 0.38, 0.95))
	# véhicules
	for v in get_tree().get_nodes_in_group("vehicle"):
		var v3 := v as Node3D
		if v3 != null and v3.is_inside_tree():
			var p := _to_map(v3.global_position, o, r, f)
			if interior.has_point(p):
				draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.45, 0.7, 1.0))
	# ennemis
	for e in get_tree().get_nodes_in_group("enemy"):
		var e3 := e as Node3D
		if e3 != null and e3.is_inside_tree():
			var p := _to_map(e3.global_position, o, r, f)
			if interior.has_point(p):
				draw_circle(p, 3.0, Color(1.0, 0.25, 0.25))
	# police (bleu), gangs / trafiquants (orange)
	for grp in ["police", "gang", "dealer"]:
		var gcol := Color(0.3, 0.5, 1.0) if grp == "police" else Color(1.0, 0.6, 0.15)
		for e in get_tree().get_nodes_in_group(grp):
			var e3 := e as Node3D
			if e3 != null and e3.is_inside_tree():
				var p := _to_map(e3.global_position, o, r, f)
				if interior.has_point(p):
					draw_circle(p, 3.0, gcol)
	# objets de mission
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is MissionItem:
			var p := _to_map((n as Node3D).global_position, o, r, f)
			if interior.has_point(p):
				draw_circle(p, 3.5, Color(1.0, 0.85, 0.2))
	# objectif (bord de carte s'il est hors portée)
	var op := MissionManager.objective_position()
	if op != Vector3.INF:
		var p2 := _to_map(op, o, r, f)
		var c := size * 0.5
		var half := size.x * 0.5 - 8.0
		var off := p2 - c
		if absf(off.x) > half or absf(off.y) > half:
			off = off * (half / maxf(absf(off.x), absf(off.y)))
			var dir := off.normalized()
			var tip := c + off
			draw_colored_polygon(PackedVector2Array([tip + dir * 7.0, tip - dir * 4.0 + dir.orthogonal() * 5.0, tip - dir * 4.0 - dir.orthogonal() * 5.0]), Color(1, 0.85, 0.2))
		else:
			draw_circle(p2, 5.0, Color(1, 0.85, 0.2))
			draw_arc(p2, 8.0, 0.0, TAU, 20, Color(1, 0.85, 0.2, 0.8), 2.0)
	# nord
	var np := _to_map(o + Vector3(0, 0, -1) * RANGE_M, o, r, f)
	var nd := (np - size * 0.5)
	nd = nd.normalized() * (size.x * 0.5 - 10.0)
	draw_string(ThemeDB.fallback_font, size * 0.5 + nd + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1, 1, 1, 0.85))
	# joueur (toujours vers le haut)
	var c0 := size * 0.5
	draw_colored_polygon(PackedVector2Array([c0 + Vector2(0, -8), c0 + Vector2(6, 6), c0 + Vector2(0, 3), c0 + Vector2(-6, 6)]), Color(1, 1, 1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.55), false, 2.0)
