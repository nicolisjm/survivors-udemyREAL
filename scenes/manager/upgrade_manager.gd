extends Node
class_name UpgradeManager

@export var experience_manager: Node
@export var upgrade_screen_scene: PackedScene

var current_upgrades = {}
var upgrade_pool: WeightedTable = WeightedTable.new()

## Path-based abilities: only the "next" upgrade per ability is in the pool.
var ability_levels: Dictionary = {}
var ability_overflow: Dictionary = {}
## Order in which the player acquired main abilities (first = left slot, second = center, third = right).
var _acquired_ability_order: Array[String] = []

var path_axe: AbilityUpgradePath = preload("res://resources/upgrades/axe_path.tres") as AbilityUpgradePath
var path_sword: AbilityUpgradePath = preload("res://resources/upgrades/sword_path.tres") as AbilityUpgradePath
var path_chain_lightning: AbilityUpgradePath = preload("res://resources/upgrades/chain_lightning_path.tres") as AbilityUpgradePath
var path_ball_lightning: AbilityUpgradePath = preload("res://resources/upgrades/ball_lightning_path.tres") as AbilityUpgradePath
var path_meteor: AbilityUpgradePath = preload("res://resources/upgrades/meteor_path.tres") as AbilityUpgradePath
var path_flamethrower: AbilityUpgradePath = preload("res://resources/upgrades/flamethrower_path.tres") as AbilityUpgradePath
var path_boulder: AbilityUpgradePath = preload("res://resources/upgrades/boulder_path.tres") as AbilityUpgradePath
var path_earth_spikes: AbilityUpgradePath = preload("res://resources/upgrades/earth_spikes_path.tres") as AbilityUpgradePath
var path_ice_shards: AbilityUpgradePath = preload("res://resources/upgrades/ice_shards_path.tres") as AbilityUpgradePath
var path_blizzard: AbilityUpgradePath = preload("res://resources/upgrades/blizzard_path.tres") as AbilityUpgradePath
var path_wind_slice: AbilityUpgradePath = preload("res://resources/upgrades/wind_slice_path.tres") as AbilityUpgradePath
var path_tornado: AbilityUpgradePath = preload("res://resources/upgrades/tornado_path.tres") as AbilityUpgradePath
var path_aura: AbilityUpgradePath = preload("res://resources/upgrades/aura_path.tres") as AbilityUpgradePath
var path_bomb: AbilityUpgradePath = preload("res://resources/upgrades/bomb_path.tres") as AbilityUpgradePath
var path_bow_arrow: AbilityUpgradePath = preload("res://resources/upgrades/bow_arrow_path.tres") as AbilityUpgradePath
var path_boomerang: AbilityUpgradePath = preload("res://resources/upgrades/boomerang_path.tres") as AbilityUpgradePath
var path_claws: AbilityUpgradePath = preload("res://resources/upgrades/claws_path.tres") as AbilityUpgradePath
var path_tail_swipe: AbilityUpgradePath = preload("res://resources/upgrades/tail_swipe_path.tres") as AbilityUpgradePath
var path_bite: AbilityUpgradePath = preload("res://resources/upgrades/bite_path.tres") as AbilityUpgradePath
var path_smite: AbilityUpgradePath = preload("res://resources/upgrades/smite_path.tres") as AbilityUpgradePath
var path_shadow_grab: AbilityUpgradePath = preload("res://resources/upgrades/shadow_grab_path.tres") as AbilityUpgradePath
var _ability_paths: Array[AbilityUpgradePath] = []

var upgrade_move_speed = preload("res://resources/upgrades/move_speed.tres")

