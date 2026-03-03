extends Node

const SPAWN_RADIUS = 380
const GROUP_SPAWN_OFFSET_RADIUS := 24.0  # max pixels from center when spawning a group

## Seconds removed from spawn interval per difficulty level (e.g. 0.02 = 0.02s faster per level).
const SPAWN_TIME_OFF_PER_DIFFICULTY := 0.0066666666666667
## Maximum seconds to remove from base spawn time (so spawn never goes below base - this).
const MAX_SPAWN_TIME_OFF := 0.8

## Tier unlock difficulties (1 per 5s): T1=0, T2=24, T3=48, T4=72, T5=96 (0, 2, 4, 6, 8 min)
const TIER_DIFFICULTIES := [0, 24, 48, 72, 96]
const WEIGHT_BASE := 200  # scale 2 for integer weights (100 -> 200)

@export var basic_enemy_scene: PackedScene
@export var basic_enemy_2_scene: PackedScene
@export var wizard_enemy_scene: PackedScene
@export var bat_enemy_scene: PackedScene
@export var ghost_enemy_scene: PackedScene
@export var spider_enemy_scene: PackedScene
@export var ogre_enemy_scene: PackedScene
@export var arena_time_manager: Node

@onready var timer = $Timer

var base_spawn_time = 0
var enemy_table = WeightedTable.new()
var _arena_difficulty := 0
var _current_tier := 1
var _prev_tier := 0  # for debug: only log when tier changes

## Enemy config: scene, tier, is_flying, unlock_diff
var _enemy_configs: Array = []

# Elite spawn: pre-10min fixed at 1, 3, 5, 7, 9 min; post-10min at most once per minute
var _elite_count_pre_10 := 0
var _last_post_10_elite_difficulty := 108  # so first post-10 elite eligible at 120
const ELITE_DIFFICULTIES := [12, 36, 60, 84, 108]  # 1, 3, 5, 7, 9 min (between tier unlocks)
const ELITE_POST_10_COOLDOWN := 12  # difficulty units = 1 min (1 per 5s)
const ELITE_CHANCE_POST_10 := 0.012  # Post-10min: roll when off cooldown
const ELITE_DROP_SCENE := preload("res://scenes/component/elite_drop_component.tscn")
const ELITE_OUTLINE_SHADER := preload("res://scenes/component/elite_outline.gdshader")

func _build_enemy_configs() -> void:
	_enemy_configs.clear()
	if basic_enemy_scene:
		_enemy_configs.append({"scene": basic_enemy_scene, "tier": 1, "is_flying": false, "unlock_diff": 0})
	if basic_enemy_2_scene:
		_enemy_configs.append({"scene": basic_enemy_2_scene, "tier": 2, "is_flying": false, "unlock_diff": 24})
	if bat_enemy_scene:
		_enemy_configs.append({"scene": bat_enemy_scene, "tier": 2, "is_flying": true, "unlock_diff": 24})
	if wizard_enemy_scene:
		_enemy_configs.append({"scene": wizard_enemy_scene, "tier": 3, "is_flying": false, "unlock_diff": 48})
	if spider_enemy_scene:
		_enemy_configs.append({"scene": spider_enemy_scene, "tier": 4, "is_flying": false, "unlock_diff": 72})
	if ghost_enemy_scene:
		_enemy_configs.append({"scene": ghost_enemy_scene, "tier": 4, "is_flying": true, "unlock_diff": 72})
	if ogre_enemy_scene:
		_enemy_configs.append({"scene": ogre_enemy_scene, "tier": 5, "is_flying": false, "unlock_diff": 96})


func _get_current_tier() -> int:
	for i in range(TIER_DIFFICULTIES.size() - 1, -1, -1):
		if _arena_difficulty >= TIER_DIFFICULTIES[i]:
			return i + 1
	return 1


func _get_config_for_scene(scene: PackedScene) -> Dictionary:
	for cfg in _enemy_configs:
		if cfg["scene"] == scene:
			return cfg
	return {}


func _get_group_size_for_enemy(scene: PackedScene) -> int:
	var cfg := _get_config_for_scene(scene)
	if cfg.is_empty():
		return 1
	var effective_tier: int = cfg["tier"] - 1 if cfg["is_flying"] else cfg["tier"]
	var delta := _current_tier - effective_tier
	return maxi(1, 1 + 2 * delta)


