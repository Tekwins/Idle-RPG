class_name GameDB
extends RefCounted
## Static registry of item and enemy data. Paths are listed by hand so
## exported builds find them (directory listing is unreliable in exports).

const ITEM_PATHS := [
	"res://data/items/wooden_sword.tres",
	"res://data/items/iron_sword.tres",
	"res://data/items/steel_blade.tres",
	"res://data/items/dragon_fang.tres",
	"res://data/items/leather_armor.tres",
	"res://data/items/chainmail.tres",
	"res://data/items/plate_armor.tres",
	"res://data/items/dragon_scale.tres",
	"res://data/items/small_potion.tres",
	"res://data/items/big_potion.tres",
	"res://data/items/slime_gel.tres",
	"res://data/items/wolf_pelt.tres",
	"res://data/items/bone.tres",
	"res://data/items/orc_tusk.tres",
	"res://data/items/scale_shard.tres",
]

## Sorted by min_stage.
const ENEMY_PATHS := [
	"res://data/enemies/slime.tres",
	"res://data/enemies/wolf.tres",
	"res://data/enemies/skeleton.tres",
	"res://data/enemies/orc.tres",
	"res://data/enemies/dragon_whelp.tres",
]

static var _items: Dictionary = {}
static var _enemies: Array[EnemyResource] = []


static func _ensure_loaded() -> void:
	if not _items.is_empty():
		return
	for path: String in ITEM_PATHS:
		var item := load(path) as ItemResource
		if item == null:
			push_error("GameDB: %s did not load as ItemResource" % path)
			continue
		_items[item.id] = item
	for path: String in ENEMY_PATHS:
		var enemy := load(path) as EnemyResource
		if enemy == null:
			push_error("GameDB: %s did not load as EnemyResource" % path)
			continue
		_enemies.append(enemy)


static func item(item_id: String) -> ItemResource:
	_ensure_loaded()
	if item_id == "" or not _items.has(item_id):
		return null
	return _items[item_id] as ItemResource


static func all_enemies() -> Array[EnemyResource]:
	_ensure_loaded()
	return _enemies


## Enemies unlocked at this stage, oldest first. Never empty.
static func enemies_for_stage(stage: int) -> Array[EnemyResource]:
	_ensure_loaded()
	var pool: Array[EnemyResource] = []
	for enemy in _enemies:
		if enemy.min_stage <= stage:
			pool.append(enemy)
	if pool.is_empty() and not _enemies.is_empty():
		pool.append(_enemies[0])
	return pool
