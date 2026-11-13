extends Node
## Autoload "Game": owns the hero and the fight, ticks it, saves it, and
## grants offline progress when the game starts again.

const SAVE_PATH := "user://idle_quest_save.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 15.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const MIN_OFFLINE_SECONDS := 60.0
const OFFLINE_STEP := 0.5

var player := PlayerState.new()
var combat: AutoCombat
## 1, 2 or 5: lets the player speed up the fight.
var speed: float = 1.0
## Filled at start if offline progress was granted; the UI shows it once.
var offline_report: String = ""

var _autosave_timer: float = 0.0


func _ready() -> void:
	combat = AutoCombat.new(player)
	var away := load_game()
	combat.start()
	if away >= MIN_OFFLINE_SECONDS:
		_simulate_offline(away)


func _process(delta: float) -> void:
	combat.tick(delta * speed)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func save_game() -> void:
	var data := player.to_dict()
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))


## Loads the save if any. Returns seconds since it was written (0 if none).
func load_game() -> float:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0.0
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary):
		push_warning("Save file unreadable, starting fresh.")
		return 0.0
	player.from_dict(parsed)
	var saved_at := float(parsed.get("saved_at", 0.0))
	if saved_at <= 0.0:
		return 0.0
	return maxf(0.0, Time.get_unix_time_from_system() - saved_at)


func reset_game() -> void:
	player.from_dict({})
	player.hp = player.max_hp()
	combat.respawn_left = 0.0
	combat.spawn_enemy()
	save_game()


## Fast-forwards the fight for the time spent away (capped).
func _simulate_offline(seconds: float) -> void:
	var capped := minf(seconds, MAX_OFFLINE_SECONDS)
	var gold0 := player.gold
	var level0 := player.level
	var kills0 := player.total_kills
	var items0 := player.inventory.total_items()
	var t := 0.0
	while t < capped:
		combat.tick(OFFLINE_STEP)
		t += OFFLINE_STEP
	var lines := PackedStringArray()
	lines.append("Absent %s%s." % [_format_time(seconds), " (max 8 h comptées)" if seconds > capped else ""])
	lines.append("Ton héros a combattu tout seul :")
	lines.append("• %d ennemis vaincus" % (player.total_kills - kills0))
	lines.append("• +%d or" % (player.gold - gold0))
	if player.level > level0:
		lines.append("• +%d niveau(x) → niveau %d" % [player.level - level0, player.level])
	lines.append("• %+d objets dans le sac" % (player.inventory.total_items() - items0))
	lines.append("• Étape actuelle : %d" % player.stage)
	offline_report = "\n".join(lines)
	save_game()


static func _format_time(seconds: float) -> String:
	var s := int(seconds)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%d min" % (s / 60)
	return "%d s" % s