func _scene_short_name(scene: PackedScene) -> String:
	if scene == null:
		return "null"
	return scene.resource_path.get_file().get_basename()


func _rebuild_spawn_weights() -> void:
	_current_tier = _get_current_tier()
	var entries: Array = []
	for cfg in _enemy_configs:
		if _arena_difficulty < cfg["unlock_diff"]:
			continue
		if _arena_difficulty > 120 and (cfg["tier"] == 1 or cfg["tier"] == 2):
			continue
		var tier_delta: int = _current_tier - int(cfg["tier"])
		var weight_float := WEIGHT_BASE * pow(0.5, float(tier_delta))
		if cfg["is_flying"]:
			weight_float *= 0.5
		var weight := maxi(1, int(weight_float))
		entries.append({"item": cfg["scene"], "weight": weight})
	enemy_table.replace_all(entries)
	# Debug: log when tier changes
	if _current_tier != _prev_tier:
		_prev_tier = _current_tier
		var min_per_tier := [0, 2, 4, 6, 8]
		var min_str := str(min_per_tier[_current_tier - 1]) if _current_tier <= min_per_tier.size() else "?"
		print("[EnemyManager] Tier %d (unlocked at %s min) | difficulty %d" % [_current_tier, min_str, _arena_difficulty])
		var parts: Array[String] = []
		for e in entries:
			parts.append("%s=%d" % [_scene_short_name(e["item"]), e["weight"]])
		print("[EnemyManager] Weights: %s" % [", ".join(parts)])


func _ready() -> void:
	_build_enemy_configs()
	base_spawn_time = timer.wait_time
	timer.timeout.connect(on_timer_timeout)
	arena_time_manager.arena_difficulty_increased.connect(on_arena_difficulty_increased)
	_rebuild_spawn_weights()


func get_spawn_position():
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	
	var spawn_position = Vector2.ZERO
	var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))

	for i in 4:
		spawn_position = player.global_position + (random_direction * SPAWN_RADIUS)
		var query_paramaters = PhysicsRayQueryParameters2D.create(player.global_position, spawn_position, 1)
		var result = get_tree().root.world_2d.direct_space_state.intersect_ray(query_paramaters)
	
		if result.is_empty():
			break
		else:
			random_direction = random_direction.rotated(deg_to_rad(90))
	
	return spawn_position


## Spawn position for flying enemies: on the same radius but no wall check, so they can spawn past arena walls.
func get_spawn_position_flying() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO
	var random_direction := Vector2.RIGHT.rotated(randf_range(0, TAU))
	return player.global_position + random_direction * SPAWN_RADIUS



func on_timer_timeout():
	timer.start()

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	# One spawn pick per tick; group size and tier mix handle difficulty
	var spawn_count: int = 1
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	for _i in spawn_count:
		var enemy_scene = enemy_table.pick_item()
		if enemy_scene == null:
			continue
		var cfg := _get_config_for_scene(enemy_scene)
		var base_pos: Vector2 = get_spawn_position_flying() if cfg.get("is_flying", false) else get_spawn_position()
		var group_size: int = _get_group_size_for_enemy(enemy_scene)
		for j in group_size:
			# Before 10 min, elites may only spawn on the highest-health enemy type in the pool
			var will_be_elite := _try_make_elite(null)
			var scene_to_spawn: PackedScene = enemy_scene
			if will_be_elite and _arena_difficulty <= 120:
				scene_to_spawn = _get_highest_health_enemy_scene()
				if scene_to_spawn == null:
					scene_to_spawn = enemy_scene
			elif will_be_elite and _arena_difficulty > 120 and ogre_enemy_scene:
				scene_to_spawn = ogre_enemy_scene
			var enemy = scene_to_spawn.instantiate() as Node2D
			entities_layer.add_child(enemy)
			var offset = Vector2(randf_range(-GROUP_SPAWN_OFFSET_RADIUS, GROUP_SPAWN_OFFSET_RADIUS), randf_range(-GROUP_SPAWN_OFFSET_RADIUS, GROUP_SPAWN_OFFSET_RADIUS))
			enemy.global_position = base_pos + offset
			if will_be_elite:
				_apply_elite(enemy)
				var hc = enemy.get_node_or_null("HealthComponent") as HealthComponent
				var elite_min := 0.0
				if _elite_count_pre_10 <= ELITE_DIFFICULTIES.size():
					elite_min = ELITE_DIFFICULTIES[_elite_count_pre_10 - 1] / 12.0  # diff 12 = 1 min
				print("[EnemyManager] ELITE spawned: %s (HP %.0f) at diff %d (elite #%d, ~%.1f min)" % [enemy.name, hc.max_health if hc else 0, _arena_difficulty, _elite_count_pre_10, elite_min])
			else:
				_apply_post_10_min_scaling(enemy)


