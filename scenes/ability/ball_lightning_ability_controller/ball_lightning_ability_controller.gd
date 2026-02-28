extends Node

@export var ball_lightning_ability_scene: PackedScene

var base_damage: int = 1
var base_wait_time: float
var _crit_base_bonus: int = 0
var _size_mult: float = 1.0
var _duration_mult: float = 1.0
var _spawn_forward_ball: bool = false

const MIN_WAIT_TIME := 0.01
const BASE_WAIT_TIME := 1.8


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ball_lightning_level() -> int:
	var manager = _get_upgrade_manager()
	if manager != null and manager.has_method("get_ability_level"):
		return manager.get_ability_level("ball_lightning")
	return 0


func _get_ball_lightning_overflow() -> int:
	var manager = _get_upgrade_manager()
	if manager != null and manager.has_method("get_overflow"):
		return manager.get_overflow("ball_lightning")
	return 0


## 1: unlock. 2: cast -0.2s. 3: duration +15%. 4: crit +3. 5: cast -0.2s. 6: duration +15%. 7: crit +3. 8: cast -0.2s & duration +15%. 9: +forward ball.
func _apply_stats_from_level() -> void:
	var level: int = _get_ball_lightning_level()
	var overflow: int = _get_ball_lightning_overflow()

	base_wait_time = BASE_WAIT_TIME
	if level >= 2:
		base_wait_time -= 0.2
	if level >= 5:
		base_wait_time -= 0.2
	if level >= 8:
		base_wait_time -= 0.2

	_duration_mult = 1.0
	if level >= 3:
		_duration_mult = 1.15
	if level >= 6:
		_duration_mult = 1.15 * 1.15
	if level >= 7:
		_duration_mult *= 1.15
	if level >= 8:
		_duration_mult *= 1.15

	_crit_base_bonus = 0
	if level >= 4:
		_crit_base_bonus += 3


	_spawn_forward_ball = (level >= 9)

	_size_mult = 1.0
	var overflow_bonus: float = 1.0 + 0.05 * overflow if overflow > 0 else 1.0
	set_meta("_ball_lightning_overflow_bonus", overflow_bonus)


func _ready() -> void:
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
	if $Timer.is_stopped():
		$Timer.start()


func on_timer_timeout() -> void:
	var level: int = _get_ball_lightning_level()
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
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	var duration_mult: float = player.get("duration_multiplier") if player.get("duration_multiplier") != null else 1.0
	var overflow_bonus: float = get_meta("_ball_lightning_overflow_bonus", 1.0)

	## Normal hits: base only (no flat bonus). Crits: base + flat bonus + crit bonus.
	var normal_damage: float = base_damage * damage_mult * overflow_bonus
	var crit_damage: float = (base_damage + flat_bonus + _crit_base_bonus + 1) * 2.0 * damage_mult * overflow_bonus

	# Orbiting ball(s) - random starting angle each cast
	var ball = ball_lightning_ability_scene.instantiate() as Node2D
	ball.initial_angle = NAN  # random
	ball.orbit_direction = -1.0
	ball.duration_mult = _duration_mult * duration_mult * 1.1
	ball.radius_mult = size_mult
	ball.damage = normal_damage
	ball.crit_damage = crit_damage
	ball.is_forward_ball = false
	foreground.add_child(ball)
	ball.global_position = player.global_position
	ball.scale = Vector2.ONE * _size_mult * size_mult * 1.2

	# Level 9: second ball goes straight forward slowly in player's last move direction
	if _spawn_forward_ball:
		var forward_ball = ball_lightning_ability_scene.instantiate() as Node2D
		forward_ball.is_forward_ball = true
		forward_ball.forward_direction = player.last_move_direction
		forward_ball.duration_mult = _duration_mult * duration_mult * 1.1
		forward_ball.radius_mult = size_mult
		forward_ball.damage = normal_damage
		forward_ball.crit_damage = crit_damage
		forward_ball.global_position = player.global_position
		foreground.add_child(forward_ball)
		forward_ball.scale = Vector2.ONE * _size_mult * size_mult * 1.5


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary) -> void:
	if upgrade.ability_id == "ball_lightning":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage", "generic_damage_prestige"]:
		pass
	elif upgrade.id in ["generic_size", "generic_size_prestige", "generic_duration", "generic_duration_prestige"]:
		pass
