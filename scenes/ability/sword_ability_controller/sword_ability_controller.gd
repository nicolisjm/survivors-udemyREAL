extends Node

const MAX_RANGE = 100
const MIN_WAIT_TIME := 0.01
const RATE_REDUCTION_PER_LEVEL := 0.2
const DAMAGE_FLAT_PER_LEVEL := 2
const DOUBLE_SWIPE_DELAY := 0.15

@export var sword_ability: PackedScene

var base_damage: int = 5
var base_wait_time: float
var _quantity: int = 1
var _damage_flat_bonus: int = 0
var _rate_reduction: float = 0.0
var _swipes_twice: bool = false

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_sword_level() -> int:
	var manager = _get_upgrade_manager()
	if manager != null and manager.has_method("get_ability_level"):
		return manager.get_ability_level("sword")
	return 1  # pre-attached, so at least 1


## Level 1 = unlock. 2: +2 damage. 3: rate -0.2. 4: extra target. 5: +2 damage. 6: rate -0.2. 7: extra target. 8: rate + extra. 9: double swipe.
func _apply_stats_from_level() -> void:
	var level: int = _get_sword_level()
	_quantity = 1
	if level >= 4:
		_quantity = 2
	if level >= 7:
		_quantity = 3
	if level >= 8:
		_quantity = 4

	_damage_flat_bonus = 0
	if level >= 2:
		_damage_flat_bonus += DAMAGE_FLAT_PER_LEVEL
	if level >= 5:
		_damage_flat_bonus += DAMAGE_FLAT_PER_LEVEL

	_rate_reduction = 0.0
	if level >= 3:
		_rate_reduction += RATE_REDUCTION_PER_LEVEL
	if level >= 6:
		_rate_reduction += RATE_REDUCTION_PER_LEVEL
	if level >= 8:
		_rate_reduction += RATE_REDUCTION_PER_LEVEL

	_swipes_twice = level >= 9


func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
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
	$Timer.start()


func _do_sword_attack() -> void:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) < pow(MAX_RANGE, 2)
	)
	if enemies.is_empty():
		return
	enemies.sort_custom(func(a: Node2D, b: Node2D):
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)

	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var damage: float = (base_damage + _damage_flat_bonus) * damage_mult
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	for i in _quantity:
		if i >= enemies.size():
			break
		var target = enemies[i] as Node2D
		var sword_instance = sword_ability.instantiate() as SwordAbility
		foreground_layer.add_child(sword_instance)
		sword_instance.hitbox_component.damage = damage
		sword_instance.global_position = target.global_position + Vector2.RIGHT.rotated(randf_range(0, TAU)) * 4
		sword_instance.rotation = (target.global_position - sword_instance.global_position).angle()


func _on_timer_timeout() -> void:
	var level: int = _get_sword_level()
	if level <= 0:
		return
	_do_sword_attack()
	if _swipes_twice:
		await get_tree().create_timer(DOUBLE_SWIPE_DELAY).timeout
		_do_sword_attack()


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary) -> void:
	if upgrade.ability_id == "sword":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage_10", "generic_damage_20", "generic_damage_30"]:
		pass  # damage_mult is read from player each attack
