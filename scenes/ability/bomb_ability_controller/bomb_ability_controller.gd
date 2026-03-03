extends Node

@export var bomb_ability_scene: PackedScene

const MIN_WAIT_TIME := 0.01
## Max distance to consider an enemy for targeting (pixels).
const MAX_TARGET_RANGE := 400.0
## Throw distance is clamped: at least this, at most THROW_DISTANCE_MAX (based on enemy distance).
const THROW_DISTANCE_MIN := 40.0
const THROW_DISTANCE_MAX := 80.0
## Minimum distance between any two bomb land positions (so bombs don't stack when enemies are close).
const MIN_SPREAD_DISTANCE := 25
## Angular spread per bomb in degrees (so many bombs fan out instead of lining up and stacking at max range).
const SPREAD_ANGLE_DEG := 30
## Delay in seconds between each bomb throw in a volley.
const THROW_DELAY := 0.1
const ARC_DURATION := 0.4
const ARC_HEIGHT := 50.0

var base_damage: int = 10
var base_wait_time: float
## Bombs per volley: 1 base, +1 at 4, +1 at 6, +2 at 8.
var _quantity: int = 1
## Area (explosion size) multiplier: +20% at levels 2, 5, 7.
var _size_mult: float = 1.0
## +2 base damage at level 3.
var _damage_flat_bonus: int = 0
## Level 9: when a bomb explodes, spawn 2 mini bombs that lob toward enemies (25% scale/damage/distance).
var _spawn_mini_bombs: bool = false


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("bomb") if manager else 0


func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	# 1: unlock. 2: area +20%. 3: base damage +2. 4: +1 bomb. 5: area +20%. 6: +1 bomb. 7: area +20%. 8: +2 bombs. 9: mini bombs on explode.
	_quantity = 1
	if level >= 4:
		_quantity += 1   # 2
	if level >= 6:
		_quantity += 1   # 3
	if level >= 8:
		_quantity += 2   # 5

	_size_mult = 1.0
	if level >= 2:
		_size_mult *= 1.2   # +20%
	if level >= 5:
		_size_mult *= 1.2
	if level >= 7:
		_size_mult *= 1.2

	_damage_flat_bonus = 2 if level >= 3 else 0
	_spawn_mini_bombs = level >= 9


func _get_nearest_enemy_positions(count: int) -> Array[Vector2]:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		var out: Array[Vector2] = []
		var mid := (THROW_DISTANCE_MIN + THROW_DISTANCE_MAX) * 0.5
		for i in count:
			out.append(Vector2.from_angle(randf() * TAU) * mid)
		return out
	var player_pos: Vector2 = player.global_position
	var range_sq := MAX_TARGET_RANGE * MAX_TARGET_RANGE
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return enemy.global_position.distance_squared_to(player_pos) < range_sq
	)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player_pos) < b.global_position.distance_squared_to(player_pos)
	)
	var result: Array[Vector2] = []
	# Base direction for fan: toward nearest enemy (or zero for random).
	var center_dir: Vector2 = Vector2.RIGHT
	if enemies.size() > 0:
		center_dir = ((enemies[0] as Node2D).global_position - player_pos).normalized()
	for i in count:
		# Fan out multiple bombs by angle so they don't stack at max range.
		var angle_offset_rad: float = 0.0
		if count > 1:
			var center_index: float = (count - 1) / 2.0
			angle_offset_rad = deg_to_rad((float(i) - center_index) * SPREAD_ANGLE_DEG)
		var dir: Vector2 = center_dir.rotated(angle_offset_rad)
		var throw_dist: float
		if i < enemies.size():
			var enemy_pos: Vector2 = (enemies[i] as Node2D).global_position
			var dist_to_enemy: float = player_pos.distance_to(enemy_pos)
			throw_dist = clampf(dist_to_enemy, THROW_DISTANCE_MIN, THROW_DISTANCE_MAX)
		else:
			dir = Vector2.from_angle(randf() * TAU)
			throw_dist = (THROW_DISTANCE_MIN + THROW_DISTANCE_MAX) * 0.5
		var land_pos: Vector2 = player_pos + dir * throw_dist
		# Enforce minimum spread from other bombs (push along our direction until clear).
		var max_push_iters := 10
		while max_push_iters > 0:
			var too_close: bool = false
			for j in result.size():
				var d: float = land_pos.distance_to(result[j])
				if d < MIN_SPREAD_DISTANCE and d > 0.0001:
					too_close = true
					var shortfall: float = MIN_SPREAD_DISTANCE - d
					land_pos += dir * shortfall
					var dist_from_player: float = land_pos.distance_to(player_pos)
					if dist_from_player > THROW_DISTANCE_MAX:
						land_pos = player_pos + (land_pos - player_pos).normalized() * THROW_DISTANCE_MAX
					break
			if not too_close:
				break
			max_push_iters -= 1
		result.append(land_pos)
	return result


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	$Timer.wait_time = max(base_wait_time / mult, MIN_WAIT_TIME)
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
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	var damage: float = (base_damage + _damage_flat_bonus + flat_bonus) * damage_mult
	var land_positions: Array = _get_nearest_enemy_positions(_quantity)

	for i in range(land_positions.size()):
		if i > 0:
			await get_tree().create_timer(THROW_DELAY).timeout
		var land_pos: Vector2 = land_positions[i]
		var bomb = bomb_ability_scene.instantiate()
		bomb.land_position = land_pos
		bomb.start_position = player.global_position
		bomb.damage = damage
		bomb.size_mult = _size_mult * size_mult
		bomb.arc_duration = ARC_DURATION
		bomb.arc_height = ARC_HEIGHT
		if _spawn_mini_bombs:
			bomb.spawn_mini_bombs = true
			bomb.mini_bomb_scene = bomb_ability_scene
		foreground.add_child(bomb)


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "bomb":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage", "generic_damage_prestige", "generic_size", "generic_size_prestige"]:
		pass
