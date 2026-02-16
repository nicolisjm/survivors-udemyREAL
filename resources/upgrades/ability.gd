extends AbilityUpgrade
class_name Ability

@export var ability_controller_scene: PackedScene
## Optional icon for the ability card. Path upgrades inherit this from the level 1 Ability.
@export var icon: Texture2D
## ability_id and level are inherited from AbilityUpgrade; set level = 1 for unlock.
