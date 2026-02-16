extends Node2D

## Number of segments per bolt segment (more = smoother but more jagged detail).
const ZIGZAG_SEGMENTS = 16
## How far the lightning can jitter sideways (pixels).
const ZIGZAG_JITTER = 2.5
## How long the bolt stays visible, flickdering (seconds).
const BOLT_DURATION = 0.20

var _chain_positions: Array[Vector2] = []
var _elapsed: float = 0.0


func set_chain_positions(positions: Array) -> void:
	_chain_positions.clear()
	for p in positions:
		_chain_positions.append(Vector2(p.x, p.y))
	if _chain_positions.size() < 2:
		return
	# Draw immediately so the bolt appears on the first frame. (Sparks are spawned by HurtboxComponent when apply_damage is called.)
	var points = _build_full_chain_points()
	$GlowLine.points = points
	$Line2D.points = points


func _process(delta: float) -> void:
	if _chain_positions.size() < 2:
		return

	_elapsed += delta
	if _elapsed >= BOLT_DURATION:
		queue_free()
		return

	# Rebuild zigzag every frame so the line "flickers" like real lightning.
	var points = _build_full_chain_points()
	$GlowLine.points = points
	$Line2D.points = points


func _build_full_chain_points() -> PackedVector2Array:
	var points: PackedVector2Array = []
	for i in _chain_positions.size() - 1:
		var a_global = _chain_positions[i]
		var b_global = _chain_positions[i + 1]
		var a_local = to_local(a_global)
		var b_local = to_local(b_global)
		var segment_points = _zigzag_between(a_local, b_local, ZIGZAG_SEGMENTS, ZIGZAG_JITTER)
		# Avoid duplicating the join: only add the first point of the first segment; then all points for later segments skip index 0.
		if i == 0:
			for p in segment_points:
				points.append(p)
		else:
			for j in range(1, segment_points.size()):
				points.append(segment_points[j])
	return points


## Builds a jagged path from A to B with random perpendicular offsets (lightning look).
func _zigzag_between(a: Vector2, b: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var result: PackedVector2Array = []
	var direction = (b - a)
	var length = direction.length()
	if length < 0.01:
		result.append(a)
		return result
	direction /= length
	var perpendicular = Vector2(-direction.y, direction.x)

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var point = a + (b - a) * t
		# Add random offset perpendicular to the segment so the line jitters sideways.
		point += perpendicular * randf_range(-jitter, jitter)
		result.append(point)
	return result
