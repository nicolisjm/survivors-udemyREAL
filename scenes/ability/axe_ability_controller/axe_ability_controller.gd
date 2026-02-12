extends Node

@export var axe_ability_scene: PackedScene

var base_damage: int = 6
var base_wait_time: float
var _quantity: int = 1
var _damage_flat_bonus: int = 0
var _size_mult: float = 1.0
var _duration_mult: float = 1.0

const MIN_WAIT_TIME := 0.01

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_axe_level() -> int:
	var manager = _get_upgrade_manager()
	if manager != null and manager.has_method("get_ability_level"):
		return manager.get_ability_level("axe")
	return 0


func _get_axe_overflow() -> int:
	var manager = _get_upgrade_manager()
	if manager != null and manager.has_method("get_overflow"):
		return manager.get_overflow("axe")
	return 0


## Level 1 = unlock. 2: +2 damage. 3: 15% size. 4: extra axe. 5: +2 damage. 6: 10% duration. 7: 15% size. 8: 30% duration + 30% size. 9: 2 extra axes (4 total).
func _apply_stats_from_level() -> void:
	var level: int = _get_axe_level()
	var overflow: int = _get_axe_overflow()

	_quantity = 1
	if level >= 4:
		_quantity = 2
	if level >= 9:
		_quantity = 4

	_damage_flat_bonus = 0
	if level >= 2:
		_damage_flat_bonus += 2
	if level >= 5:
		_damage_flat_bonus += 2

	_size_mult = 1.0
	if level >= 3:
		_size_mult = 1.15   # first size: 15%
	if level >= 7:
		_size_mult = 1.15 * 1.15   # second size: 15% each (~1.3225)
	if level >= 8:
		_size_mult *= 1.15   # combo: +30% size

	_duration_mult = 1.0
	if level >= 6:
		_duration_mult = 1.1   # 10% longer orbit
	if level >= 8:
		_duration_mult = 1.1 * 1.15   # combo: 30% longer (~1.43)

	var overflow_bonus: float = 1.0 + 0.05 * overflow if overflow > 0 else 1.0
	set_meta("_axe_overflow_bonus", overflow_bonus)


func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	$Timer.wait_time = max(base_wait_time / mult, MIN_WAIT_TIME)
	$Timer.start()


func on_timer_timeout() -> void:
	var level: int = _get_axe_level()
	if level <= 0:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var damage_mult: float = 1.0
	if player.get("damage_multiplier") != null:
		damage_mult = player.damage_multiplier
	var overflow_bonus: float = get_meta("_axe_overflow_bonus", 1.0)
	var damage: float = (base_damage + _damage_flat_bonus) * damage_mult * overflow_bonus

	for i in _quantity:
		var axe_instance = axe_ability_scene.instantiate() as Node2D
		axe_instance.initial_angle = i * TAU / _quantity
		axe_instance.orbit_direction = 1.0 if i % 2 == 0 else -1.0
		if "duration_mult" in axe_instance:
			axe_instance.duration_mult = _duration_mult
		foreground.add_child(axe_instance)
		axe_instance.global_position = player.global_position
		axe_instance.hitbox_component.damage = damage
		axe_instance.scale = Vector2.ONE * _size_mult


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary) -> void:
	if upgrade.ability_id == "axe":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage_10", "generic_damage_20", "generic_damage_30"]:
		pass  # damage_mult is read from player each attack
