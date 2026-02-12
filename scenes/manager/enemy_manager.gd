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
			var enemy = enemy_scene.instantiate() as Node2D
			entities_layer.add_child(enemy)
			var offset = Vector2(randf_range(-GROUP_SPAWN_OFFSET_RADIUS, GROUP_SPAWN_OFFSET_RADIUS), randf_range(-GROUP_SPAWN_OFFSET_RADIUS, GROUP_SPAWN_OFFSET_RADIUS))
			enemy.global_position = base_pos + offset


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
		enemy_table.add_item(wizard_enemy_scene, 30)
		print("[EnemyManager] difficulty 24: ADDED wizard_enemy to table (weight 30)")
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
