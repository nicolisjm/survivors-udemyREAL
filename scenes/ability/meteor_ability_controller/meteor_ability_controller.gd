extends Node

@export var meteor_ability_scene: PackedScene

var base_damage: int = 5
var base_wait_time: float
const MIN_WAIT_TIME := 0.01

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")

func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("meteor") if manager else 0

func _apply_stats_from_level() -> void:
	# TODO: map levels 1-9 to stats
	pass

func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()

func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	# TODO: spawn visual, apply damage
	pass

func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "meteor":
		_apply_stats_from_level()
