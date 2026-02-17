extends Node
## Attach to main_ability_test.tscn root. Set test_ability_id and test_ability_level in Inspector, then run main_ability_test as main scene.

@export var test_ability_id: String = "sword"
@export var test_ability_level: int = 9

const PRE_ATTACHED_ABILITIES := ["sword"]

func _ready() -> void:
	await get_tree().process_frame
	var upgrade_manager = get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	var player = get_tree().get_first_node_in_group("player")
	if upgrade_manager == null or player == null:
		return
	var abilities_node = player.get_node_or_null("Abilities")
	if abilities_node == null:
		return

	upgrade_manager.ability_levels[test_ability_id] = test_ability_level

	if test_ability_id not in PRE_ATTACHED_ABILITIES:
		var path = upgrade_manager.get_path_for_ability(test_ability_id)
		if path != null:
			var ability_resource = path.upgrades[0] as Ability
			if ability_resource != null:
				var controller = ability_resource.ability_controller_scene.instantiate()
				abilities_node.add_child(controller)
