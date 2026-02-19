extends Node

const SPAWN_RADIUS = 380
const GROUP_SPAWN_OFFSET_RADIUS := 24.0  # max pixels from center when spawning a group

## Seconds removed from spawn interval per difficulty level (e.g. 0.02 = 0.02s faster per level).
const SPAWN_TIME_OFF_PER_DIFFICULTY := 0.01
## Maximum seconds to remove from base spawn time (so spawn never goes below base - this).
const MAX_SPAWN_TIME_OFF := 0.7

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

# Elite spawn: pre-10min ~5 total, 2min cooldown with variance; post-10min more frequent
var _last_elite_spawn_difficulty := -999
var _elite_count_pre_10 := 0
const ELITE_UNLOCK_DIFFICULTY := 24  # minute 2
const ELITE_COOLDOWN_BASE := 24  # 2 min in difficulty units (5s each)
const ELITE_COOLDOWN_VARIANCE := 8
const MAX_ELITES_PRE_10 := 5
const ELITE_CHANCE_POST_10 := 0.012  # Post-10min: elites are rarer (~1.2% per spawn tick)
const ELITE_DROP_SCENE := preload("res://scenes/component/elite_drop_component.tscn")
const ELITE_OUTLINE_SHADER := preload("res://scenes/component/elite_outline.gdshader")

func _ready() -> void:
	if basic_enemy_scene != null:
		enemy_table.add_item(basic_enemy_scene, 20)
	
	base_spawn_time = timer.wait_time
	timer.timeout.connect(on_timer_timeout)
	arena_time_manager.arena_difficulty_increased.connect(on_arena_difficulty_increased)
	

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



func on_timer_timeout():
	timer.start()

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	# Every 12 difficulty (e.g. every minute at 5s interval): +1 spawn per tick (1 at 0, 2 at 12, 3 at 24, ...)
	var spawn_count: int = 1 + int(_arena_difficulty / 24)
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	for _i in spawn_count:
		var enemy_scene = enemy_table.pick_item()
		if enemy_scene == null:
			continue
		var group_size: int = 1
		if enemy_scene == bat_enemy_scene or enemy_scene == ghost_enemy_scene:
			group_size = randi_range(3, 6)
		var base_pos = get_spawn_position()
		for j in group_size:
			# Before 10 min, elites may only spawn on the highest-health enemy type in the pool
			var will_be_elite := _try_make_elite(null)
			var scene_to_spawn: PackedScene = enemy_scene
			if will_be_elite and _arena_difficulty <= 120:
				scene_to_spawn = _get_highest_health_enemy_scene()
				if scene_to_spawn == null:
					scene_to_spawn = enemy_scene
			var enemy = scene_to_spawn.instantiate() as Node2D
			entities_layer.add_child(enemy)
			var offset = Vector2(randf_range(-GROUP_SPAWN_OFFSET_RADIUS, GROUP_SPAWN_OFFSET_RADIUS), randf_range(-GROUP_SPAWN_OFFSET_RADIUS, GROUP_SPAWN_OFFSET_RADIUS))
			enemy.global_position = base_pos + offset
			if will_be_elite:
				_apply_elite(enemy)
				var hc = enemy.get_node_or_null("HealthComponent") as HealthComponent
				print("[Elite] Spawned elite %s (health %.0f) at diff %d, pre-10 count %d" % [enemy.name, hc.max_health if hc else 0, _arena_difficulty, _elite_count_pre_10])
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
	if _arena_difficulty < ELITE_UNLOCK_DIFFICULTY:
		return false
	if _arena_difficulty <= 120:
		if _elite_count_pre_10 >= MAX_ELITES_PRE_10:
			return false
		var cooldown = ELITE_COOLDOWN_BASE + randf_range(-ELITE_COOLDOWN_VARIANCE * 0.5, ELITE_COOLDOWN_VARIANCE * 0.5)
		if _arena_difficulty < _last_elite_spawn_difficulty + cooldown:
			return false
		return true
	else:
		return randf() < ELITE_CHANCE_POST_10


func _apply_elite(enemy: Node2D) -> void:
	_last_elite_spawn_difficulty = _arena_difficulty
	if _arena_difficulty <= 120:
		_elite_count_pre_10 += 1

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
	print("[EnemyManager] on_arena_difficulty_increased received: ", arena_difficulty, " (_arena_difficulty = ", _arena_difficulty, ")")
	var time_off = SPAWN_TIME_OFF_PER_DIFFICULTY * arena_difficulty
	time_off = min(time_off, MAX_SPAWN_TIME_OFF)
	timer.wait_time = max(base_spawn_time - time_off, 0.05)

	if arena_difficulty == 6:
		enemy_table.add_item(basic_enemy_2_scene, 20)
		print("[EnemyManager] difficulty 6: ADDED basic_enemy_2 to table (weight 20). basic_enemy_2_scene is null? ", basic_enemy_2_scene == null)
	elif arena_difficulty == 12:
		enemy_table.add_item(bat_enemy_scene, 1)
		print("[EnemyManager] difficulty 12: ADDED bat_enemy to table (weight 1)")
	elif arena_difficulty == 24:
		enemy_table.add_item(wizard_enemy_scene, 25)
		print("[EnemyManager] difficulty 24: ADDED wizard_enemy to table (weight 25)")
	elif arena_difficulty == 36:
		enemy_table.add_item(ghost_enemy_scene, 1)
		enemy_table.remove_item(basic_enemy_scene)
		enemy_table.remove_item(basic_enemy_2_scene)
		enemy_table.remove_item(bat_enemy_scene)
		print("[EnemyManager] difficulty 36: ADDED ghost_enemy, REMOVED basic, basic_2, bat")
	elif arena_difficulty == 48:
		enemy_table.add_item(spider_enemy_scene, 10)
		print("[EnemyManager] difficulty 48: ADDED spider_enemy to table (weight 10)")
	elif arena_difficulty == 60:
		enemy_table.add_item(ogre_enemy_scene, 2)
		print("[EnemyManager] difficulty 60: ADDED ogre_enemy to table (weight 2)")
