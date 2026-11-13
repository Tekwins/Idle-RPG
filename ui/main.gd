extends Control
## Main screen, built in code: hero (left), fight (middle), bag (right).

const SLOT_SIZE := Vector2(84, 72)
const GRID_COLUMNS := 6
const MAX_LOG_LINES := 150

const BG := Color(0.07, 0.075, 0.1)
const PANEL_BG := Color(0.11, 0.12, 0.16)
const PANEL_BORDER := Color(0.24, 0.26, 0.34)
const TITLE_COLOR := Color(1.0, 0.84, 0.4)
const MUTED := Color(0.62, 0.64, 0.72)

var _columns: HBoxContainer
var _level_label: Label
var _xp_bar: ProgressBar
var _stat_values: Dictionary = {}
var _weapon_button: Button
var _armor_button: Button
var _auto_equip_box: CheckBox
var _auto_sell_box: CheckBox
var _auto_forge_box: CheckBox
var _forge_buttons: Dictionary = {}
var _potion_button: Button

var _stage_label: Label
var _stage_bar: ProgressBar
var _enemy_label: Label
var _enemy_bar: ProgressBar
var _player_bar: ProgressBar
var _status_label: Label
var _log: RichTextLabel

var _bag_label: Label
var _grid: GridContainer
var _slot_buttons: Array[Button] = []
var _detail: RichTextLabel
var _slot_styles: Array[StyleBoxFlat] = []
var _slot_hover_styles: Array[StyleBoxFlat] = []
var _slot_empty_style: StyleBoxFlat


func _ready() -> void:
	_build_styles()
	_build_layout()
	var p := Game.player
	p.changed.connect(_refresh_hero)
	p.inventory.changed.connect(_refresh_bag)
	Game.combat.log_message.connect(_append_log)
	Game.combat.enemy_spawned.connect(_refresh_enemy_name)
	_refresh_hero()
	_refresh_bag()
	_refresh_enemy_name()
	_append_log("Bienvenue dans Idle Quest. Ton héros se bat tout seul.", MUTED)
	_slot_buttons[0].grab_focus()
	if Game.offline_report != "":
		_show_offline_report.call_deferred(Game.offline_report)
		Game.offline_report = ""


func _process(_delta: float) -> void:
	var p := Game.player
	var c := Game.combat
	_set_bar(_player_bar, maxi(0, p.hp), p.max_hp(), "Héros  %d / %d PV" % [maxi(0, p.hp), p.max_hp()])
	if c.is_respawning() or c.enemy == null:
		_set_bar(_enemy_bar, 0, 1, "—")
		_status_label.text = "K.O. — retour dans %.1f s" % c.respawn_left
		_status_label.add_theme_color_override("font_color", AutoCombat.COLOR_BAD)
	else:
		_set_bar(_enemy_bar, maxi(0, c.enemy_hp), c.enemy_max_hp, "%d / %d PV" % [maxi(0, c.enemy_hp), c.enemy_max_hp])
		_status_label.text = "Combat en cours…  ATQ ennemi %d · DÉF ennemi %d" % [c.enemy_attack, c.enemy_defense]
		_status_label.add_theme_color_override("font_color", MUTED)


# ---------------------------------------------------------------- layout

func _build_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 14)
	margin.add_child(_columns)

	_build_hero_panel(_panel("Héros", 0.9))
	_build_combat_panel(_panel("Combat", 1.15))
	_build_bag_panel(_panel("Inventaire", 1.3))


func _panel(title: String, ratio: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = ratio
	panel.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 2, 12))
	_columns.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", TITLE_COLOR)
	vb.add_child(label)
	return vb


