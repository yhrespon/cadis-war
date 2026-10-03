class_name CityBuilder
extends RefCounted
## Génère une ville modulaire à l'échelle des personnages : étage 3,2 m, portes 1,0 x 2,1 m, trottoirs 2,1 m,
## voies 3,4 m. Un secteur = un bloc (46 m). Aucun intérieur (les portes sont décoratives, v1).

const FLOOR_H := 3.2
const SIDEWALK := 2.1

static var _mats: Dictionary = {}
static var _win_tex: ImageTexture = null

static func _window_texture() -> ImageTexture:
	if _win_tex == null:
		var img := Image.create(64, 64, true, Image.FORMAT_RGB8)
		img.fill(Color(1, 1, 1))
		for y in range(12, 50):
			for x in range(14, 50):
				var frame := x < 17 or x > 46 or y < 15 or y > 46 or (x > 30 and x < 33)
				img.set_pixel(x, y, Color(0.8, 0.82, 0.85) if frame else Color(0.32, 0.46, 0.6))
		img.generate_mipmaps()
		_win_tex = ImageTexture.create_from_image(img)
	return _win_tex

static func mat(c: Color, kind := "flat") -> StandardMaterial3D:
	var key := "%s%s" % [kind, c.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	if kind == "facade":
		m.albedo_texture = _window_texture()
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.3125, 0.25)
	_mats[key] = m
	return m

static func visual_box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

static func solid_box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, cover := false) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	visual_box(sb, size, Vector3.ZERO, m)
	if cover:
		sb.add_to_group("cover")
	parent.add_child(sb)
	return sb

static func build_ground(city: CityDef, root: Node3D, ext: Rect2) -> void:
	var m := 60.0
	var sb := StaticBody3D.new()
	sb.name = "Ground"
	var size := Vector3(ext.size.x + 2.0 * m, 1.0, ext.size.y + 2.0 * m)
	var ctr := Vector3(ext.position.x + ext.size.x * 0.5, -0.5, ext.position.y + ext.size.y * 0.5)
	sb.position = ctr
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	visual_box(sb, size, Vector3.ZERO, mat(city.ground_color))
	root.add_child(sb)
	# chaussée (visuel seul) sur l'emprise de la ville
	visual_box(root, Vector3(ext.size.x, 0.02, ext.size.y), Vector3(ctr.x, 0.01, ctr.z), mat(city.road_color))
	# bandes de marquage au centre de chaque route (visuel)
	var p := city.block_size + city.road_width
	for i in range(0, city.blocks_x + 1):
		var x := -p * 0.5 + float(i) * p
		visual_box(root, Vector3(0.15, 0.025, ext.size.y), Vector3(x, 0.013, ctr.z), mat(Color(0.85, 0.8, 0.3)))
	for j in range(0, city.blocks_z + 1):
		var z := -p * 0.5 + float(j) * p
		visual_box(root, Vector3(ext.size.x, 0.025, 0.15), Vector3(ctr.x, 0.013, z), mat(Color(0.85, 0.8, 0.3)))
	# murs invisibles autour de la ville (le joueur reste dans la ville)
	var wall_h := 12.0
	var t := 2.0
	for s in [[Vector3(ext.size.x + 2.0 * t, wall_h, t), Vector3(ctr.x, wall_h * 0.5, ext.position.y - t * 0.5)],
			[Vector3(ext.size.x + 2.0 * t, wall_h, t), Vector3(ctr.x, wall_h * 0.5, ext.position.y + ext.size.y + t * 0.5)],
			[Vector3(t, wall_h, ext.size.y), Vector3(ext.position.x - t * 0.5, wall_h * 0.5, ctr.z)],
			[Vector3(t, wall_h, ext.size.y), Vector3(ext.position.x + ext.size.x + t * 0.5, wall_h * 0.5, ctr.z)]]:
		var wb := StaticBody3D.new()
		wb.position = s[1]
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = s[0]
		wc.shape = ws
		wb.add_child(wc)
		root.add_child(wb)