# Generic damage/attack speed: 3 rarities each (10% common, 20% uncommon, 30% rare)
var upgrade_generic_damage_10 = preload("res://resources/upgrades/generic_damage_10.tres")
var upgrade_generic_damage_20 = preload("res://resources/upgrades/generic_damage_20.tres")
var upgrade_generic_damage_30 = preload("res://resources/upgrades/generic_damage_30.tres")
var upgrade_generic_attack_speed_10 = preload("res://resources/upgrades/generic_attack_speed_10.tres")
var upgrade_generic_attack_speed_20 = preload("res://resources/upgrades/generic_attack_speed_20.tres")
var upgrade_generic_attack_speed_30 = preload("res://resources/upgrades/generic_attack_speed_30.tres")

## Upgrades in the same selection group cannot appear together in one pick (e.g. only one "generic damage" per selection).
var _selection_groups: Array[Array] = []

## Max number of main/active abilities (unlocks) the player can have. Unlock options for other abilities are removed from the pool once this is reached.
const MAX_MAIN_ABILITIES: int = 3

## Weight for each path upgrade (axe/sword level-ups) when added to the pool. Higher = more likely to appear.
@export var path_weight: int = 10
## Weight for move_speed.
@export var move_speed_weight: int = 5
## Weights for generic upgrades: [damage_10%, damage_20%, damage_30%].
@export var generic_damage_weights: Vector3i = Vector3i(10, 3, 1)
## Weights for generic attack speed: [10%, 20%, 30%].
@export var generic_attack_speed_weights: Vector3i = Vector3i(10, 3, 1)


func _ready() -> void:
	add_to_group("upgrade_manager")
	ability_levels["axe"] = 0
	ability_levels["chain_lightning"] = 0
	ability_levels["sword"] = 1  # pre-attached
	ability_levels["ball_lightning"] = 0
	ability_levels["meteor"] = 0
	ability_levels["flamethrower"] = 0
	ability_levels["boulder"] = 0
	ability_levels["earth_spikes"] = 0
	ability_levels["ice_shards"] = 0
	ability_levels["blizzard"] = 0
	ability_levels["wind_slice"] = 0
	ability_levels["tornado"] = 0
	ability_levels["aura"] = 0
	ability_levels["bomb"] = 0
	ability_levels["bow_arrow"] = 0
	ability_levels["boomerang"] = 0
	ability_levels["claws"] = 0
	ability_levels["tail_swipe"] = 0
	ability_levels["bite"] = 0
	ability_levels["smite"] = 0
	ability_levels["shadow_grab"] = 0

	# Only include functional abilities in the upgrade pool (placeholders excluded)
	_ability_paths = [
		path_axe,
		path_sword,
		path_chain_lightning,
		path_bite,
	]
	# Initialize display order: any ability already at level >= 1 (e.g. starting weapon) is first.
	for path in _ability_paths:
		if ability_levels.get(path.ability_id, 0) >= 1:
			_acquired_ability_order.append(path.ability_id)
	_rebuild_pool()

	_selection_groups = [
		[upgrade_generic_damage_10, upgrade_generic_damage_20, upgrade_generic_damage_30],
		[upgrade_generic_attack_speed_10, upgrade_generic_attack_speed_20, upgrade_generic_attack_speed_30]
	]

	experience_manager.level_up.connect(on_level_up)


func get_ability_level(ability_id: String) -> int:
	return ability_levels.get(ability_id, 0)


func get_overflow(ability_id: String) -> int:
	return ability_overflow.get(ability_id, 0)


## Returns { "current": int, "max": int } for card level display [current/max].
func get_display_level_info(upgrade: AbilityUpgrade) -> Dictionary:
	var path: AbilityUpgradePath = _get_path_for_ability(upgrade.ability_id)
	if path != null:
		if path.has_prestige() and path.prestige_upgrade == upgrade:
			return {
				"current": ability_overflow.get(upgrade.ability_id, 0),
				"max": path.prestige_max_level
			}
		else:
			return {
				"current": ability_levels.get(upgrade.ability_id, 0),
				"max": AbilityUpgradePath.MAX_LEVEL
			}
	# Generic / move_speed: quantity-based
	var quantity: int = 0
	if current_upgrades.has(upgrade.id):
		quantity = current_upgrades[upgrade.id]["quantity"]
	var max_qty: int = upgrade.max_quantity if upgrade.max_quantity > 0 else 99
	return { "current": quantity, "max": max_qty }