func _build_hero_panel(vb: VBoxContainer) -> void:
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 18)
	vb.add_child(_level_label)
	_xp_bar = _bar(Color(0.35, 0.55, 1.0))
	vb.add_child(_xp_bar)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	vb.add_child(grid)
	for key in ["Attaque", "Défense", "Vitesse", "PV max", "Or", "Étape record", "Victoires"]:
		var k := Label.new()
		k.text = key
		k.add_theme_color_override("font_color", MUTED)
		grid.add_child(k)
		var v := Label.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
		_stat_values[key] = v
	(_stat_values["Or"] as Label).add_theme_color_override("font_color", AutoCombat.COLOR_GOLD)

	vb.add_child(_section("Équipement"))
	_weapon_button = _equip_button(ItemResource.Kind.WEAPON)
	vb.add_child(_weapon_button)
	_armor_button = _equip_button(ItemResource.Kind.ARMOR)
	vb.add_child(_armor_button)

	vb.add_child(_section("Options"))
	_auto_equip_box = CheckBox.new()
	_auto_equip_box.text = "Équiper le meilleur butin"
	_auto_equip_box.toggled.connect(func(on: bool) -> void: Game.player.auto_equip = on)
	vb.add_child(_auto_equip_box)
	_auto_sell_box = CheckBox.new()
	_auto_sell_box.text = "Vendre les matériaux"
	_auto_sell_box.toggled.connect(func(on: bool) -> void: Game.player.auto_sell_materials = on)
	vb.add_child(_auto_sell_box)
	_auto_forge_box = CheckBox.new()
	_auto_forge_box.text = "Forge automatique"
	_auto_forge_box.tooltip_text = "Dépense l'or tout seul dans l'amélioration la moins chère."
	_auto_forge_box.toggled.connect(func(on: bool) -> void: Game.player.auto_forge = on)
	vb.add_child(_auto_forge_box)

	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "Vitesse"
	speed_label.add_theme_color_override("font_color", MUTED)
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(speed_label)
	var group := ButtonGroup.new()
	for mult in [1, 2, 5]:
		var b := Button.new()
		b.text = "×%d" % mult
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = is_equal_approx(Game.speed, float(mult))
		b.pressed.connect(func() -> void: Game.speed = float(mult))
		speed_row.add_child(b)
	vb.add_child(speed_row)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var reset := Button.new()
	reset.text = "Nouvelle partie"
	reset.pressed.connect(_confirm_reset)
	vb.add_child(reset)


