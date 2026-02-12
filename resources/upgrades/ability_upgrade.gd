extends Resource
class_name AbilityUpgrade

@export var id: String
@export var max_quantity: int
@export var name: String
@export_multiline var description: String
## If set, this upgrade is part of an ability's level path. Level 1 = unlock; 2-9 = level-up steps.
@export var ability_id: String = ""
@export var level: int = 0
