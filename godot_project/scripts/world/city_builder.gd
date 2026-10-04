class_name CityBuilder
extends RefCounted
## Génère une ville modulaire à l'échelle des personnages Mixamo (1,68 à 1,92 m) — v17 :
## étage 3,4 m, portes 1,1 x 2,3 m, trottoirs 2,1 m (hors bloc), chaussée 6,8 m (2 voies de 3,4 m).
## Un secteur = un bloc (46 m). Aucun intérieur (les portes sont décoratives).
##
## v17 : le décor visuel d'un bloc est FUSIONNÉ (SurfaceTool) en 2 maillages — « Main » (murs, toits, trottoir) et « Detail »
## (portes, balcons, vitrines, arbres, mobilier, masqué au-delà de 90 m). Les collisions restent des StaticBody3D sans visuel.
## Fenêtres, vitrines et lampadaires s'allument la nuit (set_night) ; chaussées et trottoirs deviennent brillants sous la pluie
## (set_wet). Styles : immeuble, tour, maison (toit à deux pentes), entrepôt. [NON TESTÉ DANS GODOT]

const FLOOR_H := 3.4
const SIDEWALK := 2.1
const ROAD_HALF := 3.4
const DETAIL_RANGE := 90.0

static var _mats: Dictionary = {}
static var _facades: Array = []
static var _lamps: Array = []
static var _wets: Array = []
static var _night := 0.0
static var _wet := 0.0
static var _tex_albedo: ImageTexture = null
static var _tex_emit: ImageTexture = null

# ================================================================ maillage fusionné
class Batch extends RefCounted:
	var _sts: Dictionary = {}

	func _surface(m: Material) -> SurfaceTool:
		var k: int = m.get_instance_id()
		if not _sts.has(k):
			var s := SurfaceTool.new()
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			s.set_material(m)
			_sts[k] = s
		return _sts[k]

	## Triangle orienté vers `nrm` (Godot : face avant = sens horaire).
	func tri(a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, m: Material) -> void:
		var s := _surface(m)
		var v1 := b
		var v2 := c
		if (c - a).cross(b - a).dot(nrm) < 0.0:
			v1 = c
			v2 = b
		s.set_normal(nrm)
		s.set_uv(Vector2(0, 0))
		s.add_vertex(a)
		s.set_normal(nrm)
		s.set_uv(Vector2(1, 0))
		s.add_vertex(v1)
		s.set_normal(nrm)
		s.set_uv(Vector2(0, 1))
		s.add_vertex(v2)

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, m: Material) -> void:
		tri(a, b, c, nrm, m)
		tri(a, c, d, nrm, m)

	## Boîte centrée en `pos`, tournée de `yaw` autour de Y.
	func box(size: Vector3, pos: Vector3, m: Material, yaw := 0.0) -> void:
		var h := size * 0.5
		var bs := Basis(Vector3.UP, yaw)
		var p: Array = []
		for i in 8:
			var sx := 1.0 if (i & 1) != 0 else -1.0
			var sy := 1.0 if (i & 2) != 0 else -1.0
			var sz := 1.0 if (i & 4) != 0 else -1.0
			p.append(pos + bs * Vector3(sx * h.x, sy * h.y, sz * h.z))
		quad(p[1], p[3], p[7], p[5], bs * Vector3(1, 0, 0), m)
		quad(p[0], p[4], p[6], p[2], bs * Vector3(-1, 0, 0), m)
		quad(p[2], p[3], p[7], p[6], Vector3(0, 1, 0), m)
		quad(p[4], p[5], p[7], p[6], bs * Vector3(0, 0, 1), m)
		quad(p[0], p[2], p[3], p[1], bs * Vector3(0, 0, -1), m)

	## Toit à deux pentes : base sx x sz posée en `pos` (pos.y = bas du toit), faîtage de hauteur rh le long de X (avant rotation).
	func gable(sx: float, sz: float, rh: float, pos: Vector3, m: Material, yaw := 0.0) -> void:
		var bs := Basis(Vector3.UP, yaw)
		var hx := sx * 0.5
		var hz := sz * 0.5
		var a: Vector3 = pos + bs * Vector3(-hx, 0, -hz)
		var b: Vector3 = pos + bs * Vector3(hx, 0, -hz)
		var c: Vector3 = pos + bs * Vector3(hx, 0, hz)
		var d: Vector3 = pos + bs * Vector3(-hx, 0, hz)
		var r1: Vector3 = pos + bs * Vector3(-hx, rh, 0)
		var r2: Vector3 = pos + bs * Vector3(hx, rh, 0)
		var n_front: Vector3 = (bs * Vector3(0, hz, -rh)).normalized()
		var n_back: Vector3 = (bs * Vector3(0, hz, rh)).normalized()
		quad(a, b, r2, r1, n_front, m)
		quad(d, c, r2, r1, n_back, m)
		tri(a, d, r1, bs * Vector3(-1, 0, 0), m)
		tri(b, c, r2, bs * Vector3(1, 0, 0), m)

	func commit(parent: Node3D, node_name: String, range_end := 0.0) -> MeshInstance3D:
		if _sts.is_empty():
			return null
		var mesh := ArrayMesh.new()
		for k in _sts:
			var surface := _sts[k] as SurfaceTool
			if surface == null:
				continue
			surface.commit(mesh)
		if mesh.get_surface_count() == 0:
			return null
		var mi := MeshInstance3D.new()
		mi.name = node_name
		mi.mesh = mesh
		if range_end > 0.0:
			mi.visibility_range_end = range_end
			mi.visibility_range_end_margin = 8.0
			# Accessoires, fenêtres et arbres : pas de contribution à la shadow map.
			# Le mesh principal des bâtiments conserve les ombres directionnelles.
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif node_name == "RoadMarkings":
			# Marquages presque coplanaires : aucun bénéfice visuel à les projeter.
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		return mi

