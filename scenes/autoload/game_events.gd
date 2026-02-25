extends Node

signal experience_vial_collected(number: float)
signal ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary)
signal player_damaged
signal player_healed
signal black_hole_activated
## Emitted when a burning enemy dies (for flamethrower level 8: spread burn to nearby).
signal burning_enemy_died(position: Vector2)


func emit_experience_vial_collected(number: float):
	experience_vial_collected.emit(number)


func emit_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	ability_upgrade_added.emit(upgrade, current_upgrades)


func emit_player_damaged():
	player_damaged.emit()


func emit_player_healed():
	player_healed.emit()


func emit_black_hole_activated():
	black_hole_activated.emit()


func emit_burning_enemy_died(position: Vector2):
	burning_enemy_died.emit(position)
