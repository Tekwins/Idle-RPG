class_name PlayerState
extends RefCounted
## Hero progress: level, gold, stage, gear and bag. Pure data + rules.

signal changed

const INVENTORY_SIZE := 24
## Forge: permanent stat upgrades bought with gold.
## kind -> [label, base cost, gain per level]
const UPGRADES := {
	"attack": ["Attaque", 20, 2],
	"defense": ["Défense", 20, 1],
	"hp": ["PV max", 15, 15],
}
const UPGRADE_COST_GROWTH := 1.18
const POTION_PRICE := 12

var level: int = 1
var xp: int = 0
var gold: int = 0
var hp: int = 100
var stage: int = 1
var best_stage: int = 1
var kills_in_stage: int = 0
var total_kills: int = 0
var weapon: ItemResource = null
var armor: ItemResource = null
var auto_equip: bool = true
var auto_sell_materials: bool = false
var auto_forge: bool = false
var upgrades: Dictionary = {"attack": 0, "defense": 0, "hp": 0}
var inventory: Inventory = Inventory.new(INVENTORY_SIZE)


func _init() -> void:
	hp = max_hp()


func _gear_bonus(stat: String) -> int:
	var total := 0
	for item: ItemResource in [weapon, armor]:
		if item != null:
			total += int(item.get(stat))
	return total


func max_hp() -> int:
	return 100 + 12 * (level - 1) + _gear_bonus("max_hp_bonus") + upgrade_bonus("hp")


func attack() -> int:
	return 6 + 2 * (level - 1) + _gear_bonus("attack") + upgrade_bonus("attack")


func defense() -> int:
	return 2 + (level - 1) + _gear_bonus("defense") + upgrade_bonus("defense")


## Attacks per second.
func attack_speed() -> float:
	return minf(2.5, 1.0 + 0.03 * (level - 1))


func xp_to_next() -> int:
	return roundi(25.0 * pow(level, 2.1))


## Returns levels gained. Level up heals fully.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	if gained > 0:
		hp = max_hp()
	changed.emit()
	return gained


func upgrade_level(kind: String) -> int:
	return int(upgrades.get(kind, 0))


func upgrade_bonus(kind: String) -> int:
	return upgrade_level(kind) * int(UPGRADES[kind][2])


func upgrade_cost(kind: String) -> int:
	return roundi(float(UPGRADES[kind][1]) * pow(UPGRADE_COST_GROWTH, upgrade_level(kind)))


func buy_upgrade(kind: String) -> bool:
	if not UPGRADES.has(kind) or gold < upgrade_cost(kind):
		return false
	var old_max := max_hp()
	gold -= upgrade_cost(kind)
	upgrades[kind] = upgrade_level(kind) + 1
	if hp > 0:
		hp += max_hp() - old_max
	changed.emit()
	return true


## Buys the cheapest upgrade while gold allows. Returns how many were bought.
func auto_buy_upgrades() -> int:
	var bought := 0
	while true:
		var cheapest := ""
		for kind: String in UPGRADES:
			if cheapest == "" or upgrade_cost(kind) < upgrade_cost(cheapest):
				cheapest = kind
		if not buy_upgrade(cheapest):
			break
		bought += 1
	return bought


func buy_potion() -> bool:
	if gold < POTION_PRICE or inventory.add(GameDB.item("small_potion")) > 0:
		return false
	gold -= POTION_PRICE
	changed.emit()
	return true


func equipped(kind: ItemResource.Kind) -> ItemResource:
	match kind:
		ItemResource.Kind.WEAPON:
			return weapon
		ItemResource.Kind.ARMOR:
			return armor
	return null


func is_upgrade(item: ItemResource) -> bool:
	if item == null or not item.is_equipment():
		return false
	var current := equipped(item.kind)
	return current == null or item.power() > current.power()


