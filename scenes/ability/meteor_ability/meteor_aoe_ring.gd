extends Node2D
## Expanding ring drawn at meteor impact. Scale and fade tween for a natural AOE wave look.

var radius: float = 40.0

const RING_POINTS := 64
const EXPAND_DURATION := 0.4
## Start scale factor (0 = center, 1 = full radius).
const START_SCALE := 0.15
## Outer ring is slightly larger and more transparent.
const OUTER_RING_SCALE := 1.15


func run() -> void:
	scale = Vector2(radius * START_SCALE, radius * START_SCALE)
	modulate = Color(1, 1, 1, 0.85)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(radius, radius), EXPAND_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, EXPAND_DURATION).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)


func _draw() -> void:
	# Draw at unit radius; node scale makes it aoe_radius in world space
	var color_inner: Color = Color(1.0, 0.55, 0.2, modulate.a)
	var color_outer: Color = Color(1.0, 0.4, 0.1, modulate.a * 0.5)
	draw_arc(Vector2.ZERO, 1.0, 0, TAU, RING_POINTS, color_inner)
	draw_arc(Vector2.ZERO, OUTER_RING_SCALE, 0, TAU, RING_POINTS, color_outer)
