class_name AutoCombat
extends RefCounted
## Automatic fight loop. Call tick(delta) every frame (or in fixed steps for
## offline progress). No nodes, so it runs the same in tests.

signal log_message(text: String, color: Color)
signal enemy_spawned
signal enemy_killed(enemy_name: String, xp_gain: int, gold_gain: int, drops: Array)
signal player_died
signal leveled_up(new_level: int)
signal stage_changed(new_stage: int)
signal hit(target: StringName, amount: int, crit: bool)

const KILLS_PER_STAGE := 10
const RESPAWN_TIME := 3.0
const POTION_COOLDOWN := 2.5
const POTION_THRESHOLD := 0.4
const CRIT_CHANCE := 0.1
const CRIT_MULT := 1.6
const STAGE_SCALE := 0.22
const BOSS_HP_MULT := 3.0
const BOSS_ATK_MULT := 1.35
const BOSS_REWARD_MULT := 3.0

const COLOR_INFO := Color(0.7, 0.72, 0.8)
const COLOR_KILL := Color(0.55, 0.9, 0.55)
const COLOR_GOLD := Color(1.0, 0.85, 0.35)
const COLOR_BAD := Color(1.0, 0.45, 0.4)
const COLOR_LEVEL := Color(0.45, 0.85, 1.0)

var player: PlayerState
var rng := RandomNumberGenerator.new()
var enemy: EnemyResource = null
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_attack: int = 0
var enemy_defense: int = 0
var enemy_is_boss: bool = false
var player_timer: float = 0.0
var enemy_timer: float = 0.0
var respawn_left: float = 0.0
var potion_cooldown: float = 0.0


func _init(p_player: PlayerState, p_seed: int = -1) -> void:
	player = p_player
	if p_seed >= 0:
		rng.seed = p_seed
	else:
		rng.randomize()


func start() -> void:
	if player.hp <= 0:
		player.hp = player.max_hp()
	spawn_enemy()


func is_respawning() -> bool:
	return respawn_left > 0.0


func stage_scale() -> float:
	return 1.0 + STAGE_SCALE * float(player.stage - 1)


func enemy_display_name() -> String:
	if enemy == null:
		return ""
	return ("BOSS · " if enemy_is_boss else "") + enemy.display_name


func spawn_enemy() -> void:
	var pool := GameDB.enemies_for_stage(player.stage)
	if pool.is_empty():
		push_error("AutoCombat: no enemy data")
		return
	# Newest unlocked enemies show up most.
	var first := maxi(0, pool.size() - 3)
	enemy = pool[rng.randi_range(first, pool.size() - 1)]
	enemy_is_boss = player.kills_in_stage == KILLS_PER_STAGE - 1
	var s := stage_scale()
	enemy_max_hp = maxi(1, roundi(enemy.max_hp * s * (BOSS_HP_MULT if enemy_is_boss else 1.0)))
	enemy_hp = enemy_max_hp
	enemy_attack = maxi(1, roundi(enemy.attack * s * (BOSS_ATK_MULT if enemy_is_boss else 1.0)))
	enemy_defense = roundi(enemy.defense * s)
	player_timer = 0.0
	enemy_timer = 0.0
	if enemy_is_boss:
		_log("Un boss approche : %s !" % enemy.display_name, COLOR_BAD)
	enemy_spawned.emit()


func tick(delta: float) -> void:
	if respawn_left > 0.0:
		respawn_left -= delta
		if respawn_left <= 0.0:
			respawn_left = 0.0
			player.hp = player.max_hp()
			_log("Tu reprends le combat.", COLOR_INFO)
			spawn_enemy()
			player.changed.emit()
		return
	if enemy == null:
		spawn_enemy()
		if enemy == null:
			return
	potion_cooldown = maxf(0.0, potion_cooldown - delta)
	_try_auto_potion()
	player_timer += delta * player.attack_speed()
	enemy_timer += delta * enemy.attack_speed
	# Resolve attacks in the order they happened, so big deltas stay fair.
	while respawn_left <= 0.0 and enemy != null and (player_timer >= 1.0 or enemy_timer >= 1.0):
		var p_ago := (player_timer - 1.0) / player.attack_speed()
		var e_ago := (enemy_timer - 1.0) / maxf(0.01, enemy.attack_speed)
		if player_timer >= 1.0 and (enemy_timer < 1.0 or p_ago >= e_ago):
			player_timer -= 1.0
			_player_attack()
		else:
			enemy_timer -= 1.0
			_enemy_attack()
			_try_auto_potion()


