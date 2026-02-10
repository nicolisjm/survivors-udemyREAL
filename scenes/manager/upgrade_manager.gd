extends Node

@export var experience_manager: Node
@export var upgrade_screen_scene: PackedScene

var current_upgrades = {}
var upgrade_pool: WeightedTable = WeightedTable.new()

var upgrade_axe = preload("res://resources/upgrades/axe.tres")
var upgrade_move_speed = preload("res://resources/upgrades/move_speed.tres")
var upgrade_chain_lightning = preload("res://resources/upgrades/chain_lightning.tres")
var upgrade_chain_lightning_chains = preload("res://resources/upgrades/chain_lightning_chains.tres")
var upgrade_chain_lightning_quantity = preload("res://resources/upgrades/chain_lightning_quantity.tres")
var upgrade_sword_quantity = preload("res://resources/upgrades/sword_quantity.tres")
var upgrade_axe_quantity = preload("res://resources/upgrades/axe_quantity.tres")

# Generic damage/attack speed: 3 rarities each (10% common, 20% uncommon, 30% rare)
var upgrade_generic_damage_10 = preload("res://resources/upgrades/generic_damage_10.tres")
var upgrade_generic_damage_20 = preload("res://resources/upgrades/generic_damage_20.tres")
var upgrade_generic_damage_30 = preload("res://resources/upgrades/generic_damage_30.tres")
var upgrade_generic_attack_speed_10 = preload("res://resources/upgrades/generic_attack_speed_10.tres")
var upgrade_generic_attack_speed_20 = preload("res://resources/upgrades/generic_attack_speed_20.tres")
var upgrade_generic_attack_speed_30 = preload("res://resources/upgrades/generic_attack_speed_30.tres")

## Upgrades in the same selection group cannot appear together in one pick (e.g. only one "generic damage" per selection).
var _selection_groups: Array[Array] = []


func _ready() -> void:
	upgrade_pool.add_item(upgrade_axe, 10)
	upgrade_pool.add_item(upgrade_sword_quantity, 2)
	upgrade_pool.add_item(upgrade_move_speed, 5)
	upgrade_pool.add_item(upgrade_chain_lightning, 10)
	# Generic damage: 10% common, 20% uncommon, 30% rare
	upgrade_pool.add_item(upgrade_generic_damage_10, 10)
	upgrade_pool.add_item(upgrade_generic_damage_20, 3)
	upgrade_pool.add_item(upgrade_generic_damage_30, 1)
	# Generic attack speed: 10% common, 20% uncommon, 30% rare
	upgrade_pool.add_item(upgrade_generic_attack_speed_10, 10)
	upgrade_pool.add_item(upgrade_generic_attack_speed_20, 3)
	upgrade_pool.add_item(upgrade_generic_attack_speed_30, 1)

	# Only one of each group can appear per selection
	_selection_groups = [
		[upgrade_generic_damage_10, upgrade_generic_damage_20, upgrade_generic_damage_30],
		[upgrade_generic_attack_speed_10, upgrade_generic_attack_speed_20, upgrade_generic_attack_speed_30]
	]

	experience_manager.level_up.connect(on_level_up)
	
	
func apply_upgrade(upgrade: AbilityUpgrade):
	var has_upgrade = current_upgrades.has(upgrade.id)
	if !has_upgrade:
		current_upgrades[upgrade.id] = {
			"resource": upgrade,
			"quantity": 1
		}
	else:
		current_upgrades[upgrade.id]["quantity"] += 1
	print(current_upgrades)
	
	if upgrade.max_quantity > 0:
		var current_quantity = current_upgrades[upgrade.id]["quantity"]
		if current_quantity == upgrade.max_quantity:
			upgrade_pool.remove_item(upgrade)
	
	update_upgrade_pool(upgrade)
	GameEvents.emit_ability_upgrade_added(upgrade, current_upgrades)
	
	
func update_upgrade_pool(chosen_upgrade: AbilityUpgrade):
	if chosen_upgrade.id == upgrade_axe.id:
		upgrade_pool.add_item(upgrade_axe_quantity, 2)
	if chosen_upgrade.id == upgrade_chain_lightning.id:
		upgrade_pool.add_item(upgrade_chain_lightning_chains, 3)
		upgrade_pool.add_item(upgrade_chain_lightning_quantity, 2)


func pick_upgrades():
	var chosen_upgrades: Array[AbilityUpgrade] = []
	for i in 3:
		if upgrade_pool.items.size() == chosen_upgrades.size():
			break
		var exclude := _build_pick_exclude(chosen_upgrades)
		var chosen_upgrade = upgrade_pool.pick_item(exclude)
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
