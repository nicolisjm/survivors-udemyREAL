extends Node

@export var chain_lightning_ability_scene: PackedScene
@export var max_chain_count: int = 3
## Sparks shown at each chain hit. Assign a HitSparkConfig .tres for chain-lightning look, or leave empty for default.
@export var hit_spark_config: HitSparkConfig

const DEFAULT_VISUAL_SCENE = preload("res://scenes/ability/chainLightning_ability/chainLightning_ability.tscn")
const DEFAULT_SPARK_CONFIG = preload("res://resources/effects/chain_lightning_spark_config.tres") as HitSparkConfig
const MIN_WAIT_TIME := 0.01
const STUN_DURATION_LEVEL_9: float = 0.2

## Max distance from player to consider enemies for bolts, and from each enemy to the next chain target. Lower = shorter chains.
@export var chain_range: float = 120.0

var base_damage: int = 6
var base_wait_time: float
var _effective_chain_count: int = 3
var _quantity: int = 1
var _damage_flat_bonus: int = 0
var _rate_reduction: float = 0.0
var _chains_doubled: bool = false
var _stun_duration: float = 0.0

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_chain_lightning_level() -> int:
	var manager = _get_upgrade_manager()
	if manager != null and manager.has_method("get_ability_level"):
		return manager.get_ability_level("chain_lightning")
	return 0


## Level 1 = unlock. 2: +1 chain. 3: +2 damage. 4: +1 bolt. 5: +1 chain. 6: attack rate -0.2s. 7: +1 bolt. 8: attack rate -0.2s. 9: chains x2 + stun 0.2s.
func _apply_stats_from_level() -> void:
	var level: int = _get_chain_lightning_level()
	_effective_chain_count = max_chain_count
	if level >= 2:
		_effective_chain_count += 1
	if level >= 5:
		_effective_chain_count += 1
	_chains_doubled = level >= 9
	if _chains_doubled:
		_effective_chain_count *= 2

	_quantity = 1
	if level >= 4:
		_quantity = 2
	if level >= 7:
		_quantity = 3

	_damage_flat_bonus = 2 if level >= 3 else 0

	_rate_reduction = 0.0
	if level >= 6:
		_rate_reduction += 0.2
	if level >= 8:
		_rate_reduction += 0.2

	_stun_duration = STUN_DURATION_LEVEL_9 if level >= 9 else 0.0


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
	var wait: float = base_wait_time - _rate_reduction
	$Timer.wait_time = max(wait / mult, MIN_WAIT_TIME)
	$Timer.start()


func on_timer_timeout() -> void:
	var level: int = _get_chain_lightning_level()
	if level <= 0:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var range_sq: float = chain_range * chain_range
	var all_enemies = get_tree().get_nodes_in_group("enemy")
	all_enemies = all_enemies.filter(func(enemy: Node2D):
		return enemy.global_position.distance_squared_to(player.global_position) < range_sq
	)
	if all_enemies.is_empty():
		return
	all_enemies.sort_custom(func(a: Node2D, b: Node2D):
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)

	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var damage_amount: float = (base_damage + _damage_flat_bonus) * damage_mult
	var spark_cfg: HitSparkConfig = hit_spark_config if hit_spark_config else DEFAULT_SPARK_CONFIG
	var scene_to_use = chain_lightning_ability_scene if chain_lightning_ability_scene else DEFAULT_VISUAL_SCENE

	# No enemy can be chained to more than once per cast (across all bolts).
	var already_hit_this_cast: Array[Node2D] = []

	for bolt_index in _quantity:
		# First target: next closest enemy not already hit this cast
		var first_target: Node2D = null
		for i in all_enemies.size():
			var candidate = all_enemies[i] as Node2D
			if candidate in already_hit_this_cast:
				continue
			first_target = candidate
			break
		if first_target == null:
			break
		var result = _build_one_chain(player, first_target, already_hit_this_cast)
		var chain_positions: Array = result["positions"]
		var chain_enemies: Array = result["enemies"]
		if chain_positions.size() <= 1:
			continue
		for enemy in chain_enemies:
			already_hit_this_cast.append(enemy)
			var hurtbox = enemy.get_node_or_null("HurtboxComponent") as HurtboxComponent
			if hurtbox:
				hurtbox.apply_damage(damage_amount, spark_cfg, _stun_duration)
		var chain_visual = scene_to_use.instantiate() as Node2D
		foreground.add_child(chain_visual)
		chain_visual.global_position = Vector2.ZERO
		if chain_visual.has_method("set_chain_positions"):
			chain_visual.set_chain_positions(chain_positions)


func _build_one_chain(player: Node2D, first_target: Node2D, exclude_enemies: Array[Node2D]) -> Dictionary:
	var chain_positions: Array[Vector2] = [player.global_position, first_target.global_position]
	var chain_enemies: Array[Node2D] = [first_target]
	var search_center = first_target.global_position
	var range_sq: float = chain_range * chain_range

	for _i in _effective_chain_count - 1:
		var enemies = get_tree().get_nodes_in_group("enemy")
		enemies = enemies.filter(func(enemy: Node2D):
			if enemy in chain_enemies:
				return false
			if enemy in exclude_enemies:
				return false
			return enemy.global_position.distance_squared_to(search_center) < range_sq
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


func on_ability_upgrade_added(upgrade: AbilityUpgrade, current_upgrades: Dictionary) -> void:
	if upgrade.ability_id == "chain_lightning":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage_10", "generic_damage_20", "generic_damage_30"]:
		pass
