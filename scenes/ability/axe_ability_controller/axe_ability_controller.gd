extends Node

@export var axe_ability_scene: PackedScene

var base_damage = 10
var base_wait_time
var _quantity: int = 1

const MIN_WAIT_TIME := 0.01

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
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var damage_mult = 1.0
	if player.get("damage_multiplier") != null:
		damage_mult = player.damage_multiplier
	var damage = base_damage * damage_mult
	for i in _quantity:
		var axe_instance = axe_ability_scene.instantiate() as Node2D
		axe_instance.initial_angle = i * TAU / _quantity
		axe_instance.orbit_direction = 1.0 if i % 2 == 0 else -1.0
		foreground.add_child(axe_instance)
		axe_instance.global_position = player.global_position
		axe_instance.hitbox_component.damage = damage


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	if upgrade.id == "axe_quantity":
		_quantity = 1 + current_upgrades["axe_quantity"]["quantity"]
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
