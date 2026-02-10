extends Node

@export var chain_lightning_ability_scene: PackedScene
@export var max_chain_count = 3
## Sparks shown at each chain hit. Assign a HitSparkConfig .tres for chain-lightning look, or leave empty for default.
@export var hit_spark_config: HitSparkConfig

# Fallback if the export isn't set in the editor (e.g. when controller is added via Ability resource).
const DEFAULT_VISUAL_SCENE = preload("res://scenes/ability/chainLightning_ability/chainLightning_ability.tscn")
const DEFAULT_SPARK_CONFIG = preload("res://resources/effects/chain_lightning_spark_config.tres") as HitSparkConfig

const MAX_RANGE = 200
const MIN_WAIT_TIME := 0.01

var base_damage = 6
var base_wait_time
var _effective_chain_count: int = 3
var _quantity: int = 1

func _ready() -> void:
	base_wait_time = $Timer.wait_time
	_effective_chain_count = max_chain_count
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

	var all_enemies = get_tree().get_nodes_in_group("enemy")
	all_enemies = all_enemies.filter(func(enemy: Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) < pow(MAX_RANGE, 2)
	)
	if all_enemies.is_empty():
		return
	all_enemies.sort_custom(func(a: Node2D, b: Node2D):
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)

	var damage_mult = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var damage_amount = base_damage * damage_mult
	var spark_cfg = hit_spark_config if hit_spark_config else DEFAULT_SPARK_CONFIG
	var scene_to_use = chain_lightning_ability_scene if chain_lightning_ability_scene else DEFAULT_VISUAL_SCENE

	# Quantity = number of bolts; each bolt has a different starting target (i-th closest enemy).
	for bolt_index in _quantity:
		if bolt_index >= all_enemies.size():
			break
		var first_target = all_enemies[bolt_index] as Node2D
		var result = _build_one_chain(player, first_target)
		var chain_positions: Array = result["positions"]
		var chain_enemies: Array = result["enemies"]
		if chain_positions.size() <= 1:
			continue
		for enemy in chain_enemies:
			var hurtbox = enemy.get_node_or_null("HurtboxComponent") as HurtboxComponent
			if hurtbox:
				hurtbox.apply_damage(damage_amount, spark_cfg)
		var chain_visual = scene_to_use.instantiate() as Node2D
		foreground.add_child(chain_visual)
		chain_visual.global_position = Vector2.ZERO
		if chain_visual.has_method("set_chain_positions"):
			chain_visual.set_chain_positions(chain_positions)


func _build_one_chain(player: Node2D, first_target: Node2D) -> Dictionary:
	var chain_positions: Array[Vector2] = [player.global_position, first_target.global_position]
	var chain_enemies: Array[Node2D] = [first_target]
	var search_center = first_target.global_position

	for _i in _effective_chain_count - 1:
		var enemies = get_tree().get_nodes_in_group("enemy")
		enemies = enemies.filter(func(enemy: Node2D):
			if enemy in chain_enemies:
				return false
			return enemy.global_position.distance_squared_to(search_center) < pow(MAX_RANGE, 2)
		)
		if enemies.is_empty():
			break
		enemies.sort_custom(func(a: Node2D, b: Node2D):
			return a.global_position.distance_squared_to(search_center) < b.global_position.distance_squared_to(search_center)
		)
		var next_enemy = enemies[0] as Node2D
		chain_enemies.append(next_enemy)
		chain_positions.append(next_enemy.global_position)
		search_center = next_enemy.global_position
	return { "positions": chain_positions, "enemies": chain_enemies }


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	if upgrade.id == "chain_lightning_chains":
		_effective_chain_count = max_chain_count + current_upgrades["chain_lightning_chains"]["quantity"]
	elif upgrade.id == "chain_lightning_quantity":
		_quantity = 1 + current_upgrades["chain_lightning_quantity"]["quantity"]
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
