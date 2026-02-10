extends Node

const MAX_RANGE = 100
const MIN_WAIT_TIME := 0.01

@export var sword_ability: PackedScene

var base_damage = 5
var base_wait_time
var _quantity: int = 1

func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
	_apply_attack_speed()


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	$Timer.wait_time = max(base_wait_time / mult, MIN_WAIT_TIME)
	$Timer.start()


func on_timer_timeout():
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

	var damage_mult = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var damage = base_damage * damage_mult
	var foreground_layer = get_tree().get_first_node_in_group("foreground_layer")
	# 1st sword → closest, 2nd → next closest, etc.
	for i in _quantity:
		if i >= enemies.size():
			break
		var target = enemies[i] as Node2D
		var sword_instance = sword_ability.instantiate() as SwordAbility
		foreground_layer.add_child(sword_instance)
		sword_instance.hitbox_component.damage = damage
		sword_instance.global_position = target.global_position + Vector2.RIGHT.rotated(randf_range(0, TAU)) * 4
		sword_instance.rotation = (target.global_position - sword_instance.global_position).angle()


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	if upgrade.id == "sword_quantity":
		_quantity = 1 + current_upgrades["sword_quantity"]["quantity"]
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
