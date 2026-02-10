extends Node2D

const MAX_RADIUS = 100

@onready var hitbox_component = $HitboxComponent

## Set before adding to tree for quantity variation: starting angle (radians) and orbit direction (1 = counter-clockwise, -1 = clockwise).
var initial_angle: float = NAN
var orbit_direction: float = 1.0

var base_rotation := Vector2.RIGHT


func _ready() -> void:
	if is_nan(initial_angle):
		initial_angle = randf_range(0, TAU)
	base_rotation = Vector2.RIGHT.rotated(initial_angle)

	var tween = create_tween()
	tween.tween_method(tween_method, 0.0, 2.0, 3)
	tween.tween_callback(queue_free)


func tween_method(rotations: float) -> void:
	var percent = rotations / 2
	var current_radius = percent * MAX_RADIUS
	var current_direction = base_rotation.rotated(rotations * TAU * orbit_direction)
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	global_position = player.global_position + (current_direction * current_radius)
	
