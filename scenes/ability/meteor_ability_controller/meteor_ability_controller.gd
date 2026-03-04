extends Node

@export var meteor_ability_scene: PackedScene
@export var burning_ground_scene: PackedScene

const MIN_WAIT_TIME := 0.01
const BASE_WAIT_TIME := 2.5
const BASE_FALL_SPEED := 450.0
const BASE_AOE_RADIUS := 30.0
const MAX_TARGET_RANGE := 400
## Delay in seconds between spawning each meteor when multiple.
const SPAWN_DELAY := 0.1
const MIN_SPREAD_DEGREES := 25.0

var base_damage: int = 6
var base_wait_time: float
var _fall_speed: float = BASE_FALL_SPEED
var _aoe_radius: float = BASE_AOE_RADIUS
var _size_mult: float = 1.0
var _meteor_count: int = 1
var _spawn_burning_ground: bool = false
var _burning_ground_damage_per_tick: float = 1.0
var _burning_ground_tick_interval: float = 0.2
var _burning_ground_duration: float = 2.0


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("meteor") if manager else 0


func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	# 1 unlock. 2,4,6: -0.2s attack rate. 3,7: +20% size. 5: +1 meteor. 8: +2 meteors. 9: burning ground.
	base_wait_time = BASE_WAIT_TIME
	if level >= 2:
		base_wait_time -= 0.2
	if level >= 4:
		base_wait_time -= 0.2
	if level >= 6:
		base_wait_time -= 0.2
	base_wait_time = maxf(base_wait_time, MIN_WAIT_TIME)

	_size_mult = 1.0
	if level >= 3:
		_size_mult *= 1.2
	if level >= 7:
		_size_mult *= 1.2
	_aoe_radius = BASE_AOE_RADIUS * _size_mult

	_meteor_count = 1
	if level >= 5:
		_meteor_count = 2
	if level >= 8:
		_meteor_count = 3
	if level >= 9:
		_meteor_count = 5

	_spawn_burning_ground = level >= 9
	_burning_ground_damage_per_tick = 1.0
	_burning_ground_tick_interval = 0.2
	_burning_ground_duration = 2.0


func _get_spawn_y() -> float:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return -300.0
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = (vp_size / cam.zoom) * 0.5
	return cam.global_position.y - half.y - 50.0


## Get land positions with lead prediction. First meteor targets nearest enemy; additional meteors target random different enemies on screen.
func _get_land_positions(count: int) -> Array[Vector2]:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return []
	var spawn_y := _get_spawn_y()
	var range_sq := MAX_TARGET_RANGE * MAX_TARGET_RANGE
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return is_instance_valid(enemy) and enemy.global_position.distance_squared_to(player.global_position) < range_sq
	)
	if enemies.is_empty():
		var fallback: Vector2 = player.global_position + Vector2(randf_range(-80, 80), 0)
		var result: Array[Vector2] = []
		for i in count:
			result.append(fallback)
		return result
	# Nearest first for first meteor; rest get random distinct targets
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)
	var used_indices: Array[int] = []
	var positions: Array[Vector2] = []
	for i in count:
		var idx: int
		if i == 0:
			idx = 0
		else:
			var available: Array[int] = []
			for j in enemies.size():
				if used_indices.has(j):
					continue
				available.append(j)
			if available.is_empty():
				idx = randi() % enemies.size()
			else:
				idx = available.pick_random()
		used_indices.append(idx)
		var enemy: Node2D = enemies[idx]
		var enemy_pos: Vector2 = enemy.global_position
		var enemy_velocity := Vector2.ZERO
		var vc = enemy.get_node_or_null("VelocityComponent")
		if vc != null and vc.get("velocity") != null:
			enemy_velocity = vc.get("velocity") as Vector2
		var time_to_fall: float = (spawn_y - enemy_pos.y) / _fall_speed
		time_to_fall = maxf(time_to_fall, 0.1)
		var lead: Vector2 = enemy_velocity * time_to_fall
		positions.append(enemy_pos + lead)
	return positions


func _apply_minimum_spread_positions(positions: Array[Vector2]) -> Array[Vector2]:
	if positions.size() <= 1:
		return positions
	var center := Vector2.ZERO
	for p in positions:
		center += p
	center /= float(positions.size())
	var dir_from_center: Array[Vector2] = []
	for p in positions:
		dir_from_center.append((p - center).normalized())
	var n := positions.size()
	var angle_step := deg_to_rad(MIN_SPREAD_DEGREES)
	var start_angle := -angle_step * (n - 1) * 0.5
	var result: Array[Vector2] = []
	var avg_dist := 0.0
	for p in positions:
		avg_dist += center.distance_to(p)
	avg_dist /= float(positions.size())
	avg_dist = maxf(avg_dist, 30.0)
	for i in n:
		var angle := start_angle + i * angle_step
		var offset := Vector2.from_angle(angle) * avg_dist
		result.append(center + offset)
	return result


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	$Timer.wait_time = maxf(base_wait_time / mult, MIN_WAIT_TIME)
	if $Timer.is_stopped():
		$Timer.start()


func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()


func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	var damage: float = (base_damage + flat_bonus) * damage_mult
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	size_mult *= _size_mult

	var land_positions: Array[Vector2] = _get_land_positions(_meteor_count)

	for i in land_positions.size():
		var pos: Vector2 = land_positions[i]
		var meteor = meteor_ability_scene.instantiate()
		meteor.land_position = pos
		meteor.damage = damage
		meteor.aoe_radius = _aoe_radius * size_mult
		meteor.fall_speed = _fall_speed
		meteor.size_mult = size_mult
		meteor.spawn_burning_ground = _spawn_burning_ground
		meteor.burning_ground_damage_per_tick = _burning_ground_damage_per_tick
		meteor.burning_ground_tick_interval = _burning_ground_tick_interval
		meteor.burning_ground_duration = _burning_ground_duration
		meteor.burning_ground_radius = _aoe_radius * size_mult
		meteor.burning_ground_scene = burning_ground_scene
		foreground.add_child(meteor)
		if i < land_positions.size() - 1:
			await get_tree().create_timer(SPAWN_DELAY).timeout


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "meteor":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