func get_path_for_ability(ability_id: String) -> AbilityUpgradePath:
	return _get_path_for_ability(ability_id)


## Returns up to MAX_MAIN_ABILITIES entries in acquisition order: first = left slot, second = center, third = right.
## Each entry: { "ability_id": String, "level": int, "icon": Texture2D }
func get_acquired_main_abilities() -> Array:
	var result: Array = []
	for ability_id in _acquired_ability_order:
		if result.size() >= MAX_MAIN_ABILITIES:
			break
		var level: int = ability_levels.get(ability_id, 0)
		if level < 1:
			continue
		var path: AbilityUpgradePath = _get_path_for_ability(ability_id)
		var icon: Texture2D = null
		if path != null and path.upgrades.size() > 0 and path.upgrades[0] is Ability:
			icon = (path.upgrades[0] as Ability).icon
		result.append({ "ability_id": ability_id, "level": level, "icon": icon })
	return result


func _count_owned_main_abilities() -> int:
	var count: int = 0
	for path in _ability_paths:
		if ability_levels.get(path.ability_id, 0) >= 1:
			count += 1
	return count


func _rebuild_pool() -> void:
	upgrade_pool.clear()
	var owned_count: int = _count_owned_main_abilities()

	for path in _ability_paths:
		var current: int = int(ability_levels.get(path.ability_id, 0))
		if current >= 1:
			if current < AbilityUpgradePath.MAX_LEVEL:
				var next_upgrade: Resource = path.get_next_upgrade_for_level(current)
				if next_upgrade:
					upgrade_pool.add_item(next_upgrade, path_weight)
			elif path.has_prestige():
				var overflow: int = int(ability_overflow.get(path.ability_id, 0))
				if overflow < path.prestige_max_level:
					upgrade_pool.add_item(path.prestige_upgrade, path_weight)
		elif owned_count < MAX_MAIN_ABILITIES:
			var unlock: Resource = path.get_next_upgrade_for_level(0)
			if unlock:
				upgrade_pool.add_item(unlock, path_weight)

	upgrade_pool.add_item(upgrade_move_speed, move_speed_weight)
	upgrade_pool.add_item(upgrade_generic_damage_10, generic_damage_weights.x)
	upgrade_pool.add_item(upgrade_generic_damage_20, generic_damage_weights.y)
	upgrade_pool.add_item(upgrade_generic_damage_30, generic_damage_weights.z)
	upgrade_pool.add_item(upgrade_generic_attack_speed_10, generic_attack_speed_weights.x)
	upgrade_pool.add_item(upgrade_generic_attack_speed_20, generic_attack_speed_weights.y)
	upgrade_pool.add_item(upgrade_generic_attack_speed_30, generic_attack_speed_weights.z)


func _get_path_for_ability(ability_id: String) -> AbilityUpgradePath:
	for path in _ability_paths:
		if path.ability_id == ability_id:
			return path
	return null


func _apply_path_upgrade(upgrade: AbilityUpgrade) -> void:
	ability_levels[upgrade.ability_id] = upgrade.level
	if upgrade.level == 1 and upgrade.ability_id not in _acquired_ability_order:
		_acquired_ability_order.append(upgrade.ability_id)
	upgrade_pool.remove_item(upgrade)

	var path: AbilityUpgradePath = _get_path_for_ability(upgrade.ability_id)
	if path != null:
		if upgrade.level < path.upgrades.size():
			var next_upgrade = path.upgrades[upgrade.level] as Resource
			if next_upgrade:
				upgrade_pool.add_item(next_upgrade, path_weight)
		elif upgrade.level >= AbilityUpgradePath.MAX_LEVEL and path.has_prestige():
			var overflow: int = int(ability_overflow.get(upgrade.ability_id, 0))
			if overflow < path.prestige_max_level:
				upgrade_pool.add_item(path.prestige_upgrade, path_weight)

	# If player just reached max main abilities, remove all other ability-unlock options from the pool.
	if upgrade.level == 1 and _count_owned_main_abilities() >= MAX_MAIN_ABILITIES:
		for p in _ability_paths:
			if ability_levels.get(p.ability_id, 0) >= 1:
				continue
			var unlock: Resource = p.get_next_upgrade_for_level(0)
			if unlock:
				upgrade_pool.remove_item(unlock)


