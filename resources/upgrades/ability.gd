extends AbilityUpgrade
class_name Ability

@export var ability_controller_scene: PackedScene
## Optional icon for the ability card. Path upgrades inherit this from the level 1 Ability.
@export var icon: Texture2D
## Optional tint for the icon (e.g. Color(1, 0.16, 0) for orange/red). White = no change.
@export var icon_modulate: Color = Color.WHITE
## ability_id and level are inherited from AbilityUpgrade; set level = 1 for unlock.
