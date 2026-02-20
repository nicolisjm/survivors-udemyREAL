extends Node2D

const MAX_RADIUS = 100

@onready var hitbox_component = $HitboxComponent

## Set before adding to tree for quantity variation: starting angle (radians) and orbit direction (1 = counter-clockwise, -1 = clockwise).
var initial_angle: float = NAN
var orbit_direction: float = 1.0
## Multiplier for how long the axe orbits (default 1.0). Same orbital speed, more rotations and time.
var duration_mult: float = 1
## Multiplier for orbit radius (generic size upgrade). Default 1.0.
var radius_mult: float = 1.0

var base_rotation := Vector2.RIGHT
var _max_rotations: float = 1


func _ready() -> void:
	if is_nan(initial_angle):
		initial_angle = randf_range(0, TAU)
	base_rotation = Vector2.RIGHT.rotated(initial_angle)

	# Scale both rotations and time so orbital speed stays the same; axe just orbits longer.
	_max_rotations = 1 * duration_mult
	var duration: float = 1.5 * duration_mult
	var tween = create_tween()
	tween.tween_method(tween_method, 0.0, _max_rotations, duration)
	tween.tween_callback(queue_free)


func tween_method(rotations: float) -> void:
	var percent: float = rotations / _max_rotations
	var current_radius: float = percent * MAX_RADIUS * radius_mult
	var current_direction = base_rotation.rotated(rotations * TAU * orbit_direction)
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	global_position = player.global_position + (current_direction * current_radius)
	
