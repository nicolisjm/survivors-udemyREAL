extends Node
## Spawns breakables (barrel, crate, crate tower) off-screen at a constant, infrequent rate.

const SPAWN_RADIUS := 380.0
const SPAWN_CHANCE := 0.30  # 30% chance each tick
const SPAWN_INTERVAL := 14.0  # seconds, constant whole game

@export var barrel_scene: PackedScene
@export var crate_scene: PackedScene
@export var crate_tower_scene: PackedScene

var breakable_table := WeightedTable.new()

@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.wait_time = SPAWN_INTERVAL
	timer.timeout.connect(on_timer_timeout)
	timer.start()

	if barrel_scene:
		breakable_table.add_item(barrel_scene, 10)
	if crate_scene:
		breakable_table.add_item(crate_scene, 8)
	if crate_tower_scene:
		breakable_table.add_item(crate_tower_scene, 4)


func get_spawn_position() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.ZERO

	var spawn_position = Vector2.ZERO
	var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))

	for i in 4:
		spawn_position = player.global_position + (random_direction * SPAWN_RADIUS)
		var query = PhysicsRayQueryParameters2D.create(player.global_position, spawn_position, 1)
		var result = get_tree().root.world_2d.direct_space_state.intersect_ray(query)
		if result.is_empty():
			break
		random_direction = random_direction.rotated(deg_to_rad(90))

	return spawn_position


func on_timer_timeout() -> void:
	timer.start()

	if randf() > SPAWN_CHANCE:
		return

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var breakable_scene = breakable_table.pick_item()
	if breakable_scene == null:
		return

	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	if entities_layer == null:
		return

	var spawn_pos = get_spawn_position()
	var breakable = breakable_scene.instantiate() as Node2D
	entities_layer.add_child(breakable)
	breakable.global_position = spawn_pos
	print("[Breakable] Spawned %s at %s" % [breakable.name, spawn_pos])
