extends Node

@export var earth_spikes_ability_scene: PackedScene

const MIN_WAIT_TIME := 0.01
const MAX_TARGET_RANGE := 500.0
const RECT_CENTER_OFFSET := 20
const RECT_LENGTH := 120
const RECT_WIDTH := 20
const MIN_SPIKE_DISTANCE := 12.0
const MAX_SPAWN_ATTEMPTS := 10
var SPAWN_DELAY := 0.1
const BASE_WAIT_TIME := 2.5
const BASE_KNOCKBACK := 20.0

var base_damage: int = 2
var base_linger_duration: float = 6
## Hits per spike before it retracts.
var base_max_hits: int = 1
var base_wait_time: float
var base_knockback: float = BASE_KNOCKBACK
var _quantity: int = 6
var _rect_width_mult: float = 1.0


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("earth_spikes") if manager else 0


func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	# Quantity: 6 @ L1, +3 @ L2, +3 @ L5, +6 @ L8
	_quantity = 6
	if level >= 2:
		_quantity = 9
	if level >= 5:
		_quantity = 12
	if level >= 8:
		_quantity = 18
		_rect_width_mult = 1.5 if level >= 8 else 1.0
		SPAWN_DELAY = 0.05
	if level >= 9:
		base_max_hits = 2
	# Duration +20% at L4
	base_linger_duration = 7.2 if level >= 4 else 6.0
	# Attack rate: -0.2s at L3, -0.2s at L6
	base_wait_time = BASE_WAIT_TIME
	if level >= 3:
		base_wait_time -= 0.2
	if level >= 6:
		base_wait_time -= 0.2
	# Knockback +20% at L7
	base_knockback = BASE_KNOCKBACK * 1.2 if level >= 7 else BASE_KNOCKBACK


func _get_direction_toward_nearest_enemy(player_pos: Vector2) -> Vector2:
	var range_sq := MAX_TARGET_RANGE * MAX_TARGET_RANGE
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return enemy.global_position.distance_squared_to(player_pos) < range_sq
	)
	if enemies.is_empty():
		return Vector2.RIGHT
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) < b.global_position.distance_squared_to(player_pos)
	)
	var to_nearest: Vector2 = (enemies[0] as Node2D).global_position - player_pos
	if to_nearest.length_squared() < 1.0:
		return Vector2.RIGHT
	return to_nearest.normalized()


func _get_spawn_positions(player_pos: Vector2, direction: Vector2, count: int) -> Array[Vector2]:
	## Rectangle extends from RECT_CENTER_OFFSET to RECT_CENTER_OFFSET + RECT_LENGTH in front of player.
	var spawn_start := player_pos + direction * RECT_CENTER_OFFSET
	var along := direction
	var across := direction.rotated(PI / 2.0)
	var half_width := (RECT_WIDTH * _rect_width_mult) / 2.0
	var min_dist_sq := MIN_SPIKE_DISTANCE * MIN_SPIKE_DISTANCE
	var positions: Array[Vector2] = []

	for i in count:
		var pos: Vector2
		for attempt in MAX_SPAWN_ATTEMPTS:
			var along_offset := randf_range(0.0, RECT_LENGTH)
			var across_offset := randf_range(-half_width, half_width)
			pos = spawn_start + along * along_offset + across * across_offset
			var valid := true
			for j in positions.size():
				if pos.distance_squared_to(positions[j]) < min_dist_sq:
					valid = false
					break
			if valid:
				break
		positions.append(pos)
	return positions


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	$Timer.wait_time = max(base_wait_time / mult, MIN_WAIT_TIME)
	if $Timer.is_stopped():
		$Timer.start()


func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()


func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var entities_layer := get_tree().get_first_node_in_group("entities_layer") as Node2D
	if entities_layer == null:
		return

	var player_pos: Vector2 = player.global_position
	var direction := _get_direction_toward_nearest_enemy(player_pos)
	var positions: Array[Vector2] = _get_spawn_positions(player_pos, direction, _quantity)

	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	var duration_mult: float = player.get("duration_multiplier") if player.get("duration_multiplier") != null else 1.0
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	var damage: float = (base_damage + flat_bonus) * damage_mult
	var linger: float = base_linger_duration * duration_mult

	positions.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return player_pos.distance_squared_to(a) < player_pos.distance_squared_to(b)
	)

	for i in positions.size():
		if i > 0:
			await get_tree().create_timer(SPAWN_DELAY).timeout
		var pos: Vector2 = positions[i]
		var spike = earth_spikes_ability_scene.instantiate()
		spike.damage = damage
		spike.linger_duration = linger
		spike.max_hits = base_max_hits
		spike.knockback_strength = base_knockback
		spike.size_mult = size_mult
		spike.global_position = pos
		entities_layer.add_child(spike)


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "earth_spikes":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
