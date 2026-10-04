class_name ShopUI
extends BasePanel
## Boutique : onglets (Armes, Munitions, Soins, Hauts, Bas, Cheveux), achat réel via InventoryManager.buy(), équipement d'armes et de vêtements.
## Flux : INPUT (bouton) -> InventoryManager.buy/equip -> état (argent, inventaire) -> UI (rafraîchie) -> SAVE (autosave en partie, save_profile au menu).
## Ouverte par game.gd open_shop() et par le menu principal (rubrique Magasins). [NON TESTÉ DANS GODOT]

const TABS := [
	["weapon", "Armes"], ["ammo", "Munitions"], ["heal", "Soins"],
	["top", "Hauts"], ["bottom", "Bas"], ["hair", "Cheveux"],
]

var _tab := "weapon"
var _tabs_row: HBoxContainer
var _list: VBoxContainer

static func open(host: Node) -> void:
	BasePanel.show_panel(host, ShopUI.new())

func _title() -> String:
	return "MAGASIN"

func _header_info() -> String:
	return "%d $" % GameManager.money

func _build_content() -> void:
	_tabs_row = HBoxContainer.new()
	_tabs_row.add_theme_constant_override("separation", 8)
	body.add_child(_tabs_row)
	var holder := VBoxContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(holder)
	_list = UIKit.scroll_column(holder, 8)
	_rebuild()

func _categories(tab: String) -> Array:
	return ["heal", "armor"] if tab == "heal" else [tab]

func _items_for(tab: String) -> Array:
	var out: Array = []
	for c in _categories(tab):
		out.append_array(InventoryManager.items_of(c))
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return a.price < b.price if a.price != b.price else a.id < b.id)
	return out

func _rebuild() -> void:
	for c in _tabs_row.get_children():
		c.queue_free()
	for t in TABS:
		var tid: String = t[0]
		var b := UIKit.button(str(t[1]), Color(0.3, 0.24, 0.08) if tid == _tab else Color(0.16, 0.18, 0.23), 52.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_tab = tid
			_rebuild())
		_tabs_row.add_child(b)
	for c in _list.get_children():
		c.queue_free()
	var items := _items_for(_tab)
	if items.is_empty():
		_list.add_child(UIKit.label("Rien à vendre dans cette catégorie.", 22, Color(0.8, 0.8, 0.85)))
	for d in items:
		_list.add_child(_row(d))
	_refresh_header()

func _owned_text(d: ItemDef) -> String:
	match d.category:
		"weapon":
			return "Possédée · réserve %d" % InventoryManager.reserve_for(d.ref_id) if InventoryManager.has_weapon(d.ref_id) else ""
		"ammo":
			return "Réserve : %d" % int(InventoryManager.ammo.get(d.ref_id, 0))
		"heal", "armor":
			var n := int(InventoryManager.items.get(d.id, 0))
			return "En stock : %d" % n if n > 0 else ""
		_:
			return "Possédé" if int(InventoryManager.items.get(d.id, 0)) > 0 else ""

func _row(d: ItemDef) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.style(UIKit.CARD, Color(1, 1, 1, 0.08), 1))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	if d.category in ["top", "bottom", "hair"]:
		var sw := ColorRect.new()
		sw.color = d.color
		sw.custom_minimum_size = Vector2(46, 46)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UIKit.label(d.display_name, 24, Color.WHITE))
	if d.description != "":
		info.add_child(UIKit.label(d.description, 18, Color(0.75, 0.78, 0.85)))
	var owned := _owned_text(d)
	if owned != "":
		info.add_child(UIKit.label(owned, 18, Color(0.5, 1.0, 0.6)))
	h.add_child(UIKit.label("%d $" % d.price, 24, UIKit.GOLD, false))
	if d.id == "heal_kit" and int(InventoryManager.items.get(d.id, 0)) > 0:
		var use := UIKit.button("Activer", Color(0.15, 0.3, 0.4), 60.0)
		use.custom_minimum_size = Vector2(150, 60)
		use.disabled = not GameManager.in_game
		use.pressed.connect(_activate_heal)
		h.add_child(use)
	var act := _action_button(d)
	act.custom_minimum_size = Vector2(190, 60)
	h.add_child(act)
	return card

func _action_button(d: ItemDef) -> Button:
	var wearable: bool = d.category in ["top", "bottom", "hair"]
	var owned_wear: bool = wearable and int(InventoryManager.items.get(d.id, 0)) > 0
	if d.category == "weapon" and InventoryManager.has_weapon(d.ref_id):
		var eq := InventoryManager.equipped == d.ref_id
		var b := UIKit.button("Équipée" if eq else "Équiper", Color(0.15, 0.3, 0.4), 60.0)
		b.disabled = eq
		b.pressed.connect(func() -> void:
			InventoryManager.equip_weapon(d.ref_id)
			_after_action())
		return b
	if owned_wear:
		var worn := str(InventoryManager.outfit.get(d.category, "")) == d.id
		var wb := UIKit.button("Retirer" if worn else "Porter", Color(0.15, 0.3, 0.4), 60.0)
		wb.pressed.connect(func() -> void:
			InventoryManager.equip_clothing(d.category, "" if worn else d.id)
			_after_action())
		return wb
	var buy := UIKit.button("Acheter", Color(0.15, 0.4, 0.2), 60.0)
	buy.disabled = GameManager.money < d.price
	buy.pressed.connect(func() -> void:
		var err := InventoryManager.buy(d.id)
		if err != "":
			UIManager.toast(err, Color(1, 0.4, 0.4))
		else:
			UIManager.toast("Acheté : %s" % d.display_name, Color(0.5, 1, 0.6))
			if wearable:
				InventoryManager.equip_clothing(d.category, d.id)
			_after_action())
	return buy

func _activate_heal() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and InventoryManager.use_heal(pl):
		UIManager.toast("Soin activé", Color(0.5, 1, 0.5), 1.2)
		_after_action()
	else:
		UIManager.toast("Santé déjà au maximum", Color(1, 0.8, 0.4), 1.2)

func _after_action() -> void:
	if GameManager.in_game:
		SaveManager.autosave_if_playing()
	else:
		SaveManager.save_profile()
	_rebuild()
