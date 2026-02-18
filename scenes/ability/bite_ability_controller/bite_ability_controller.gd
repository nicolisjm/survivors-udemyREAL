extends Node

@export var bite_ability_scene: PackedScene

var _bite_hit_sound: AudioStream = preload("res://assets/audio/sfx/freesound_community-carrotnom-92106.mp3") as AudioStream

var base_damage: int = 3
var base_wait_time: float
var _damage_flat_bonus: int = 0
var _rate_reduction: float = 0.0
## Extra damage per repeat hit on same enemy (level 4: 2, level 7: 3).
var _repeat_hit_bonus: int = 1
## Single-target bonus applies when enemies in range <= this (level 8: 3).
var _single_target_max_enemies: int = 1
## Level 9: bite twice per tick (like sword double swipe).
var _bite_twice: bool = false

const MIN_WAIT_TIME := 0.01
const RATE_REDUCTION_PER_UPGRADE := 0.2
const DAMAGE_FLAT_PER_UPGRADE := 2
const BITE_TWICE_DELAY := 0.1
## All enemies within this range of the player are hit (direct damage).
const BITE_RANGE: float = 48.0
## Single-target = crit: double damage (stacks multiplicatively with player damage_mult).
const SINGLE_TARGET_CRIT_MULT: float = 2.0

## Tracks how many times each enemy has been hit by Bite (for repeat-hit bonus). Cleared when enemy invalid.
var _bite_hit_count: Dictionary = {}

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")

func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("bite") if manager else 0

func _apply_stats_from_level() -> void:
	var level: int = _get_ability_level()
	_rate_reduction = 0.0
	if level >= 2:
		_rate_reduction += RATE_REDUCTION_PER_UPGRADE
	if level >= 5:
		_rate_reduction += RATE_REDUCTION_PER_UPGRADE

	_damage_flat_bonus = 0
	if level >= 3:
		_damage_flat_bonus += DAMAGE_FLAT_PER_UPGRADE
	if level >= 6:
		_damage_flat_bonus += DAMAGE_FLAT_PER_UPGRADE

	_repeat_hit_bonus = 1
	if level >= 4:
		_repeat_hit_bonus = 2
	if level >= 7:
		_repeat_hit_bonus = 3

	_single_target_max_enemies = 1
	if level >= 8:
		_single_target_max_enemies = 3

	_bite_twice = level >= 9

func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()

func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = 1.0
	if player:
		var m = player.get("attack_speed_multiplier")
		if m != null and m > 0.0:
			mult = m
	var wait: float = base_wait_time - _rate_reduction
	wait = wait / mult
	$Timer.wait_time = max(wait, MIN_WAIT_TIME)
	$Timer.start()

func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	_do_bite_attack()
	if _bite_twice:
		await get_tree().create_timer(BITE_TWICE_DELAY).timeout
		_do_bite_attack()


func _do_bite_attack() -> void:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var range_sq: float = BITE_RANGE * BITE_RANGE
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) <= range_sq
	)

	if enemies.is_empty():
		return

	var enemy_count: int = enemies.size()
	var is_single_target: bool = enemy_count <= _single_target_max_enemies

	for enemy in enemies:
		var visual = bite_ability_scene.instantiate()
		visual.impact.connect(_on_bite_impact.bind(enemy, is_single_target))
		foreground.add_child(visual)
		visual.global_position = ((enemy as Node2D).global_position).round()


func _on_bite_impact(enemy, is_single_target: bool) -> void:
	if not is_instance_valid(enemy):
		return
	_prune_dead_bite_counts()
	var count: int = _bite_hit_count.get(enemy, 0)
	var player = get_tree().get_first_node_in_group("player")
	var damage_mult: float = 1.0
	if player:
		var mult = player.get("damage_multiplier")
		if mult != null and mult > 0.0:
			damage_mult = mult
	var is_crit: bool = is_single_target
	var crit_mult: float = SINGLE_TARGET_CRIT_MULT if is_single_target else 1.0
	var damage: float = (base_damage + _damage_flat_bonus + count * _repeat_hit_bonus) * damage_mult * crit_mult
	var hurtbox = enemy.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if hurtbox:
		hurtbox.apply_damage(damage, null, 0.0, null, is_crit, _bite_hit_sound, -30.0)
	_bite_hit_count[enemy] = count + 1


func _prune_dead_bite_counts() -> void:
	var to_erase: Array = []
	for key in _bite_hit_count:
		if not is_instance_valid(key):
			to_erase.append(key)
	for key in to_erase:
		_bite_hit_count.erase(key)

func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "bite":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage_10", "generic_damage_20", "generic_damage_30"]:
		# Bite reads player.damage_multiplier at impact time, so no refresh needed.
		pass