func _build_combat_panel(vb: VBoxContainer) -> void:
	_stage_label = Label.new()
	_stage_label.add_theme_font_size_override("font_size", 18)
	vb.add_child(_stage_label)
	_stage_bar = _bar(Color(0.85, 0.65, 0.2))
	vb.add_child(_stage_bar)

	_enemy_label = Label.new()
	_enemy_label.add_theme_font_size_override("font_size", 26)
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_enemy_label)
	_enemy_bar = _bar(Color(0.8, 0.25, 0.25))
	_enemy_bar.custom_minimum_size.y = 30
	vb.add_child(_enemy_bar)

	var vs := Label.new()
	vs.text = "⚔"
	vs.add_theme_font_size_override("font_size", 22)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(vs)

	_player_bar = _bar(Color(0.25, 0.7, 0.35))
	_player_bar.custom_minimum_size.y = 30
	vb.add_child(_player_bar)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_status_label)

	vb.add_child(_section("Forge"))
	var forge := GridContainer.new()
	forge.columns = 2
	forge.add_theme_constant_override("h_separation", 6)
	forge.add_theme_constant_override("v_separation", 6)
	vb.add_child(forge)
	for kind: String in PlayerState.UPGRADES:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_forge_pressed.bind(kind))
		forge.add_child(b)
		_forge_buttons[kind] = b
	_potion_button = Button.new()
	_potion_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_potion_button.text = "Petite potion · %d or" % PlayerState.POTION_PRICE
	_potion_button.pressed.connect(_on_buy_potion)
	forge.add_child(_potion_button)

	vb.add_child(_section("Journal"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_stylebox_override("normal", _box(Color(0.06, 0.065, 0.09), PANEL_BORDER, 1, 8))
	vb.add_child(_log)


func _build_bag_panel(vb: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	_bag_label = Label.new()
	_bag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_label.add_theme_color_override("font_color", MUTED)
	header.add_child(_bag_label)
	var sort_button := Button.new()
	sort_button.text = "Trier"
	sort_button.pressed.connect(func() -> void: Game.player.inventory.sort())
	header.add_child(sort_button)
	var sell_button := Button.new()
	sell_button.text = "Vendre matériaux"
	sell_button.pressed.connect(_on_sell_materials)
	header.add_child(sell_button)
	vb.add_child(header)

	var center := CenterContainer.new()
	vb.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	center.add_child(_grid)
	for i in PlayerState.INVENTORY_SIZE:
		var b := Button.new()
		b.custom_minimum_size = SLOT_SIZE
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_slot_pressed.bind(i))
		b.gui_input.connect(_on_slot_gui_input.bind(i))
		b.mouse_entered.connect(_show_detail.bind(i))
		b.focus_entered.connect(_show_detail.bind(i))
		var count := Label.new()
		count.name = "Count"
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_right = -5
		count.offset_bottom = -2
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.add_theme_font_size_override("font_size", 12)
		b.add_child(count)
		_grid.add_child(b)
		_slot_buttons.append(b)

	vb.add_child(_section("Détails"))
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_stylebox_override("normal", _box(Color(0.06, 0.065, 0.09), PANEL_BORDER, 1, 8))
	vb.add_child(_detail)
	var hint := Label.new()
	hint.text = "Clic : équiper / boire   ·   Clic droit : vendre 1   ·   Maj + clic droit : vendre la pile"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	vb.add_child(hint)


# ---------------------------------------------------------------- refresh

func _refresh_hero() -> void:
	var p := Game.player
	_level_label.text = "Niveau %d" % p.level
	_set_bar(_xp_bar, p.xp, p.xp_to_next(), "XP %d / %d" % [p.xp, p.xp_to_next()])
	(_stat_values["Attaque"] as Label).text = str(p.attack())
	(_stat_values["Défense"] as Label).text = str(p.defense())
	(_stat_values["Vitesse"] as Label).text = "%.2f coups/s" % p.attack_speed()
	(_stat_values["PV max"] as Label).text = str(p.max_hp())
	(_stat_values["Or"] as Label).text = str(p.gold)
	(_stat_values["Étape record"] as Label).text = str(p.best_stage)
	(_stat_values["Victoires"] as Label).text = str(p.total_kills)
	_fill_equip_button(_weapon_button, "Arme", p.weapon)
	_fill_equip_button(_armor_button, "Armure", p.armor)
	_auto_equip_box.set_pressed_no_signal(p.auto_equip)
	_auto_sell_box.set_pressed_no_signal(p.auto_sell_materials)
	_auto_forge_box.set_pressed_no_signal(p.auto_forge)
	for kind: String in _forge_buttons:
		var b := _forge_buttons[kind] as Button
		var info: Array = PlayerState.UPGRADES[kind]
		var cost := p.upgrade_cost(kind)
		b.text = "%s +%d  (niv. %d) · %d or" % [info[0], info[2], p.upgrade_level(kind), cost]
		b.disabled = p.gold < cost
	_potion_button.disabled = p.gold < PlayerState.POTION_PRICE
	_stage_label.text = "Étape %d" % p.stage
	_set_bar(_stage_bar, p.kills_in_stage, AutoCombat.KILLS_PER_STAGE,
		"%d / %d ennemis  (boss au %de)" % [p.kills_in_stage, AutoCombat.KILLS_PER_STAGE, AutoCombat.KILLS_PER_STAGE])


func _refresh_enemy_name() -> void:
	var c := Game.combat
	_enemy_label.text = c.enemy_display_name()
	_enemy_label.add_theme_color_override("font_color",
		AutoCombat.COLOR_BAD if c.enemy_is_boss else Color(0.95, 0.95, 0.95))


func _refresh_bag() -> void:
	var inv := Game.player.inventory
	_bag_label.text = "%d / %d emplacements" % [inv.used_slots(), inv.size]
	for i in _slot_buttons.size():
		var b := _slot_buttons[i]
		var count := b.get_node("Count") as Label
		var item := inv.item_at(i)
		if item == null:
			b.text = ""
			b.tooltip_text = ""
			count.text = ""
			b.add_theme_stylebox_override("normal", _slot_empty_style)
			b.add_theme_stylebox_override("hover", _slot_empty_style)
			b.remove_theme_color_override("font_color")
			continue
		var n := inv.count_at(i)
		b.text = item.display_name
		b.tooltip_text = item.tooltip()
		count.text = "×%d" % n if n > 1 else ""
		b.add_theme_stylebox_override("normal", _slot_styles[item.rarity])
		b.add_theme_stylebox_override("hover", _slot_hover_styles[item.rarity])
		b.add_theme_color_override("font_color", item.rarity_color())
		b.add_theme_color_override("font_hover_color", item.rarity_color().lightened(0.3))


func _fill_equip_button(b: Button, slot_name: String, item: ItemResource) -> void:
	if item == null:
		b.text = "%s : (vide)" % slot_name
		b.tooltip_text = ""
		b.remove_theme_color_override("font_color")
	else:
		b.text = "%s : %s" % [slot_name, item.display_name]
		b.tooltip_text = item.tooltip() + "\n\nClic : ranger dans le sac"
		b.add_theme_color_override("font_color", item.rarity_color())


func _show_detail(index: int) -> void:
	var item := Game.player.inventory.item_at(index)
	if item == null:
		_detail.text = "[color=#%s]Emplacement vide.[/color]" % MUTED.to_html(false)
		return
	var lines := item.tooltip().split("\n")
	lines[0] = "[b][color=#%s]%s[/color][/b]" % [item.rarity_color().to_html(false), lines[0]]
	if item.is_equipment():
		var current := Game.player.equipped(item.kind)
		var delta := item.power() - (current.power() if current != null else 0.0)
		var tag := "[color=#7ee08a]meilleur que l'actuel[/color]" if delta > 0.0 else "[color=#e07e7e]moins bon que l'actuel[/color]"
		lines.append(tag)
	_detail.text = "\n".join(lines)


func _append_log(text: String, color: Color) -> void:
	_log.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	while _log.get_paragraph_count() > MAX_LOG_LINES:
		_log.remove_paragraph(0)


# ---------------------------------------------------------------- actions

func _on_slot_pressed(index: int) -> void:
	var p := Game.player
	var item := p.inventory.item_at(index)
	if item == null:
		return
	if p.activate_slot(index):
		_append_log("%s : %s" % ["Équipé" if item.is_equipment() else "Utilisé", item.display_name], item.rarity_color())
	elif item.kind == ItemResource.Kind.CONSUMABLE:
		_append_log("PV déjà au max.", MUTED)
	_show_detail(index)


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	var p := Game.player
	var item := p.inventory.item_at(index)
	if item == null:
		return
	var n := p.inventory.count_at(index) if mb.shift_pressed else 1
	var earned := p.sell_slot(index, n)
	_append_log("Vendu %d × %s (+%d or)" % [n, item.display_name, earned], AutoCombat.COLOR_GOLD)
	_show_detail(index)
	accept_event()


func _on_forge_pressed(kind: String) -> void:
	if Game.player.buy_upgrade(kind):
		_append_log("Forge : %s niveau %d" % [PlayerState.UPGRADES[kind][0], Game.player.upgrade_level(kind)], AutoCombat.COLOR_GOLD)


func _on_buy_potion() -> void:
	if not Game.player.buy_potion():
		_append_log("Pas assez d'or ou sac plein.", AutoCombat.COLOR_BAD)


func _on_sell_materials() -> void:
	var earned := Game.player.sell_all_materials()
	_append_log("Matériaux vendus : +%d or" % earned, AutoCombat.COLOR_GOLD)


func _equip_button(kind: ItemResource.Kind) -> Button:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.pressed.connect(func() -> void:
		if not Game.player.unequip(kind) and Game.player.equipped(kind) != null:
			_append_log("Sac plein : impossible de ranger.", AutoCombat.COLOR_BAD)
	)
	return b


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Nouvelle partie"
	dialog.dialog_text = "Tout effacer et recommencer au niveau 1 ?"
	dialog.confirmed.connect(func() -> void:
		Game.reset_game()
		_log.clear()
		_append_log("Nouvelle partie !", MUTED)
	)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _show_offline_report(text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Pendant ton absence"
	dialog.dialog_text = text
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
	_append_log(text.replace("\n", "  "), AutoCombat.COLOR_GOLD)


# ---------------------------------------------------------------- styles

func _build_styles() -> void:
	_slot_empty_style = _box(Color(0.08, 0.085, 0.11), Color(0.18, 0.19, 0.24), 1, 4)
	for color in ItemResource.RARITY_COLORS:
		_slot_styles.append(_box(Color(0.13, 0.14, 0.19), color.darkened(0.25), 2, 4))
		_slot_hover_styles.append(_box(Color(0.18, 0.19, 0.26), color, 2, 4))


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TITLE_COLOR.darkened(0.15))
	label.add_theme_font_size_override("font_size", 15)
	return label


func _box(bg: Color, border: Color, border_width: int, margin: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(margin)
	return sb


func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _box(fill, fill, 0, 0))
	bar.add_theme_stylebox_override("background", _box(Color(0.05, 0.05, 0.07), Color(0.2, 0.2, 0.25), 1, 0))
	var text := Label.new()
	text.name = "Text"
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("font_size", 13)
	bar.add_child(text)
	return bar


func _set_bar(bar: ProgressBar, value: float, max_value: float, text: String) -> void:
	bar.max_value = maxf(1.0, max_value)
	bar.value = value
	(bar.get_node("Text") as Label).text = text
