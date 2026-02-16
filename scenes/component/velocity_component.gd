extends Node

@export var max_speed: int = 40
@export var acceleration: float = 5
## When using move_node2d (Area2D enemies), push away from nearby entities to prevent overlap.
## Lower values allow more bunching (~40% sprite overlap).
@export var separation_radius: float = 40
@export var separation_strength: float = 160
## Skip separation when farther from player (saves CPU for off-screen enemies).
@export var separation_max_player_dist: float = 280.0
## Update AI direction every N frames (1=every frame). Reduces CPU with many enemies.
@export var ai_update_interval: int = 2
## Run separation every N frames (1=every frame). Major FPS win with many enemies.
@export var separation_update_interval: int = 2
## Cap neighbors per enemy (0 = no cap). Use e.g. 20–24 in late game to keep Process time bounded when 500+ enemies.
@export var separation_max_neighbors: int = 0

var velocity = Vector2.ZERO

# Cache enemy list + spatial grid once per frame. Spatial grid reduces O(n²) to O(n*k).
# Smaller cells = fewer enemies per 3x3 = less work. 3x3 must cover separation_radius (24 gives 72px).
static var _cached_enemies: Array = []
static var _cached_grid: Dictionary = {}  # Vector2i -> Array of enemies in cell
static var _cached_frame: int = -1
const _CELL_SIZE: float = 24.0


func accelerate_to_player():
	# Throttle AI updates - run every ai_update_interval frames to reduce CPU.
	if ai_update_interval > 1 and Engine.get_process_frames() % ai_update_interval != 0:
		return
	var owner_node2d := owner as Node2D
	if owner_node2d == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var direction: Vector2 = (player.global_position - owner_node2d.global_position).normalized()
	accelerate_in_direction(direction)


func accelerate_in_direction(direction: Vector2):
	var desired_velocity = direction * max_speed
	velocity = velocity.lerp(desired_velocity, 1 - exp(-acceleration * get_process_delta_time()))
	
	
func decelerate():
	accelerate_in_direction(Vector2.ZERO)


func move(node: Node2D) -> void:
	var delta := get_process_delta_time()
	if node is CharacterBody2D:
		var character_body := node as CharacterBody2D
		character_body.velocity = velocity
		character_body.move_and_slide()
		velocity = character_body.velocity
	else:
		if node.is_in_group("enemy") and separation_strength > 0:
			if separation_update_interval <= 1 or Engine.get_process_frames() % separation_update_interval == 0:
				_apply_separation(node, delta)
		_move_node2d(node, delta)


func _move_node2d(node: Node2D, delta: float) -> void:
	node.global_position += velocity * delta


func _apply_separation(node: Node2D, delta: float) -> void:
	var tree := node.get_tree()
	if tree == null:
		return
	var pos := node.global_position
	var radius_sq := separation_radius * separation_radius

	# Skip separation for enemies far from player (off-screen) - big perf win.
	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	if player and is_instance_valid(player):
		var player_dist_sq := pos.distance_squared_to(player.global_position)
		if player_dist_sq > separation_max_player_dist * separation_max_player_dist:
			return
		# Player separation
		if player_dist_sq < radius_sq and player_dist_sq > 0.001:
			var d := pos.distance_to(player.global_position)
			var away: Vector2 = (pos - player.global_position).normalized()
			var strength: float = separation_strength * (1.0 - d / separation_radius)
			velocity += away * strength * delta

	# Use cached enemy list + spatial grid. Build grid once per frame.
	var frame := Engine.get_process_frames()
	if frame != _cached_frame:
		_cached_frame = frame
		_cached_enemies = tree.get_nodes_in_group("enemy")
		_cached_grid.clear()
		for other in _cached_enemies:
			if not is_instance_valid(other):
				continue
			var op: Vector2 = (other as Node2D).global_position
			var cell := Vector2i(int(op.x / _CELL_SIZE), int(op.y / _CELL_SIZE))
			if not _cached_grid.has(cell):
				_cached_grid[cell] = []
			_cached_grid[cell].append(other)

	# Only check enemies in same cell + 8 neighbors (spatial partitioning).
	var cell := Vector2i(int(pos.x / _CELL_SIZE), int(pos.y / _CELL_SIZE))
	var sep := Vector2.ZERO
	var count := 0
	var done := false
	for dx in range(-1, 2):
		if done:
			break
		for dy in range(-1, 2):
			if separation_max_neighbors > 0 and count >= separation_max_neighbors:
				done = true
				break
			var c := Vector2i(cell.x + dx, cell.y + dy)
			if not _cached_grid.has(c):
				continue
			for other in _cached_grid[c]:
				if separation_max_neighbors > 0 and count >= separation_max_neighbors:
					break
				if other == node or not is_instance_valid(other):
					continue
				count += 1
				var other_pos: Vector2 = (other as Node2D).global_position
				var d_sq := pos.distance_squared_to(other_pos)
				if d_sq < radius_sq and d_sq > 0.001:
					var d := pos.distance_to(other_pos)
					var away: Vector2 = (pos - other_pos).normalized()
					var strength: float = separation_strength * (1.0 - d / separation_radius)
					sep += away * strength

	velocity += sep * delta