func _apply_prestige(upgrade: AbilityUpgrade, path: AbilityUpgradePath) -> void:
	var id_key: String = path.ability_id
	var prev: int = int(ability_overflow.get(id_key, 0))
	ability_overflow[id_key] = prev + 1
	upgrade_pool.remove_item(upgrade)
	if prev + 1 < path.prestige_max_level:
		upgrade_pool.add_item(path.prestige_upgrade, path_weight)


func apply_upgrade(upgrade: AbilityUpgrade) -> void:
	var is_path_upgrade: bool = upgrade.ability_id != "" and upgrade.level > 0
	var path: AbilityUpgradePath = _get_path_for_ability(upgrade.ability_id) if upgrade.ability_id != "" else null
	var is_prestige: bool = path != null and path.has_prestige() and path.prestige_upgrade == upgrade

	if is_prestige:
		_apply_prestige(upgrade, path)
		if !current_upgrades.has(upgrade.id):
			current_upgrades[upgrade.id] = { "resource": upgrade, "quantity": 0 }
		current_upgrades[upgrade.id]["quantity"] = ability_overflow.get(path.ability_id, 0)
		GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades)
		return

	if is_path_upgrade:
		_apply_path_upgrade(upgrade)
		GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades)
		return

	# Generic / move_speed: quantity-based
	var has_upgrade = current_upgrades.has(upgrade.id)
	if !has_upgrade:
		current_upgrades[upgrade.id] = {
			"resource": upgrade,
			"quantity": 1
		}
	else:
		current_upgrades[upgrade.id]["quantity"] += 1

	if upgrade.max_quantity > 0:
		var current_quantity = current_upgrades[upgrade.id]["quantity"]
		if current_quantity >= upgrade.max_quantity:
			upgrade_pool.remove_item(upgrade)

	GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades)


func pick_upgrades():
	var chosen_upgrades: Array[AbilityUpgrade] = []
	for i in 3:
		if upgrade_pool.items.size() == 0:
			break
		var exclude := _build_pick_exclude(chosen_upgrades)
		var chosen_upgrade = upgrade_pool.pick_item(exclude) as AbilityUpgrade
		if chosen_upgrade == null:
			break
		chosen_upgrades.append(chosen_upgrade)
	return chosen_upgrades


## Excludes chosen upgrades plus any other upgrade in the same selection group (so only one "generic damage" etc. per pick).
func _build_pick_exclude(chosen_upgrades: Array) -> Array:
	var exclude: Array = chosen_upgrades.duplicate()
	for chosen in chosen_upgrades:
		for group in _selection_groups:
			if chosen in group:
				for upgrade in group:
					if upgrade not in exclude:
						exclude.append(upgrade)
				break
	return exclude


func on_upgrade_selected(upgrade: AbilityUpgrade):
	apply_upgrade(upgrade)


func on_level_up(current_level: int):
	var upgrade_screen_instance = upgrade_screen_scene.instantiate()
	add_child(upgrade_screen_instance)
	var chosen_upgrades = pick_upgrades()
	upgrade_screen_instance.set_ability_upgrades(chosen_upgrades as Array[AbilityUpgrade])
	upgrade_screen_instance.upgrade_selected.connect(on_upgrade_selected)