func damage(atk: int, def: int, crit: bool) -> int:
	# atk²/(atk+def): defense helps a lot but never makes you immune.
	var base := float(atk * atk) / float(maxi(1, atk + def))
	var roll := base * rng.randf_range(0.9, 1.1) * (CRIT_MULT if crit else 1.0)
	return maxi(1, roundi(roll))


func _player_attack() -> void:
	var crit := rng.randf() < CRIT_CHANCE
	var dmg := damage(player.attack(), enemy_defense, crit)
	enemy_hp -= dmg
	hit.emit(&"enemy", dmg, crit)
	if enemy_hp <= 0:
		_on_enemy_killed()


func _enemy_attack() -> void:
	var dmg := damage(enemy_attack, player.defense(), false)
	player.hp -= dmg
	hit.emit(&"player", dmg, false)
	if player.hp <= 0:
		_on_player_died()


func _try_auto_potion() -> void:
	if potion_cooldown > 0.0 or player.hp <= 0:
		return
	if float(player.hp) >= float(player.max_hp()) * POTION_THRESHOLD:
		return
	var index := player.inventory.find_best_potion(player.max_hp() - player.hp)
	if index < 0:
		return
	var item := player.inventory.item_at(index)
	if player.use_slot(index):
		potion_cooldown = POTION_COOLDOWN
		_log("Potion bue : %s (+%d PV)" % [item.display_name, item.heal], COLOR_LEVEL)


func _on_enemy_killed() -> void:
	var s := stage_scale() * (BOSS_REWARD_MULT if enemy_is_boss else 1.0)
	var xp_gain := maxi(1, roundi(enemy.xp * s))
	var gold_gain := maxi(1, roundi(enemy.gold * s))
	var enemy_name := enemy_display_name()
	player.gold += gold_gain
	player.total_kills += 1
	_log("%s vaincu ! +%d XP, +%d or" % [enemy_name, xp_gain, gold_gain], COLOR_KILL)
	var drops := _roll_loot()
	for item in drops:
		_give_item(item)
	var gained := player.add_xp(xp_gain)
	if gained > 0:
		_log("Niveau %d ! PV au max." % player.level, COLOR_LEVEL)
		leveled_up.emit(player.level)
	enemy_killed.emit(enemy_name, xp_gain, gold_gain, drops)
	if player.auto_forge:
		var bought := player.auto_buy_upgrades()
		if bought > 0:
			_log("Forge : %d amélioration(s) achetée(s)." % bought, COLOR_GOLD)
	player.kills_in_stage += 1
	if player.kills_in_stage >= KILLS_PER_STAGE:
		player.kills_in_stage = 0
		player.stage += 1
		player.best_stage = maxi(player.best_stage, player.stage)
		_log("Étape %d atteinte." % player.stage, COLOR_GOLD)
		stage_changed.emit(player.stage)
	player.changed.emit()
	spawn_enemy()


func _roll_loot() -> Array[ItemResource]:
	var drops: Array[ItemResource] = []
	var chance_mult := 2.0 if enemy_is_boss else 1.0
	for i in enemy.loot_ids.size():
		var chance: float = enemy.loot_chances[i] if i < enemy.loot_chances.size() else 0.0
		if rng.randf() < chance * chance_mult:
			var item := GameDB.item(enemy.loot_ids[i])
			if item != null:
				drops.append(item)
	return drops


func _give_item(item: ItemResource) -> void:
	if player.auto_sell_materials and item.kind == ItemResource.Kind.MATERIAL:
		player.gold += item.value
		_log("  %s vendu (+%d or)" % [item.display_name, item.value], COLOR_GOLD)
		return
	if player.auto_equip and player.is_upgrade(item):
		player.equip_and_stash(item)
		_log("  Nouvel équipement : %s" % item.display_name, item.rarity_color())
		return
	var left := player.inventory.add(item)
	if left > 0:
		player.gold += item.value * left
		_log("  Sac plein : %s vendu (+%d or)" % [item.display_name, item.value * left], COLOR_GOLD)
	else:
		_log("  Butin : %s" % item.display_name, item.rarity_color())


func _on_player_died() -> void:
	var killer := enemy_display_name()
	player.hp = 0
	respawn_left = RESPAWN_TIME
	var old_stage := player.stage
	player.stage = maxi(1, player.stage - 1)
	player.kills_in_stage = 0
	enemy = null
	_log("K.O. face à %s… Retour à l'étape %d." % [killer, player.stage], COLOR_BAD)
	player_died.emit()
	if player.stage != old_stage:
		stage_changed.emit(player.stage)
	player.changed.emit()


func _log(text: String, color: Color) -> void:
	log_message.emit(text, color)