static func build_block(city: CityDef, b: Vector2i, n: Node3D, poi: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city.seed_value * 7919 + b.x * 131 + b.y * 977
	var bs := city.block_size
	visual_box(n, Vector3(bs, 0.03, bs), Vector3(0, 0.015, 0), mat(Color(0.52, 0.52, 0.5)))
	var inner := bs - 2.0 * SIDEWALK
	if poi == "":
		_normal_block(city, n, rng, inner)
	else:
		_plaza_block(city, n, rng, inner, poi)
	# lampadaires aux coins du trottoir (collision fine)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamp(n, Vector3(sx * (bs * 0.5 - 0.6), 0.0, sz * (bs * 0.5 - 0.6)))

static func _lamp(n: Node3D, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.12
	cyl.height = 4.5
	cs.shape = cyl
	cs.position.y = 2.25
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.1
	cm.height = 4.5
	mi.mesh = cm
	mi.position.y = 2.25
	mi.material_override = mat(Color(0.2, 0.2, 0.22))
	sb.add_child(mi)
	visual_box(sb, Vector3(0.5, 0.12, 0.25), Vector3(0, 4.55, 0), mat(Color(1.0, 0.92, 0.65)))
	n.add_child(sb)

static func _normal_block(city: CityDef, n: Node3D, rng: RandomNumberGenerator, inner: float) -> void:
	if city.industrial and rng.randf() < 0.5:
		var w := inner * rng.randf_range(0.7, 0.85)
		var d := inner * rng.randf_range(0.6, 0.8)
		building(city, n, Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), Vector2(w, d), 1, rng.randi_range(0, 3), rng, "")
		return
	var gap := 1.6
	var lot := (inner - gap) * 0.5
	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var c := Vector3(float(ix) * (lot * 0.5 + gap * 0.5), 0, float(iz) * (lot * 0.5 + gap * 0.5))
			var w := lot - rng.randf_range(0.2, 2.2)
			var d := lot - rng.randf_range(0.2, 2.2)
			var floors := rng.randi_range(city.floors_min, city.floors_max)
			var door := 0 if (ix > 0 and rng.randf() < 0.5) else (1 if iz > 0 else (2 if ix < 0 else 3))
			building(city, n, c, Vector2(w, d), floors, door, rng, "")

static func _plaza_block(city: CityDef, n: Node3D, rng: RandomNumberGenerator, inner: float, poi: String) -> void:
	var cross := 16.0
	var s := (inner - cross) * 0.5
	var idx := 0
	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var c := Vector3(float(ix) * (cross * 0.5 + s * 0.5), 0, float(iz) * (cross * 0.5 + s * 0.5))
			var floors := rng.randi_range(city.floors_min, city.floors_max)
			# porte tournée vers le centre de la place (axe X)
			var door := 3 if ix > 0 else 2
			var label := ""
			if idx == 0:
				if poi == "shop":
					label = "MAGASIN"
				elif poi == "vault":
					label = "BANQUE"
					floors = maxi(floors, 3)
				elif poi == "hospital":
					label = "HÔPITAL"
				elif poi == "safehouse":
					label = "PLANQUE"
			building(city, n, c, Vector2(s - 0.4, s - 0.4), floors, door, rng, label)
			if poi == "shop" and idx == 0:
				var sp := ShopPoint.new()
				# devant la porte (côté centre) : ix<0 => porte face +X, ix>0 => face -X
				sp.position = Vector3(c.x + (s * 0.5 + 1.2) * (1.0 if ix < 0 else -1.0), 0.0, c.z)
				n.add_child(sp)
			idx += 1
	if poi.begins_with("hideout") or poi == "depot" or poi.begins_with("search"):
		_cover_field(n, rng, 9 if poi.begins_with("hideout") else 5)
	elif poi == "car_a" or poi == "spawn" or poi.begins_with("contact") or poi == "drop_a" or poi == "travel":
		_bench(n, Vector3(5.0, 0, -3.0))
		_bench(n, Vector3(-5.0, 0, 3.0))

static func _cover_field(n: Node3D, rng: RandomNumberGenerator, count: int) -> void:
	var crate := mat(Color(0.55, 0.4, 0.22))
	var metal := mat(Color(0.3, 0.38, 0.45))
	for i in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.5, 9.0)
		var p := Vector3(cos(a) * r, 0.55, sin(a) * r)
		var sb := solid_box(n, Vector3(1.1, 1.1, 1.1), p, crate, true)
		sb.rotation.y = rng.randf() * TAU
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var cont := solid_box(n, Vector3(6.0, 2.6, 2.4), Vector3(side * 11.0, 1.3, side * -3.0), metal, true)
		cont.rotation.y = 0.0
	for k in 3:
		var wall := solid_box(n, Vector3(3.2, 1.2, 0.3), Vector3(rng.randf_range(-6, 6), 0.6, rng.randf_range(-6, 6)), mat(Color(0.5, 0.5, 0.52)), true)
		wall.rotation.y = rng.randf() * PI

