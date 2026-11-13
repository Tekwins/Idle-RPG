extends SceneTree
## Headless tests for data, bag, gear, auto-fight and save.
## godot --headless --path . --import
## godot --headless --path . --script res://tests/test_core.gd

var _failed := 0


func _initialize() -> void:
	_test_data()
	_test_inventory()
	_test_equipment()
	_test_forge()
	_test_combat()
	_test_save_roundtrip()
	print("Results: %d failed" % _failed)
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   - " + what)
	else:
		_failed += 1
		push_error("FAIL - " + what)


func _test_data() -> void:
	for path: String in GameDB.ITEM_PATHS:
		_check(load(path) is ItemResource, "%s loads as ItemResource" % path)
	for path: String in GameDB.ENEMY_PATHS:
		var e := load(path) as EnemyResource
		_check(e != null, "%s loads as EnemyResource" % path)
		if e == null:
			continue
		_check(e.loot_ids.size() == e.loot_chances.size(), "%s loot lists match" % e.id)
		for loot_id in e.loot_ids:
			_check(GameDB.item(loot_id) != null, "%s drop '%s' exists" % [e.id, loot_id])
	_check(GameDB.enemies_for_stage(1).size() == 1, "only the slime at stage 1")


func _test_inventory() -> void:
	var potion := GameDB.item("small_potion")
	var inv := Inventory.new(2)
	_check(inv.add(potion, 25) == 0, "25 potions fit in 2 slots")
	_check(inv.count_at(0) == potion.max_stack and inv.count_at(1) == 25 - potion.max_stack, "stacks fill in order")
	_check(inv.add(potion, 30) == 15, "overflow returns leftover")
	_check(inv.is_full(), "bag reports full")
	_check(inv.remove_at(1, 100) == potion.max_stack, "remove clamps to stack")
	_check(inv.item_at(1) == null, "empty stack clears slot")

	var bag := Inventory.new(6)
	bag.add(GameDB.item("bone"), 3)
	bag.add(GameDB.item("iron_sword"))
	bag.add(GameDB.item("small_potion"), 2)
	bag.sort()
	_check(bag.item_at(0).id == "iron_sword", "sort puts weapons first")
	_check(bag.item_at(2).id == "bone", "sort puts materials last")

	var heal_bag := Inventory.new(4)
	heal_bag.add(GameDB.item("big_potion"))
	heal_bag.add(GameDB.item("small_potion"))
	_check(heal_bag.item_at(heal_bag.find_best_potion(20)).id == "small_potion", "small heal for small wound")
	_check(heal_bag.item_at(heal_bag.find_best_potion(100)).id == "big_potion", "big heal for big wound")


func _test_equipment() -> void:
	var p := PlayerState.new()
	var base_atk := p.attack()
	p.inventory.add(GameDB.item("wooden_sword"))
	_check(p.equip_slot(0), "equip from bag")
	_check(p.attack() == base_atk + 3, "sword adds attack")
	_check(p.inventory.item_at(0) == null, "equipped item left the bag")
	p.inventory.add(GameDB.item("iron_sword"))
	p.equip_slot(0)
	_check(p.weapon.id == "iron_sword", "swap weapon")
	_check(p.inventory.item_at(0).id == "wooden_sword", "old weapon back in bag")
	_check(p.is_upgrade(GameDB.item("steel_blade")) and not p.is_upgrade(GameDB.item("wooden_sword")), "upgrade check")
	_check(p.unequip(ItemResource.Kind.WEAPON) and p.weapon == null, "unequip to bag")


func _test_forge() -> void:
	var p := PlayerState.new()
	var atk := p.attack()
	var cost := p.upgrade_cost("attack")
	_check(not p.buy_upgrade("attack"), "no gold, no upgrade")
	p.gold = 1000
	_check(p.buy_upgrade("attack"), "buy attack upgrade")
	_check(p.attack() == atk + 2 and p.gold == 1000 - cost, "upgrade adds attack and costs gold")
	_check(p.upgrade_cost("attack") > cost, "next upgrade costs more")
	var hp_before := p.hp
	p.buy_upgrade("hp")
	_check(p.hp == hp_before + 15 and p.hp == p.max_hp(), "hp upgrade heals the gain")
	_check(p.auto_buy_upgrades() > 0 and p.gold < p.upgrade_cost("defense"), "auto forge spends gold")
	p.gold = PlayerState.POTION_PRICE
	_check(p.buy_potion() and p.gold == 0, "buy potion")


func _test_combat() -> void:
	var p := PlayerState.new()
	var combat := AutoCombat.new(p, 1234)
	combat.start()
	var t := 0.0
	while t < 1800.0:
		combat.tick(0.25)
		t += 0.25
		if p.hp > p.max_hp():
			break
	print("     30 min: level %d, stage %d (best %d), kills %d, gold %d, items %d" %
		[p.level, p.stage, p.best_stage, p.total_kills, p.gold, p.inventory.total_items()])
	_check(p.hp <= p.max_hp(), "hp never above max")
	_check(p.total_kills > 50, "kills enemies on its own")
	_check(p.gold > 0, "earns gold")
	_check(p.level >= 5, "levels up")
	_check(p.best_stage >= 3, "climbs stages")

	# Same seed, same result.
	var p2 := PlayerState.new()
	var c2 := AutoCombat.new(p2, 1234)
	c2.start()
	t = 0.0
	while t < 1800.0:
		c2.tick(0.25)
		t += 0.25
	_check(p2.total_kills == p.total_kills and p2.gold == p.gold, "seeded fight is deterministic")

	# A weak hero vs a hard stage drinks potions and falls back a stage.
	var weak := PlayerState.new()
	weak.stage = 8
	weak.inventory.add(GameDB.item("small_potion"), 5)
	var c3 := AutoCombat.new(weak, 7)
	var died := [false]
	c3.player_died.connect(func() -> void: died[0] = true)
	c3.start()
	t = 0.0
	while t < 120.0 and not died[0]:
		c3.tick(0.1)
		t += 0.1
	_check(died[0], "weak hero gets K.O.")
	_check(weak.stage == 7, "K.O. drops one stage")
	_check(weak.inventory.count_of(GameDB.item("small_potion")) < 5, "auto potion used")


func _test_save_roundtrip() -> void:
	var p := PlayerState.new()
	p.gold = 321
	p.add_xp(500)
	p.stage = 6
	p.inventory.add(GameDB.item("bone"), 7)
	p.inventory.add(GameDB.item("chainmail"))
	p.equip_and_stash(GameDB.item("iron_sword"))
	p.upgrades["defense"] = 4
	var json := JSON.stringify(p.to_dict())
	var q := PlayerState.new()
	q.from_dict(JSON.parse_string(json))
	_check(q.gold == p.gold and q.level == p.level and q.xp == p.xp, "gold, level, xp survive save")
	_check(q.stage == 6 and q.weapon != null and q.weapon.id == "iron_sword", "stage and gear survive save")
	_check(q.upgrade_level("defense") == 4 and q.defense() == p.defense(), "forge levels survive save")
	_check(q.inventory.count_of(GameDB.item("bone")) == 7 and q.inventory.count_of(GameDB.item("chainmail")) == 1, "bag survives save")
