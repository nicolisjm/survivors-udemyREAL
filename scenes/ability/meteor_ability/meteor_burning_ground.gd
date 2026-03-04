extends Area2D
## DoT zone left by meteor impact (level 9). Applies small damage in fast ticks to enemies in the area.

## Damage applied each tick.
var damage_per_tick: float = 1.0
## Seconds between damage ticks.
var tick_interval: float = 0.2
## Total lifetime of the zone.
var duration: float = 2.0
## Radius of the zone (set before add_child or in _ready from parent).
var radius: float = 40.0

const HURTBOX_LAYER := 32
const DRAW_POINTS := 32

## Tweak: inner glow alpha (0 = invisible, 1 = opaque). Lower = more subtle.
const VISUAL_INNER_ALPHA := 0.12
## Tweak: outer glow alpha.
const VISUAL_OUTER_ALPHA := 0.07
## Tweak: ring outline alpha.
const VISUAL_RING_ALPHA := 0.08
## Tweak: flicker adds ±this to alpha per frame (0 = no flicker).
const VISUAL_FLICKER_AMOUNT := 0.03
## Tweak: inner circle size as fraction of radius (0.6 = 60%).
const VISUAL_INNER_RADIUS_FRAC := 0.5

var _flicker: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _draw() -> void:
	var inner_alpha: float = clampf(VISUAL_INNER_ALPHA + _flicker * VISUAL_FLICKER_AMOUNT, 0.0, 1.0)
	var outer_alpha: float = clampf(VISUAL_OUTER_ALPHA + _flicker * VISUAL_FLICKER_AMOUNT, 0.0, 1.0)
	var ring_alpha: float = clampf(VISUAL_RING_ALPHA + _flicker * VISUAL_FLICKER_AMOUNT, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * VISUAL_INNER_RADIUS_FRAC, Color(1.0, 0.45, 0.1, inner_alpha))
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.25, 0.05, outer_alpha))
	draw_arc(Vector2.ZERO, radius, 0, TAU, DRAW_POINTS, Color(0.8, 0.2, 0.0, ring_alpha))


func _process(_delta: float) -> void:
	_flicker = randf_range(-1.0, 1.0)
	queue_redraw()


func _ready() -> void:
	collision_layer = 0
	collision_mask = HURTBOX_LAYER
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle: CircleShape2D = (collision_shape.shape as CircleShape2D).duplicate()
		circle.radius = radius
		collision_shape.shape = circle

	# First tick after one interval, then repeat until duration
	var elapsed := tick_interval
	while elapsed <= duration:
		await get_tree().create_timer(tick_interval).timeout
		if not is_instance_valid(self):
			return
		_apply_tick_damage()
		elapsed += tick_interval
	queue_free()


func _apply_tick_damage() -> void:
	for area in get_overlapping_areas():
		if area is HurtboxComponent:
			(area as HurtboxComponent).apply_damage(damage_per_tick, null, 0.0, null, false, null, -12.0, 0.0, 0.0, Color(0.9, 0.3, 0.1))