func _get_highest_health_enemy_scene() -> PackedScene:
	var best_scene: PackedScene = null
	var best_health: float = -1.0
	for entry in enemy_table.items:
		var scene: PackedScene = entry["item"] as PackedScene
		if scene == null:
			continue
		var temp = scene.instantiate() as Node2D
		add_child(temp)
		var hc = temp.get_node_or_null("HealthComponent") as HealthComponent
		var health: float = hc.max_health if hc else 0.0
		temp.queue_free()
		if health > best_health:
			best_health = health
			best_scene = scene
	return best_scene


func _try_make_elite(_enemy: Node2D) -> bool:
	if _arena_difficulty <= 120:
		if _elite_count_pre_10 >= ELITE_DIFFICULTIES.size():
			return false
		return _arena_difficulty >= ELITE_DIFFICULTIES[_elite_count_pre_10]
	else:
		if _arena_difficulty < _last_post_10_elite_difficulty + ELITE_POST_10_COOLDOWN:
			return false
		return randf() < ELITE_CHANCE_POST_10


func _apply_elite(enemy: Node2D) -> void:
	if _arena_difficulty <= 120:
		_elite_count_pre_10 += 1
	else:
		_last_post_10_elite_difficulty = _arena_difficulty

	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		var base_health = health.max_health
		health.max_health = (base_health + 1.0) * 10.0
		health.current_health = health.max_health

	# Replace VialDropComponent with EliteDropComponent
	var vial_drop = enemy.get_node_or_null("VialDropComponent")
	var base_amount := 1.0
	if vial_drop and "amount" in vial_drop:
		base_amount = vial_drop.amount
	if vial_drop:
		vial_drop.queue_free()

	var elite_drop = ELITE_DROP_SCENE.instantiate() as Node
	elite_drop.health_component = health
	elite_drop.arena_time_manager = arena_time_manager
	elite_drop.base_vial_amount = base_amount
	enemy.add_child(elite_drop)

	# 50% increased scale for elites
	enemy.scale *= 1.5

	# Bright red outline on visuals (apply to all Sprite2D under Visuals)
	var visuals = enemy.get_node_or_null("Visuals")
	if visuals:
		var mat = ShaderMaterial.new()
		mat.shader = ELITE_OUTLINE_SHADER
		mat.set_shader_parameter("outline_color", Color(1.0, 0.0, 0.0, 1.0))
		for child in visuals.get_children():
			if child is Sprite2D:
				child.material = mat


func _apply_post_10_min_scaling(enemy: Node2D) -> void:
	if _arena_difficulty <= 120:
		return
	var post_10_min_levels := _arena_difficulty - 120
	var multiplier := 1.0 + post_10_min_levels * 0.01

	var health := enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.max_health *= multiplier
		health.current_health = health.max_health

	var velocity := enemy.get_node_or_null("VelocityComponent")
	if velocity:
		velocity.max_speed = int(velocity.max_speed * multiplier)
		velocity.acceleration *= multiplier


func on_arena_difficulty_increased(arena_difficulty: int):
	_arena_difficulty = arena_difficulty
	var time_off = SPAWN_TIME_OFF_PER_DIFFICULTY * arena_difficulty
	time_off = min(time_off, MAX_SPAWN_TIME_OFF)
	timer.wait_time = max(base_spawn_time - time_off, 0.05)
	_rebuild_spawn_weights()
