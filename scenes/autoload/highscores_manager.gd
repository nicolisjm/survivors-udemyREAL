extends Node

const SAVE_PATH := "user://highscores.dat"
const MAX_ENTRIES := 5
## Set to true to always show initials entry (for testing). Set to false for release.
const FORCE_NEW_HIGHSCORE_FOR_TESTING := false

## Arcade-style placeholder entries to encourage players to beat them.
const PLACEHOLDER_ENTRIES: Array[Dictionary] = [
	{"initials": "NIC", "time_survived": 1200.0, "exp_collected": 20000, "ability_names": ["???"]},
	{"initials": "THO", "time_survived": 600.0, "exp_collected": 6000, "ability_names": ["Sword", "Axe", "Chain Lightning"]},
	{"initials": "WIL", "time_survived": 360.0, "exp_collected": 3000, "ability_names": ["Ball Lightning", "Chain Lightning", "Sword"]},
	{"initials": "SHO", "time_survived": 180.0, "exp_collected": 300, "ability_names": ["Bite", "Sword", "Axe"]},
	{"initials": "DED", "time_survived": 60.0, "exp_collected": 20, "ability_names": ["Sword"]},
]

var _entries: Array = []


func _ready() -> void:
	_entries = load_highscores()


func load_highscores() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return _placeholders_to_array()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _placeholders_to_array()
	var data = file.get_var()
	file.close()
	if data is Array:
		var result: Array = data.duplicate()
		if result.size() > MAX_ENTRIES:
			result.resize(MAX_ENTRIES)
			save_highscores(result)
		return result
	return _placeholders_to_array()


func _placeholders_to_array() -> Array:
	var result: Array = []
	for entry in PLACEHOLDER_ENTRIES:
		result.append(entry.duplicate())
	return result


func save_highscores(entries: Array) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[HighscoresManager] Failed to open save file for writing")
		return
	file.store_var(entries)
	file.close()


func would_be_highscore(time_survived: float) -> bool:
	if FORCE_NEW_HIGHSCORE_FOR_TESTING:
		return true
	var entries: Array = get_highscores()
	if entries.size() < MAX_ENTRIES:
		return true
	return time_survived > entries[entries.size() - 1]["time_survived"]


func submit_score(time_survived: float, exp_collected: float, initials: String = "---", ability_names: Array = []) -> bool:
	var entries: Array = get_highscores()
	var new_entry := {
		"initials": initials.to_upper().substr(0, 3),
		"time_survived": time_survived,
		"exp_collected": int(exp_collected),
		"ability_names": ability_names.duplicate()
	}
	var inserted := false
	for i in entries.size():
		if time_survived > entries[i]["time_survived"]:
			entries.insert(i, new_entry)
			inserted = true
			break
	if not inserted and entries.size() < MAX_ENTRIES:
		entries.append(new_entry)
		inserted = true
	entries.resize(min(entries.size(), MAX_ENTRIES))
	_entries = entries.duplicate()
	save_highscores(entries)
	return inserted


func get_highscores() -> Array:
	if _entries.is_empty():
		_entries = load_highscores()
	var result: Array = []
	for e in _entries:
		result.append(e)
	return result
