extends Node
## Inventaire réel : armes possédées, munitions (par type), chargeurs, objets, tenue équipée, armure.
## Achat -> inventaire -> équipement -> sauvegarde (SaveManager).

signal changed()
signal weapon_equipped(id: String)

const ITEM_IDS_PATH := "res://data/registry.json"

var weapons: Array = []              # ids d'armes possédées
var ammo: Dictionary = {}            # type -> réserve
var mag: Dictionary = {}             # weapon id -> balles dans le chargeur
var items: Dictionary = {}           # item id -> quantité (soins, vêtements possédés...)
var outfit: Dictionary = {"top": "", "bottom": "", "hair": ""}   # item id équipé par emplacement
var equipped := ""                   # id d'arme en main ("" = mains nues)
var armor := 0.0

var _items_db: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open(ITEM_IDS_PATH, FileAccess.READ)
	var reg: Dictionary = JSON.parse_string(f.get_as_text())
	for id in reg["items"]:
		var d := load("res://data/items/%s.tres" % id) as ItemDef
		if d != null:
			_items_db[id] = d
	reset()

func reset() -> void:
	weapons = ["bat"]
	ammo = {}
	mag = {}
	items = {}
	outfit = {"top": "", "bottom": "", "hair": ""}
	equipped = "bat"
	armor = 0.0
	changed.emit()

func all_items() -> Array:
	return _items_db.values()

func item_def(id: String) -> ItemDef:
	return _items_db.get(id) as ItemDef

func items_of(category: String) -> Array:
	var out: Array = []
	for d in _items_db.values():
		if d.category == category:
			out.append(d)
	return out

func has_weapon(id: String) -> bool:
	return weapons.has(id)

func add_weapon(id: String) -> void:
	if not weapons.has(id):
		weapons.append(id)
		var def := WeaponManager.get_def(id)
		if def != null and not def.melee:
			mag[id] = def.mag_size
	changed.emit()

func add_ammo(type: String, n: int) -> void:
	ammo[type] = int(ammo.get(type, 0)) + n
	changed.emit()

func reserve_for(id: String) -> int:
	var def := WeaponManager.get_def(id)
	if def == null or def.melee:
		return 0
	return int(ammo.get(def.ammo_type, 0))

func mag_for(id: String) -> int:
	return int(mag.get(id, 0))

func equip_weapon(id: String) -> void:
	if id != "" and not weapons.has(id):
		return
	equipped = id
	weapon_equipped.emit(id)
	changed.emit()

func cycle_weapon() -> void:
	if weapons.is_empty():
		return
	var i := weapons.find(equipped)
	equip_weapon(weapons[(i + 1) % weapons.size()])

## Recharge l'arme équipée : retourne le nombre de balles ajoutées.
func do_reload(id: String) -> int:
	var def := WeaponManager.get_def(id)
	if def == null or def.melee:
		return 0
	var need := def.mag_size - mag_for(id)
	var take := mini(need, int(ammo.get(def.ammo_type, 0)))
	mag[id] = mag_for(id) + take
	ammo[def.ammo_type] = int(ammo.get(def.ammo_type, 0)) - take
	changed.emit()
	return take

func consume_bullet(id: String) -> bool:
	if mag_for(id) <= 0:
		return false
	mag[id] = mag_for(id) - 1
	return true

## Achat réel : débite l'argent, ajoute à l'inventaire. Retourne "" si OK, sinon le message d'erreur.
func buy(id: String) -> String:
	var d := item_def(id)
	if d == null:
		return "Objet inconnu"
	if d.category == "weapon" and has_weapon(d.ref_id):
		return "Déjà possédé"
	if (d.category == "top" or d.category == "bottom" or d.category == "hair") and int(items.get(id, 0)) > 0:
		return "Déjà possédé"
	if not GameManager.spend_money(d.price):
		return "Argent insuffisant"
	match d.category:
		"weapon":
			add_weapon(d.ref_id)
			add_ammo(WeaponManager.get_def(d.ref_id).ammo_type, WeaponManager.get_def(d.ref_id).mag_size * 2)
		"ammo":
			add_ammo(d.ref_id, d.amount)
		_:
			items[id] = int(items.get(id, 0)) + 1
	changed.emit()
	return ""

func grant_item(id: String) -> void:
	var d := item_def(id)
	if d == null:
		return
	if d.category == "weapon":
		add_weapon(d.ref_id)
		var wd := WeaponManager.get_def(d.ref_id)
		if wd != null:
			add_ammo(wd.ammo_type, wd.mag_size * 3)
		equip_weapon(d.ref_id)
	elif d.category == "ammo":
		add_ammo(d.ref_id, d.amount)
	else:
		items[id] = int(items.get(id, 0)) + 1
	changed.emit()

## Habillement : slot = top | bottom | hair ; id "" = tenue d'origine.
func equip_clothing(slot: String, id: String) -> bool:
	if id != "" and int(items.get(id, 0)) <= 0:
		return false
	outfit[slot] = id
	changed.emit()
	return true

func outfit_color(slot: String) -> Variant:
	var id := str(outfit.get(slot, ""))
	if id == "":
		return null
	var d := item_def(id)
	return d.color if d != null else null

func use_heal(player: Node) -> bool:
	if int(items.get("heal_kit", 0)) <= 0 or player == null:
		return false
	if player.health >= player.max_health:
		return false
	items["heal_kit"] = int(items["heal_kit"]) - 1
	player.heal(float(item_def("heal_kit").amount))
	changed.emit()
	return true

func use_armor() -> bool:
	if int(items.get("armor_vest", 0)) <= 0 or armor >= 100.0:
		return false
	items["armor_vest"] = int(items["armor_vest"]) - 1
	armor = minf(100.0, armor + float(item_def("armor_vest").amount))
	changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"weapons": weapons.duplicate(), "ammo": ammo.duplicate(), "mag": mag.duplicate(), "items": items.duplicate(),
		"outfit": outfit.duplicate(), "equipped": equipped, "armor": armor}

func from_dict(d: Dictionary) -> void:
	weapons = Array(d.get("weapons", ["bat"]))
	ammo = Dictionary(d.get("ammo", {}))
	mag = Dictionary(d.get("mag", {}))
	items = Dictionary(d.get("items", {}))
	outfit = Dictionary(d.get("outfit", {"top": "", "bottom": "", "hair": ""}))
	equipped = str(d.get("equipped", "bat"))
	armor = float(d.get("armor", 0.0))
	changed.emit()