static func _bench(n: Node3D, pos: Vector3) -> void:
	var wood := mat(Color(0.45, 0.3, 0.15))
	solid_box(n, Vector3(1.6, 0.45, 0.45), pos + Vector3(0, 0.225, 0), wood)
	visual_box(n, Vector3(1.6, 0.5, 0.08), pos + Vector3(0, 0.7, -0.2), wood)

## door : 0 = +Z, 1 = +Z (alias), 2 = -X, 3 = +X (porte sur la face indiquée). Retourne le corps statique.
static func building(city: CityDef, n: Node3D, center: Vector3, foot: Vector2, floors: int, door: int, rng: RandomNumberGenerator, label: String) -> StaticBody3D:
	var h := 6.0 if (city.industrial and floors <= 1) else float(floors) * FLOOR_H
	var col := city.wall_color if rng.randf() < 0.5 else city.wall_color_b
	if label != "":
		col = col.lerp(Color(0.9, 0.75, 0.3), 0.35)
	var sb := solid_box(n, Vector3(foot.x, h, foot.y), center + Vector3(0, h * 0.5, 0), mat(col, "facade"))
	visual_box(sb, Vector3(foot.x + 0.3, 0.25, foot.y + 0.3), Vector3(0, h * 0.5 + 0.125, 0), mat(city.roof_color))
	# porte 1,0 x 2,1 m sur la face choisie, seuil de 0,5 m de profondeur
	var dm := mat(Color(0.12, 0.1, 0.09))
	var dpos := Vector3.ZERO
	var dsize := Vector3(1.0, 2.1, 0.12)
	var normal := Vector3.ZERO
	match door:
		2:
			normal = Vector3(-1, 0, 0)
			dsize = Vector3(0.12, 2.1, 1.0)
		3:
			normal = Vector3(1, 0, 0)
			dsize = Vector3(0.12, 2.1, 1.0)
		_:
			normal = Vector3(0, 0, 1)
	dpos = normal * (foot.x * 0.5 if absf(normal.x) > 0.5 else foot.y * 0.5) + Vector3(0, 1.05 - h * 0.5, 0) + normal * 0.06
	visual_box(sb, dsize, dpos, dm)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.font_size = 96
		l.pixel_size = 0.012
		l.modulate = Color(1.0, 0.9, 0.4)
		l.outline_modulate = Color(0, 0, 0)
		l.position = normal * ((foot.x if absf(normal.x) > 0.5 else foot.y) * 0.5 + 0.25) + Vector3(0, 3.1 - h * 0.5, 0)
		l.rotation.y = atan2(normal.x, normal.z)
		sb.add_child(l)
	return sb
