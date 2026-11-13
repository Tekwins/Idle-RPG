class_name ItemResource
extends Resource
## Static item data. Shared by reference: never mutate at runtime.

enum Kind { WEAPON, ARMOR, CONSUMABLE, MATERIAL }

const KIND_NAMES: Array[String] = ["Arme", "Armure", "Consommable", "Matériau"]
const RARITY_NAMES: Array[String] = ["Commun", "Rare", "Épique", "Légendaire"]
const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),
	Color(0.35, 0.62, 1.0),
	Color(0.72, 0.42, 1.0),
	Color(1.0, 0.66, 0.15),
]

@export var id: String = ""
@export var display_name: String = "Objet"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.MATERIAL
@export_range(0, 3) var rarity: int = 0
@export var attack: int = 0
@export var defense: int = 0
@export var max_hp_bonus: int = 0
@export var heal: int = 0
@export var value: int = 1
@export var max_stack: int = 99


func is_equipment() -> bool:
	return kind == Kind.WEAPON or kind == Kind.ARMOR


## Rough power score, used by auto-equip to compare gear.
func power() -> float:
	return attack * 2.0 + defense * 2.0 + max_hp_bonus / 5.0


func rarity_color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


func tooltip() -> String:
	var lines := PackedStringArray()
	lines.append("%s  (%s · %s)" % [display_name, RARITY_NAMES[clampi(rarity, 0, 3)], KIND_NAMES[kind]])
	if attack != 0:
		lines.append("+%d Attaque" % attack)
	if defense != 0:
		lines.append("+%d Défense" % defense)
	if max_hp_bonus != 0:
		lines.append("+%d PV max" % max_hp_bonus)
	if heal != 0:
		lines.append("Soigne %d PV" % heal)
	if description != "":
		lines.append(description)
	lines.append("Valeur : %d or" % value)
	return "\n".join(lines)
