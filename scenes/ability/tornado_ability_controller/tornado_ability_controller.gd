extends Node

@export var tornado_ability_scene: PackedScene

const MIN_WAIT_TIME := 0.01
const BASE_DAMAGE := 3
const BASE_DURATION := 4.0
const BASE_WAIT_TIME := 2.7
const BASE_TICK_RATE := 0.33
const PULL_STRENGTH_WEAK := 60.0
const PULL_STRENGTH_STRONG := 90.0
const MAX_AIM_RANGE := 500.0
## Minimum angle in degrees between each tornado when multiple are fired.
const MIN_SPREAD_DEGREES := 30.0
## Delay in seconds between spawning each tornado when multiple.
const SPAWN_DELAY := 0.1

var base_wait_time: float = BASE_WAIT_TIME
var _duration_mult: float = 1.0
var _damage_flat_bonus: int = 0
var _tornado_count: int = 1
var _strong_pull: bool = false
var _tick_interval: float = BASE_TICK_RATE


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("tornado") if manager else 0


func _apply_stats_from_level() -> void:
	var level: int = _get_ability_level()
	base_wait_time = BASE_WAIT_TIME
	_duration_mult = 1.0
	_damage_flat_bonus = 0
	_tornado_count = 1
	_strong_pull = false
	_tick_interval = BASE_TICK_RATE

	if level >= 2:
		_duration_mult *= 1.2
	if level >= 3:
		base_wait_time -= 0.2
	if level >= 4:
		_damage_flat_bonus += 2
	if level >= 5:
		_tornado_count = 2
	if level >= 6:
		_duration_mult *= 1.2
	if level >= 7:
		base_wait_time -= 0.2
	if level >= 8:
		_tornado_count = 3
	if level >= 9:
		_strong_pull = true
		_tick_interval = BASE_TICK_RATE / 1.5


func _get_aim_directions(count: int) -> Array[Vector2]:
	var directions: Array[Vector2] = []
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		for i in count:
			directions.append(Vector2.RIGHT)
		return directions
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return enemy.global_position.distance_squared_to(player.global_position) < pow(MAX_AIM_RANGE, 2)
	)
	if enemies.is_empty():
		var fallback := Vector2.RIGHT
		var last_move = player.get("last_move_direction")
		if last_move != null and (last_move as Vector2).length_squared() > 0.0001:
			fallback = (last_move as Vector2).normalized()
		for i in count:
			directions.append(fallback)
		return directions
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)
	for i in count:
		var idx: int = mini(i, enemies.size() - 1)
		var target = (enemies[idx] as Node2D).global_position
		directions.append((target - player.global_position).normalized())
	return directions


func _apply_minimum_spread(directions: Array[Vector2]) -> Array[Vector2]:
	if directions.size() <= 1:
		return directions
	var center := Vector2.ZERO
	for d in directions:
		center += d
	center = center.normalized()
	if center.length_squared() < 0.0001:
		center = Vector2.RIGHT
	var spread: Array[Vector2] = []
	var n := directions.size()
	for i in n:
		var angle_offset_deg: float = (float(i) - (n - 1) * 0.5) * MIN_SPREAD_DEGREES
		spread.append(center.rotated(deg_to_rad(angle_offset_deg)))
	return spread


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	$Timer.wait_time = maxf(base_wait_time / mult, MIN_WAIT_TIME)
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
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	var damage: float = (BASE_DAMAGE + _damage_flat_bonus + flat_bonus) * damage_mult
	var duration: float = BASE_DURATION * _duration_mult
	var duration_mult_player: float = player.get("duration_multiplier") if player.get("duration_multiplier") != null else 1.0
	duration *= duration_mult_player
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	var pull_strength: float = PULL_STRENGTH_STRONG if _strong_pull else PULL_STRENGTH_WEAK

	var directions: Array[Vector2] = _get_aim_directions(_tornado_count)
	directions = _apply_minimum_spread(directions)

	for i in _tornado_count:
		var tornado = tornado_ability_scene.instantiate() as Node2D
		tornado.direction = directions[i]
		tornado.damage = damage
		tornado.duration = duration
		tornado.tick_interval = _tick_interval
		tornado.size_mult = size_mult
		tornado.pull_strength = pull_strength
		foreground.add_child(tornado)
		tornado.global_position = player.global_position
		if i < _tornado_count - 1:
			await get_tree().create_timer(SPAWN_DELAY).timeout


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "tornado":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
