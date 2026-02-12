extends Resource
class_name AbilityUpgradePath

## Unique id for this ability (e.g. "axe", "sword", "chain_lightning").
@export var ability_id: String = ""
## Ordered path: [0] = level 1 (unlock), [1]..[8] = levels 2-9. Each entry is Ability (lv1) or AbilityUpgrade (lv2-9).
@export var upgrades: Array[Resource] = []
## Optional post-max upgrade offered repeatedly (e.g. +2% damage per pick) until prestige_max_level.
@export var prestige_upgrade: AbilityUpgrade
@export var prestige_max_level: int = 99

const MAX_LEVEL := 9

func get_next_upgrade_for_level(current_level: int) -> Resource:
	if current_level < 0 or current_level >= MAX_LEVEL:
		return null
	if current_level >= upgrades.size():
		return null
	return upgrades[current_level] as Resource

func has_prestige() -> bool:
	return prestige_upgrade != null
