extends Node
## Registry for starting ability selection. Tracks unlocked abilities (saved/loaded like highscores)
## and the selected starting ability for the next run.

const SAVE_PATH := "user://unlocked_starting_abilities.dat"
const DEFAULT_UNLOCKED: Array[String] = ["sword", "axe", "chain_lightning"]

var selected_starting_ability_id: String = "sword"
var _unlocked_ids: Array[String] = []

## All ability paths that can appear in the starting ability selector. Add new paths here for expandability.
var _all_paths: Array[AbilityUpgradePath] = []


func _ready() -> void:
	_unlocked_ids = load_unlocked_abilities()
	_init_all_paths()


## Selectable starting abilities. Cut (not shown): smite, shadow_grab, tail_swipe, blizzard, wind_slice, aura.
func _init_all_paths() -> void:
	_all_paths = [
		preload("res://resources/upgrades/sword_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/axe_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/chain_lightning_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/ball_lightning_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/meteor_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/flamethrower_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/boulder_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/earth_spikes_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/ice_shards_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/tornado_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/bomb_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/bow_arrow_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/boomerang_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/claws_path.tres") as AbilityUpgradePath,
		preload("res://resources/upgrades/bite_path.tres") as AbilityUpgradePath,
	]


func load_unlocked_abilities() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return DEFAULT_UNLOCKED.duplicate()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return DEFAULT_UNLOCKED.duplicate()
	var data = file.get_var()
	file.close()
	if data is Array:
		var result: Array[String] = []
		for item in data:
			if item is String:
				result.append(item)
		return result
	return DEFAULT_UNLOCKED.duplicate()


func save_unlocked_abilities(ids: Array) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[StartingAbilityRegistry] Failed to open save file for writing")
		return
	file.store_var(ids)
	file.close()


func get_unlocked_ability_ids() -> Array:
	return _unlocked_ids.duplicate()


func is_unlocked(ability_id: String) -> bool:
	return ability_id in _unlocked_ids


func unlock_ability(ability_id: String) -> void:
	if ability_id in _unlocked_ids:
		return
	_unlocked_ids.append(ability_id)
	save_unlocked_abilities(_unlocked_ids)


func get_all_ability_paths() -> Array[AbilityUpgradePath]:
	return _all_paths.duplicate()


## Paths that can be selected as starting ability (all in _all_paths; cut abilities are no longer in _all_paths).
func get_selectable_ability_paths() -> Array[AbilityUpgradePath]:
	var result: Array[AbilityUpgradePath] = []
	for path in _all_paths:
		if path != null:
			result.append(path)
	return result


func get_path_for_ability_id(ability_id: String) -> AbilityUpgradePath:
	for path in _all_paths:
		if path != null and path.ability_id == ability_id:
			return path
	return null


func get_ability_display_name(ability_id: String) -> String:
	for path in _all_paths:
		if path.ability_id == ability_id and path.upgrades.size() > 0:
			var first: AbilityUpgrade = path.upgrades[0] as AbilityUpgrade
			if first != null and first.name != "":
				return first.name
	return ability_id.capitalize().replace("_", " ")
