extends Node

const MAX_RANGE := 100.0
const BASE_STRIKE_DELAY := 0.5
const BASE_STRIKE_COUNT := 2
## Small x-offset per strike so they alternate left/right (pixels).
const STRIKE_X_OFFSET := 0
const MIN_WAIT_TIME := 0.01
const CRIT_MULTIPLIER := 2.0
const RATE_REDUCTION_PER_LEVEL := 0.2
const DAMAGE_FLAT_PER_LEVEL := 2
const STRIKE_DELAY_MULT_LEVEL_8 := 0.7
## Level 9: claws grow 20% larger after every strike in the sequence (multiplicative).
const SIZE_GROWTH_PER_STRIKE_LEVEL_9 := 0.2
## Duration of slow debuff (seconds). Each hit refreshes; does not stack.
const SLOW_DURATION := 3.0
## Movement speed multiplier when slowed (e.g. 0.9 = 10% reduction). Level 8 upgrades to 20%.
const SLOW_MULTIPLIER := 0.9
const SLOW_MULTIPLIER_LEVEL_8 := 0.8

@export var claws_ability_scene: PackedScene

var base_damage: int = 4
var base_wait_time: float
var _strike_count: int = BASE_STRIKE_COUNT
var _strike_delay: float = BASE_STRIKE_DELAY
var _rate_reduction: float = 0.0
var _damage_flat_bonus: int = 0
var _slow_duration: float = 0.0
var _slow_multiplier: float = SLOW_MULTIPLIER
var _size_growth_per_strike: float = 0.0

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")

func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("claws") if manager else 0

## 1 unlock, 2 +2 strike, 3 rate, 4 damage, 5 slow, 6 +2 strike, 7 rate, 8 strikes + 30% delay reduction, 9 size +20% after every strike.
func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	_strike_count = BASE_STRIKE_COUNT
	if level >= 2:
		_strike_count += 2   # 4
	if level >= 6:
		_strike_count += 2   # 6

	_strike_delay = BASE_STRIKE_DELAY
	if level >= 8:
		_strike_delay *= STRIKE_DELAY_MULT_LEVEL_8   # 30% reduced

	_rate_reduction = 0.0
	if level >= 3:
		_rate_reduction += RATE_REDUCTION_PER_LEVEL
	if level >= 7:
		_rate_reduction += RATE_REDUCTION_PER_LEVEL

	_damage_flat_bonus = 0
	if level >= 4:
		_damage_flat_bonus += DAMAGE_FLAT_PER_LEVEL

	_slow_duration = 0.0
	_slow_multiplier = SLOW_MULTIPLIER
	if level >= 5:
		_slow_duration = SLOW_DURATION
		_slow_multiplier = SLOW_MULTIPLIER
	if level >= 8:
		_slow_multiplier = SLOW_MULTIPLIER_LEVEL_8   # 20% slow

	_size_growth_per_strike = SIZE_GROWTH_PER_STRIKE_LEVEL_9 if level >= 9 else 0.0

func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()

func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	var wait: float = base_wait_time - _rate_reduction
	wait = wait / mult
	$Timer.wait_time = max(wait, MIN_WAIT_TIME)
	if $Timer.is_stopped():
		$Timer.start()

func _get_nearest_enemy_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return enemy.global_position.distance_squared_to(player.global_position) < pow(MAX_RANGE, 2)
	)
	if enemies.is_empty():
		return Vector2.ZERO
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)
	return (enemies[0] as Node2D).global_position

func _do_claw_sequence() -> void:
	var target_pos := _get_nearest_enemy_position()
	if target_pos == Vector2.ZERO:
		return
	var player = get_tree().get_first_node_in_group("player")
	var damage_mult: float = player.get("damage_multiplier") if player and player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player and player.get("damage_flat_bonus") != null else 0
	var size_mult: float = player.get("size_multiplier") if player and player.get("size_multiplier") != null else 1.0
	var damage: float = (base_damage + _damage_flat_bonus + flat_bonus) * damage_mult
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground == null:
		return
	for i in _strike_count:
		var offset_x := STRIKE_X_OFFSET if i % 2 == 1 else -STRIKE_X_OFFSET
		var flip_x := -1.0 if i % 2 == 1 else 1.0
		# Level 9: size grows 20% after every strike (strike 0 = 1x, 1 = 1.2x, 2 = 1.44x, ...)
		var strike_size_mult: float = size_mult * (1.0 + _size_growth_per_strike) ** i
		var claws = claws_ability_scene.instantiate() as Node2D
		claws.global_position = target_pos + Vector2(offset_x, 0.0)
		# Preserve scene's root scale (e.g. 2,2) so hitboxes match visual; apply flip and size on top.
		var base_scale: Vector2 = claws.scale
		claws.scale = Vector2(base_scale.x * flip_x * strike_size_mult, base_scale.y * strike_size_mult)
		foreground.add_child(claws)
		if claws.has_method("set_damage"):
			claws.set_damage(damage, CRIT_MULTIPLIER, _slow_duration, _slow_multiplier)
		if i < _strike_count - 1:
			await _wait_unpaused(_strike_delay)


## Waits for strike_delay seconds but only counts time when the tree is not paused, so pause doesn't queue up a burst of strikes on unpause.
func _wait_unpaused(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()

func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	_do_claw_sequence()

func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "claws":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage", "generic_damage_prestige", "generic_size", "generic_size_prestige"]:
		pass