## Equips `item` (not taken from the bag) and stores the old piece in the bag.
## If the bag is full the old piece is sold. Returns gold earned that way.
func equip_and_stash(item: ItemResource) -> int:
	var old: ItemResource = null
	match item.kind:
		ItemResource.Kind.WEAPON:
			old = weapon
			weapon = item
		ItemResource.Kind.ARMOR:
			old = armor
			armor = item
		_:
			return 0
	var earned := 0
	if old != null and inventory.add(old) > 0:
		earned = old.value
		gold += earned
	hp = mini(hp, max_hp())
	changed.emit()
	return earned


func equip_slot(index: int) -> bool:
	var item := inventory.item_at(index)
	if item == null or not item.is_equipment():
		return false
	inventory.remove_at(index, 1)
	equip_and_stash(item)
	return true


func unequip(kind: ItemResource.Kind) -> bool:
	var item := equipped(kind)
	if item == null or inventory.add(item) > 0:
		return false
	if kind == ItemResource.Kind.WEAPON:
		weapon = null
	else:
		armor = null
	hp = mini(hp, max_hp())
	changed.emit()
	return true


func use_slot(index: int) -> bool:
	var item := inventory.item_at(index)
	if item == null or item.kind != ItemResource.Kind.CONSUMABLE or hp >= max_hp() or hp <= 0:
		return false
	inventory.remove_at(index, 1)
	hp = mini(max_hp(), hp + item.heal)
	changed.emit()
	return true


## Click action: equip gear, drink potion. Materials do nothing.
func activate_slot(index: int) -> bool:
	var item := inventory.item_at(index)
	if item == null:
		return false
	if item.is_equipment():
		return equip_slot(index)
	return use_slot(index)


func sell_slot(index: int, count: int = 1) -> int:
	var item := inventory.item_at(index)
	if item == null:
		return 0
	var earned := inventory.remove_at(index, count) * item.value
	gold += earned
	changed.emit()
	return earned


func sell_all_materials() -> int:
	var earned := 0
	for i in inventory.size:
		var item := inventory.item_at(i)
		if item != null and item.kind == ItemResource.Kind.MATERIAL:
			earned += inventory.remove_at(i, inventory.count_at(i)) * item.value
	gold += earned
	changed.emit()
	return earned


func to_dict() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"gold": gold,
		"hp": hp,
		"stage": stage,
		"best_stage": best_stage,
		"kills_in_stage": kills_in_stage,
		"total_kills": total_kills,
		"weapon": weapon.id if weapon != null else "",
		"armor": armor.id if armor != null else "",
		"auto_equip": auto_equip,
		"auto_sell_materials": auto_sell_materials,
		"auto_forge": auto_forge,
		"upgrades": upgrades.duplicate(),
		"inventory": inventory.to_array(),
	}


func from_dict(d: Dictionary) -> void:
	level = maxi(1, int(d.get("level", 1)))
	xp = maxi(0, int(d.get("xp", 0)))
	gold = maxi(0, int(d.get("gold", 0)))
	stage = maxi(1, int(d.get("stage", 1)))
	best_stage = maxi(stage, int(d.get("best_stage", 1)))
	kills_in_stage = clampi(int(d.get("kills_in_stage", 0)), 0, 9)
	total_kills = maxi(0, int(d.get("total_kills", 0)))
	weapon = GameDB.item(str(d.get("weapon", "")))
	armor = GameDB.item(str(d.get("armor", "")))
	auto_equip = bool(d.get("auto_equip", true))
	auto_sell_materials = bool(d.get("auto_sell_materials", false))
	auto_forge = bool(d.get("auto_forge", false))
	var up_data = d.get("upgrades", {})
	for kind: String in UPGRADES:
		upgrades[kind] = maxi(0, int(up_data.get(kind, 0))) if up_data is Dictionary else 0
	var inv_data = d.get("inventory", [])
	inventory.from_array(inv_data if inv_data is Array else [])
	hp = clampi(int(d.get("hp", max_hp())), 1, max_hp())
	changed.emit()
