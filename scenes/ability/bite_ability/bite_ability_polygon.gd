extends Node2D
## Alternative bite visual: Polygon2D mouth with sharp fang triangles that close for a satisfying chomp.
## Same timing and impact signal as bite_ability.gd so the controller can use either scene.
## Pixel-y: points are rounded to integers; use texture_filter / draw style for crisp look.

signal impact

var _elapsed: float = 0.0
var _impact_emitted: bool = false

# Match original bite timing
const TIME_OPEN_END := 0.08
const TIME_MID1 := 0.09
const TIME_MID2 := 0.10
const TIME_CLOSED := 0.10
const TIME_SCALE_BACK := 0.18
const TIME_END := 0.32
const SCALE_PUNCH := 1.25
const BASE_SCALE := 1

# Mouth geometry (local space, y down): jaw "height", fang tip y when open, center line when closed
const JAW_Y := 5
const TIP_OPEN_Y := 2
const HALF_WIDTH := 7

@onready var upper_teeth: Polygon2D = $UpperTeeth
@onready var lower_teeth: Polygon2D = $LowerTeeth
@onready var upper_outline: Line2D = $UpperOutline
@onready var lower_outline: Line2D = $LowerOutline


func _ready() -> void:
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.0)
	_update_mouth(0.0)


func _process(delta: float) -> void:
	_elapsed += delta

	# Close curve: hold open until TIME_OPEN_END, then snap closed by TIME_CLOSED (ease-in = satisfying chomp)
	var t_close: float = 0.0
	if _elapsed > TIME_OPEN_END:
		var close_duration: float = TIME_CLOSED - TIME_OPEN_END
		var t_linear: float = clampf((_elapsed - TIME_OPEN_END) / close_duration, 0.0, 1.0)
		t_close = ease(t_linear, 2.0)  # ease-in: fast at end = snappy close
	_update_mouth(t_close)

	if _elapsed >= TIME_CLOSED and not _impact_emitted:
		_impact_emitted = true
		impact.emit()

	# Scale punch when closed
	if _elapsed < TIME_CLOSED:
		scale = Vector2(BASE_SCALE, BASE_SCALE)
	elif _elapsed < TIME_SCALE_BACK:
		scale = Vector2(BASE_SCALE * SCALE_PUNCH, BASE_SCALE * SCALE_PUNCH)
	else:
		scale = Vector2(BASE_SCALE, BASE_SCALE)

	if _elapsed >= TIME_END:
		queue_free()


## t: 0 = mouth open (jaws apart), 1 = mouth closed (jaws meet at center)
func _update_mouth(t: float) -> void:
	# Upper jaw: 3 fangs, tips move from -TIP_OPEN_Y down to 0 (meet center)
	var upper_tip_y: float = lerpf(-TIP_OPEN_Y, 0.0, t)
	# Lower jaw: 3 fangs, tips move from TIP_OPEN_Y up to 0 (meet center)
	var lower_tip_y: float = lerpf(TIP_OPEN_Y, 0.0, t)

	# Upper teeth: one polygon, 3 fangs pointing down. Base at y = -JAW_Y, tips at upper_tip_y
	var upper_pts: PackedVector2Array = []
	upper_pts.append(Vector2(-HALF_WIDTH, -JAW_Y))
	upper_pts.append(Vector2(-4, upper_tip_y))
	upper_pts.append(Vector2(-2, -JAW_Y))
	upper_pts.append(Vector2(0, upper_tip_y))
	upper_pts.append(Vector2(2, -JAW_Y))
	upper_pts.append(Vector2(4, upper_tip_y))
	upper_pts.append(Vector2(HALF_WIDTH, -JAW_Y))

	# Lower teeth: 3 fangs pointing up. Base at y = JAW_Y, tips at lower_tip_y
	var lower_pts: PackedVector2Array = []
	lower_pts.append(Vector2(HALF_WIDTH, JAW_Y))
	lower_pts.append(Vector2(4, lower_tip_y))
	lower_pts.append(Vector2(2, JAW_Y))
	lower_pts.append(Vector2(0, lower_tip_y))
	lower_pts.append(Vector2(-2, JAW_Y))
	lower_pts.append(Vector2(-4, lower_tip_y))
	lower_pts.append(Vector2(-HALF_WIDTH, JAW_Y))

	# Pixel-y: snap to integers
	for i in upper_pts.size():
		upper_pts[i] = Vector2(int(round(upper_pts[i].x)), int(round(upper_pts[i].y)))
	for i in lower_pts.size():
		lower_pts[i] = Vector2(int(round(lower_pts[i].x)), int(round(lower_pts[i].y)))

	upper_teeth.polygon = upper_pts
	lower_teeth.polygon = lower_pts

	# Closed outlines
	var upper_outline_pts := upper_pts.duplicate()
	upper_outline_pts.append(upper_pts[0])
	upper_outline.points = upper_outline_pts
	var lower_outline_pts := lower_pts.duplicate()
	lower_outline_pts.append(lower_pts[0])
	lower_outline.points = lower_outline_pts