# ================================================================ matériaux
static func _facade_textures() -> void:
	if _tex_albedo != null:
		return
	var cell := 64
	var w := cell * 4
	var a := Image.create(w, w, true, Image.FORMAT_RGB8)
	var e := Image.create(w, w, true, Image.FORMAT_RGB8)
	a.fill(Color(1, 1, 1))
	e.fill(Color(0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for r in 4:
		for c in 4:
			var x0 := c * cell
			var y0 := r * cell
			var lit := rng.randf() < 0.5
			var glow := Color(1.0, 0.82, 0.5).lerp(Color(0.85, 0.92, 1.0), rng.randf() * 0.5)
			if rng.randf() < 0.12:
				glow = Color(0.45, 0.65, 1.0)
			for y in range(10, 50):
				for x in range(14, 50):
					var frame := x < 17 or x > 46 or y < 13 or y > 46 or (x > 30 and x < 33)
					a.set_pixel(x0 + x, y0 + y, Color(0.80, 0.82, 0.85) if frame else Color(0.20, 0.30, 0.40))
					if lit and not frame:
						e.set_pixel(x0 + x, y0 + y, glow)
			for x in range(12, 52):
				for y in range(50, 53):
					a.set_pixel(x0 + x, y0 + y, Color(0.84, 0.84, 0.84))
	a.generate_mipmaps()
	e.generate_mipmaps()
	_tex_albedo = ImageTexture.create_from_image(a)
	_tex_emit = ImageTexture.create_from_image(e)

## kind : flat | facade | road | walk | lamp (émissif la nuit) | window_lit | window_dark | glass
static func mat(c: Color, kind := "flat") -> StandardMaterial3D:
	var key := "%s%s" % [kind, c.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	match kind:
		"facade":
			_facade_textures()
			m.albedo_texture = _tex_albedo
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(1.0 / 16.0, 1.0 / (FLOOR_H * 4.0), 1.0 / 16.0)
			m.emission_enabled = _night > 0.03
			m.emission = Color(1, 1, 1)
			m.emission_texture = _tex_emit
			m.emission_energy_multiplier = 2.2 * _night
			m.roughness = 0.8
			_facades.append(m)
		"road", "walk":
			m.set_meta("base", c)
			m.albedo_color = c.lerp(c.darkened(0.4), _wet)
			m.roughness = lerpf(0.92, 0.25, _wet)
			_wets.append(m)
		"lamp":
			m.emission_enabled = true
			m.emission = c
			m.set_meta("e", 3.0)
			m.emission_energy_multiplier = 3.0 * _night
			m.albedo_color = c.darkened(0.5)
			_lamps.append(m)
		"window_lit":
			m.albedo_color = Color(0.2, 0.26, 0.32)
			m.emission_enabled = true
			m.emission = c
			m.set_meta("e", 2.2)
			m.emission_energy_multiplier = 2.2 * _night
			m.roughness = 0.2
			_lamps.append(m)
		"window_dark", "glass":
			m.roughness = 0.12
			m.metallic = 0.3
	_mats[key] = m
	return m

## 0 = jour, 1 = nuit : allume fenêtres, vitrines, enseignes et lampadaires.
static func set_night(f: float) -> void:
	_night = f
	for m in _facades:
		var bm := m as StandardMaterial3D
		bm.emission_enabled = f > 0.03
		bm.emission_energy_multiplier = 2.2 * f
	for m in _lamps:
		var lm := m as StandardMaterial3D
		lm.emission_energy_multiplier = float(lm.get_meta("e", 3.0)) * f

## 0 = sec, 1 = trempé : chaussée / trottoir plus sombres et brillants.
static func set_wet(w: float) -> void:
	_wet = w
	for m in _wets:
		var bm := m as StandardMaterial3D
		var base: Color = bm.get_meta("base", bm.albedo_color)
		bm.albedo_color = base.lerp(base.darkened(0.4), w)
		bm.roughness = lerpf(0.92, 0.25, w)

# ================================================================ primitives utilitaires (collisions, objets du monde)
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

static func collider_box(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

static func collider_cyl(parent: Node3D, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = radius
	cy.height = height
	cs.shape = cy
	cs.position.y = height * 0.5
	sb.add_child(cs)
	parent.add_child(sb)
	return sb

# ================================================================ sol, routes, marquages
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
	var bt := Batch.new()
	bt.box(Vector3(ext.size.x, 0.02, ext.size.y), Vector3(ctr.x, 0.01, ctr.z), mat(city.road_color, "road"))
	_markings(city, bt)
	bt.commit(root, "RoadMarkings")
	# murs invisibles autour de la ville (le joueur reste dans la ville)
	var wall_h := 12.0
	var t := 2.0
	for s in [[Vector3(ext.size.x + 2.0 * t, wall_h, t), Vector3(ctr.x, wall_h * 0.5, ext.position.y - t * 0.5)],
			[Vector3(ext.size.x + 2.0 * t, wall_h, t), Vector3(ctr.x, wall_h * 0.5, ext.position.y + ext.size.y + t * 0.5)],
			[Vector3(t, wall_h, ext.size.y), Vector3(ext.position.x - t * 0.5, wall_h * 0.5, ctr.z)],
			[Vector3(t, wall_h, ext.size.y), Vector3(ext.position.x + ext.size.x + t * 0.5, wall_h * 0.5, ctr.z)]]:
		collider_box(root, s[0], s[1])

## Lignes jaunes centrales, bords blancs, passages piétons (aux intersections intérieures).
static func _markings(city: CityDef, bt: Batch) -> void:
	var p := city.block_size + city.road_width
	var yellow := mat(Color(0.88, 0.76, 0.2))
	var white := mat(Color(0.88, 0.88, 0.85))
	var y := 0.026
	var lw := 0.12
	for i in range(1, city.blocks_x):                       # routes parallèles à Z
		var x := -p * 0.5 + float(i) * p
		for j in range(0, city.blocks_z):
			var z0 := -p * 0.5 + float(j) * p + (6.2 if j >= 1 else 0.6)
			var z1 := -p * 0.5 + float(j + 1) * p - (6.2 if j + 1 <= city.blocks_z - 1 else 0.6)
			var ln := z1 - z0
			if ln <= 0.5:
				continue
			var zc := (z0 + z1) * 0.5
			bt.box(Vector3(lw, 0.012, ln), Vector3(x - 0.12, y, zc), yellow)
			bt.box(Vector3(lw, 0.012, ln), Vector3(x + 0.12, y, zc), yellow)
			bt.box(Vector3(lw, 0.012, ln), Vector3(x - ROAD_HALF + 0.25, y, zc), white)
			bt.box(Vector3(lw, 0.012, ln), Vector3(x + ROAD_HALF - 0.25, y, zc), white)
	for j in range(1, city.blocks_z):                       # routes parallèles à X
		var z := -p * 0.5 + float(j) * p
		for i in range(0, city.blocks_x):
			var x0 := -p * 0.5 + float(i) * p + (6.2 if i >= 1 else 0.6)
			var x1 := -p * 0.5 + float(i + 1) * p - (6.2 if i + 1 <= city.blocks_x - 1 else 0.6)
			var ln2 := x1 - x0
			if ln2 <= 0.5:
				continue
			var xc := (x0 + x1) * 0.5
			bt.box(Vector3(ln2, 0.012, lw), Vector3(xc, y, z - 0.12), yellow)
			bt.box(Vector3(ln2, 0.012, lw), Vector3(xc, y, z + 0.12), yellow)
			bt.box(Vector3(ln2, 0.012, lw), Vector3(xc, y, z - ROAD_HALF + 0.25), white)
			bt.box(Vector3(ln2, 0.012, lw), Vector3(xc, y, z + ROAD_HALF - 0.25), white)
	# passages piétons : 4 par intersection intérieure, 7 bandes de 0,5 m
	for i in range(1, city.blocks_x):
		for j in range(1, city.blocks_z):
			var cx := -p * 0.5 + float(i) * p
			var cz := -p * 0.5 + float(j) * p
			for s in [-1.0, 1.0]:
				for k in 7:
					var off := -3.0 + float(k)
					bt.box(Vector3(0.5, 0.012, 2.2), Vector3(cx + off, y, cz + s * 4.6), white)
					bt.box(Vector3(2.2, 0.012, 0.5), Vector3(cx + s * 4.6, y, cz + off), white)

# ================================================================ blocs
static func build_block(city: CityDef, b: Vector2i, n: Node3D, poi: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = city.seed_value * 7919 + b.x * 131 + b.y * 977
	var bs := city.block_size
	var main := Batch.new()
	var detail := Batch.new()
	main.box(Vector3(bs + 2.0 * SIDEWALK, 0.04, bs + 2.0 * SIDEWALK), Vector3(0, 0.02, 0), mat(Color(0.56, 0.56, 0.54), "walk"))
	main.box(Vector3(bs - 0.6, 0.05, bs - 0.6), Vector3(0, 0.025, 0), mat(Color(0.47, 0.47, 0.46), "walk"))
	var inner := bs - 2.0 * SIDEWALK
	if poi == "":
		_normal_block(city, n, main, detail, rng, inner)
	else:
		_plaza_block(city, n, main, detail, rng, inner, poi)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamp(n, detail, Vector3(sx * (bs * 0.5 - 0.6), 0.0, sz * (bs * 0.5 - 0.6)), Vector2(-sx, -sz))
	_street_props(n, detail, rng, bs)
	main.commit(n, "Main")
	detail.commit(n, "Detail", DETAIL_RANGE)

static func _lamp(n: Node3D, dt: Batch, pos: Vector3, toward: Vector2) -> void:
	collider_cyl(n, 0.13, 4.8, pos)
	var pole := mat(Color(0.18, 0.19, 0.21))
	dt.box(Vector3(0.14, 4.8, 0.14), pos + Vector3(0, 2.4, 0), pole)
	var arm := Vector3(toward.x, 0, toward.y).normalized()
	dt.box(Vector3(0.1 + absf(arm.x), 0.1, 0.1 + absf(arm.z)), pos + Vector3(0, 4.75, 0) + arm * 0.5, pole)
	dt.box(Vector3(0.5, 0.12, 0.3), pos + Vector3(0, 4.68, 0) + arm * 1.0, mat(Color(1.0, 0.9, 0.62), "lamp"))

static func _normal_block(city: CityDef, n: Node3D, main: Batch, detail: Batch, rng: RandomNumberGenerator, inner: float) -> void:
	if city.industrial and rng.randf() < 0.5:
		var w := inner * rng.randf_range(0.7, 0.85)
		var d := inner * rng.randf_range(0.6, 0.8)
		building(city, n, main, detail, Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)), Vector2(w, d), 1, rng.randi_range(1, 4), rng, "")
		return
	var gap := 1.6
	var lot := (inner - gap) * 0.5
	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var c := Vector3(float(ix) * (lot * 0.5 + gap * 0.5), 0, float(iz) * (lot * 0.5 + gap * 0.5))
			var w := lot - rng.randf_range(0.2, 2.2)
			var d := lot - rng.randf_range(0.2, 2.2)
			var floors := rng.randi_range(city.floors_min, city.floors_max)
			var door := 1 if (ix > 0 and rng.randf() < 0.5) else (1 if iz > 0 else (2 if ix < 0 else 3))
			building(city, n, main, detail, c, Vector2(w, d), floors, door, rng, "")

static func _plaza_block(city: CityDef, n: Node3D, main: Batch, detail: Batch, rng: RandomNumberGenerator, inner: float, poi: String) -> void:
	var cross := 16.0
	var s := (inner - cross) * 0.5
	var idx := 0
	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var c := Vector3(float(ix) * (cross * 0.5 + s * 0.5), 0, float(iz) * (cross * 0.5 + s * 0.5))
			var floors := rng.randi_range(city.floors_min, city.floors_max)
			var door := 3 if ix > 0 else 2          # porte tournée vers le centre de la place (axe X)
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
			building(city, n, main, detail, c, Vector2(s - 0.4, s - 0.4), floors, door, rng, label)
			if poi == "shop" and idx == 0:
				var sp := ShopPoint.new()
				sp.position = Vector3(c.x + (s * 0.5 + 1.2) * (1.0 if ix < 0 else -1.0), 0.0, c.z)
				n.add_child(sp)
			idx += 1
	if poi.begins_with("hideout") or poi == "depot" or poi.begins_with("search"):
		_cover_field(n, rng, 9 if poi.begins_with("hideout") else 5)
	elif poi == "car_a" or poi == "spawn" or poi.begins_with("contact") or poi == "drop_a" or poi == "travel":
		_bench(n, detail, Vector3(5.0, 0, -3.0))
		_bench(n, detail, Vector3(-5.0, 0, 3.0))

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
		solid_box(n, Vector3(6.0, 2.6, 2.4), Vector3(side * 11.0, 1.3, side * -3.0), metal, true)
	for k in 3:
		var wall := solid_box(n, Vector3(3.2, 1.2, 0.3), Vector3(rng.randf_range(-6, 6), 0.6, rng.randf_range(-6, 6)), mat(Color(0.5, 0.5, 0.52)), true)
		wall.rotation.y = rng.randf() * PI

static func _bench(n: Node3D, dt: Batch, pos: Vector3) -> void:
	var wood := mat(Color(0.45, 0.3, 0.15))
	var iron := mat(Color(0.2, 0.2, 0.22))
	collider_box(n, Vector3(1.6, 0.45, 0.45), pos + Vector3(0, 0.225, 0))
	dt.box(Vector3(1.6, 0.08, 0.45), pos + Vector3(0, 0.43, 0), wood)
	dt.box(Vector3(1.6, 0.5, 0.08), pos + Vector3(0, 0.7, -0.2), wood)
	dt.box(Vector3(0.08, 0.4, 0.4), pos + Vector3(-0.7, 0.2, 0), iron)
	dt.box(Vector3(0.08, 0.4, 0.4), pos + Vector3(0.7, 0.2, 0), iron)

static func _tree(n: Node3D, dt: Batch, pos: Vector3, rng: RandomNumberGenerator) -> void:
	collider_cyl(n, 0.2, 2.4, pos)
	var g := Color(0.16, 0.38 + rng.randf() * 0.14, 0.17)
	dt.box(Vector3(0.28, 2.5, 0.28), pos + Vector3(0, 1.25, 0), mat(Color(0.3, 0.2, 0.12)))
	var yaw := rng.randf() * PI
	dt.box(Vector3(2.5, 1.7, 2.5), pos + Vector3(0, 3.0, 0), mat(g), yaw)
	dt.box(Vector3(1.7, 1.3, 1.7), pos + Vector3(0, 4.2, 0), mat(g.lightened(0.08)), yaw + 0.6)

## Mobilier de rue sur le trottoir, côté chaussée (arbres, bornes, boîtes aux lettres, panneaux).
static func _street_props(n: Node3D, dt: Batch, rng: RandomNumberGenerator, bs: float) -> void:
	var edge := bs * 0.5 + SIDEWALK - 0.25
	var green := mat(Color(0.14, 0.3, 0.2))
	var red := mat(Color(0.7, 0.12, 0.1))
	for side in 4:
		var yaw := float(side) * PI * 0.5
		var bas := Basis(Vector3.UP, yaw)
		for i in 2 + (rng.randi() % 2):
			var pos: Vector3 = bas * Vector3(edge, 0.0, rng.randf_range(-15.0, 15.0))
			match rng.randi() % 6:
				0, 1:
					_tree(n, dt, pos, rng)
				2:
					dt.box(Vector3(0.3, 0.7, 0.3), pos + Vector3(0, 0.35, 0), red, yaw)
					dt.box(Vector3(0.38, 0.12, 0.38), pos + Vector3(0, 0.74, 0), red, yaw)
				3:
					dt.box(Vector3(0.5, 0.95, 0.5), pos + Vector3(0, 0.475, 0), green, yaw)
				4:
					dt.box(Vector3(0.09, 2.6, 0.09), pos + Vector3(0, 1.3, 0), mat(Color(0.25, 0.25, 0.28)))
					dt.box(Vector3(0.7, 0.5, 0.05), pos + Vector3(0, 2.4, 0), mat(Color(0.1, 0.35, 0.65)), yaw)
				_:
					pass

# ================================================================ bâtiments
## Faces : 1 = +Z (alias 0), 2 = -X, 3 = +X, 4 = -Z. Retourne {n: normale, t: tangente, w: largeur, d: demi-profondeur}.
static func _face(foot: Vector2, door: int) -> Dictionary:
	match door:
		2:
			return {"n": Vector3(-1, 0, 0), "t": Vector3(0, 0, 1), "w": foot.y, "d": foot.x * 0.5}
		3:
			return {"n": Vector3(1, 0, 0), "t": Vector3(0, 0, 1), "w": foot.y, "d": foot.x * 0.5}
		4:
			return {"n": Vector3(0, 0, -1), "t": Vector3(1, 0, 0), "w": foot.x, "d": foot.y * 0.5}
	return {"n": Vector3(0, 0, 1), "t": Vector3(1, 0, 0), "w": foot.x, "d": foot.y * 0.5}

## Boîte posée sur une face : u = décalage latéral, y = hauteur du CENTRE, w x hgt x thick (épaisseur vers l'extérieur), push = recul.
static func _fbox(dt: Batch, center: Vector3, face: Dictionary, u: float, y: float, w: float, hgt: float, thick: float, push: float, m: Material) -> void:
	var nrm: Vector3 = face["n"]
	var tg: Vector3 = face["t"]
	var pos: Vector3 = center + nrm * (float(face["d"]) + push + thick * 0.5) + tg * u + Vector3(0, y, 0)
	var size := Vector3(w, hgt, thick) if absf(nrm.z) > 0.5 else Vector3(thick, hgt, w)
	dt.box(size, pos, m)

static func _opposite(door: int) -> int:
	match door:
		2:
			return 3
		3:
			return 2
		4:
			return 1
	return 4

static func building(city: CityDef, n: Node3D, main: Batch, detail: Batch, center: Vector3, foot: Vector2, floors: int, door_in: int, rng: RandomNumberGenerator, label: String) -> StaticBody3D:
	var door := 1 if door_in == 0 else door_in
	var style := "apartment"
	if floors >= 6:
		style = "tower"
	elif city.industrial and floors <= 1:
		style = "warehouse"
	elif floors <= 2 and not city.industrial and label == "" and rng.randf() < 0.55:
		style = "house"
	var h := 6.5 if style == "warehouse" else float(floors) * FLOOR_H
	var col := city.wall_color if rng.randf() < 0.5 else city.wall_color_b
	if label != "":
		col = col.lerp(Color(0.9, 0.75, 0.3), 0.35)
	var body := collider_box(n, Vector3(foot.x, h, foot.y), center + Vector3(0, h * 0.5, 0))
	var face := _face(foot, door)
	var nrm: Vector3 = face["n"]
	var fw: float = face["w"]
	var dark := mat(Color(0.14, 0.12, 0.11))
	var roof := mat(city.roof_color)
	match style:
		"house":
			main.box(Vector3(foot.x, h, foot.y), center + Vector3(0, h * 0.5, 0), mat(col.lerp(Color(0.95, 0.9, 0.8), 0.3)))
			var along_x := foot.x >= foot.y
			var roof_col := Color(0.45, 0.2, 0.15).lerp(city.roof_color, 0.3)
			var rx := (foot.x if along_x else foot.y) + 0.8
			var rz := (foot.y if along_x else foot.x) + 0.8
			main.gable(rx, rz, 2.4, center + Vector3(0, h, 0), mat(roof_col), 0.0 if along_x else PI * 0.5)
			detail.box(Vector3(0.7, 1.6, 0.7), center + Vector3(foot.x * 0.25, h + 1.6, foot.y * 0.2), mat(Color(0.4, 0.25, 0.2)))
			_windows(detail, center, foot, floors, door, rng)
		"warehouse":
			main.box(Vector3(foot.x, h, foot.y), center + Vector3(0, h * 0.5, 0), mat(col.darkened(0.1)))
			main.box(Vector3(foot.x + 0.3, 0.3, foot.y + 0.3), center + Vector3(0, h + 0.15, 0), roof)
			_fbox(detail, center, face, 0.0, 2.0, 4.2, 4.0, 0.15, 0.0, mat(Color(0.35, 0.37, 0.4)))
			_fbox(detail, center, face, 0.0, 5.4, maxf(fw - 3.0, 1.0), 0.9, 0.12, 0.0, mat(Color(0.12, 0.2, 0.28), "window_dark"))
			for k in 2:
				detail.box(Vector3(1.4, 0.9, 1.4), center + Vector3((float(k) - 0.5) * foot.x * 0.35, h + 0.75, foot.y * 0.1), mat(Color(0.5, 0.5, 0.52)))
		_:
			var tint := col if style == "apartment" else col.lerp(Color(0.5, 0.65, 0.8), 0.55)
			main.box(Vector3(foot.x, h, foot.y), center + Vector3(0, h * 0.5, 0), mat(tint, "facade"))
			main.box(Vector3(foot.x + 0.3, 0.3, foot.y + 0.3), center + Vector3(0, h + 0.15, 0), roof)
			main.box(Vector3(foot.x + 0.36, 0.28, foot.y + 0.36), center + Vector3(0, h - 0.14, 0), mat(col.lightened(0.12)))
			var pt := 0.22
			var ph := 0.75
			var py := h + 0.3 + ph * 0.5
			detail.box(Vector3(foot.x + 0.3, ph, pt), center + Vector3(0, py, foot.y * 0.5 + 0.1), roof)
			detail.box(Vector3(foot.x + 0.3, ph, pt), center + Vector3(0, py, -foot.y * 0.5 - 0.1), roof)
			detail.box(Vector3(pt, ph, foot.y + 0.3), center + Vector3(foot.x * 0.5 + 0.1, py, 0), roof)
			detail.box(Vector3(pt, ph, foot.y + 0.3), center + Vector3(-foot.x * 0.5 - 0.1, py, 0), roof)
			for k in rng.randi_range(1, 3):
				detail.box(Vector3(1.3, 0.9, 1.2), center + Vector3(rng.randf_range(-0.3, 0.3) * foot.x, h + 0.75, rng.randf_range(-0.3, 0.3) * foot.y), mat(Color(0.55, 0.57, 0.6)), rng.randf() * PI)
			if style == "tower":
				detail.box(Vector3(0.12, 7.0, 0.12), center + Vector3(0, h + 3.8, 0), mat(Color(0.3, 0.3, 0.33)))
				detail.box(Vector3(0.3, 0.3, 0.3), center + Vector3(0, h + 7.3, 0), mat(Color(1.0, 0.15, 0.1), "lamp"))
			elif floors >= 3 and rng.randf() < 0.55:
				var back := _face(foot, _opposite(door))
				var bw: float = back["w"]
				var bal := mat(Color(0.5, 0.5, 0.5))
				var rail := mat(Color(0.2, 0.22, 0.25))
				for fl in range(1, floors):
					for u in [-bw * 0.25, bw * 0.25]:
						_fbox(detail, center, back, u, float(fl) * FLOOR_H + 0.05, 2.4, 0.12, 1.0, 0.0, bal)
						_fbox(detail, center, back, u, float(fl) * FLOOR_H + 0.55, 2.4, 0.9, 0.05, 0.95, rail)
	# porte 1,1 x 2,3 m + cadre + marche + lampe d'entrée
	var door_cols: Array = [Color(0.35, 0.2, 0.12), Color(0.12, 0.2, 0.3), Color(0.25, 0.25, 0.27), Color(0.3, 0.12, 0.1)]
	_fbox(detail, center, face, 0.0, 1.2, 1.5, 2.4, 0.1, 0.0, dark)
	_fbox(detail, center, face, 0.0, 1.15, 1.1, 2.3, 0.1, 0.06, mat(door_cols[rng.randi() % 4]))
	_fbox(detail, center, face, 0.38, 1.1, 0.07, 0.16, 0.08, 0.14, mat(Color(0.8, 0.7, 0.3)))
	_fbox(detail, center, face, 0.0, 0.06, 2.0, 0.12, 0.7, 0.0, mat(Color(0.6, 0.6, 0.58)))
	_fbox(detail, center, face, 0.0, 2.65, 0.35, 0.12, 0.2, 0.0, mat(Color(1.0, 0.9, 0.65), "lamp"))
	# vitrines de commerce de part et d'autre de la porte (immeubles, tours, lieux-dits)
	var shop_roll := rng.randf()
	if style != "house" and style != "warehouse" and (label != "" or shop_roll < 0.5):
		var side_w := maxf(fw * 0.5 - 1.6, 0.5)
		var shop_glass := mat(Color(1.0, 0.85, 0.55), "window_lit")
		for sgn in [-1.0, 1.0]:
			_fbox(detail, center, face, sgn * (0.8 + side_w * 0.5), 1.5, side_w, 2.4, 0.08, 0.0, shop_glass)
		var awnings: Array = [Color(0.7, 0.15, 0.12), Color(0.12, 0.35, 0.55), Color(0.15, 0.45, 0.25), Color(0.75, 0.55, 0.12)]
		_fbox(detail, center, face, 0.0, 3.0, maxf(fw - 1.0, 1.0), 0.1, 1.0, 0.0, mat(awnings[rng.randi() % 4]))
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.font_size = 96
		l.pixel_size = 0.012
		l.modulate = Color(1.0, 0.9, 0.4)
		l.outline_modulate = Color(0, 0, 0)
		l.position = center + nrm * (float(face["d"]) + 1.1) + Vector3(0, 3.9, 0)
		l.rotation.y = atan2(nrm.x, nrm.z)
		n.add_child(l)
	return body

## Fenêtres des maisons : allumées (la nuit) ou éteintes, sur toutes les faces sauf celle de la porte.
static func _windows(dt: Batch, center: Vector3, foot: Vector2, floors: int, door: int, rng: RandomNumberGenerator) -> void:
	for fl in floors:
		var y := float(fl) * FLOOR_H + 1.9
		for d in [1, 2, 3, 4]:
			if d == door:
				continue
			var face := _face(foot, d)
			var fw: float = face["w"]
			var cnt := maxi(int(fw / 4.0), 1)
			for k in cnt:
				var u := (float(k) + 0.5) * fw / float(cnt) - fw * 0.5
				var lit := rng.randf() < 0.45
				var wm := mat(Color(1.0, 0.85, 0.55), "window_lit") if lit else mat(Color(0.18, 0.26, 0.34), "window_dark")
				_fbox(dt, center, face, u, y, 1.2, 1.3, 0.06, 0.0, wm)
				_fbox(dt, center, face, u, y - 0.75, 1.5, 0.1, 0.18, 0.0, mat(Color(0.85, 0.85, 0.85)))
