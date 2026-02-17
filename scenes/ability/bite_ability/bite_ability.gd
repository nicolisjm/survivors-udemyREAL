extends Node2D
## Direct damage - controller applies via HurtboxComponent.
## Visual: 4-frame chomp (open -> fast in-between -> closed), with emphasis on open and closed.
## Script-driven timing so frame swaps and scale punch are reliable.
## Emits impact when the mouth reaches the closed pose so damage can be timed to the chomp.

signal impact

var _frames: Array[Texture2D] = []
var _elapsed: float = 0.0
var _impact_emitted: bool = false

# Timing (seconds): hold open, then fast close, then hold closed with scale punch
const TIME_OPEN_END := 0.08
const TIME_MID1 := 0.09
const TIME_MID2 := 0.10
const TIME_CLOSED := 0.10
const TIME_SCALE_BACK := 0.18
const TIME_END := 0.32
const SCALE_PUNCH := 1.25  # 0.5 * 1.25 = 0.625 → 20px (integer) for crisp pixel art
const BASE_SCALE := 0.5

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ZERO
	_frames = [
		preload("res://scenes/ability/bite_ability/bite1.png"),
		preload("res://scenes/ability/bite_ability/bite2.png"),
		preload("res://scenes/ability/bite_ability/bite3.png"),
		preload("res://scenes/ability/bite_ability/bite4.png"),
	]
	if _frames.size() > 0:
		sprite.texture = _frames[0]
	# Tween from 0 to base size with duration 0 so we never show a frame at full size
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(BASE_SCALE, BASE_SCALE), 0.0)


func _process(delta: float) -> void:
	_elapsed += delta

	# Frame: 0 = open, 1–2 = in-between, 3 = closed
	if _frames.is_empty():
		return
	if _elapsed < TIME_OPEN_END:
		_set_frame(0)
	elif _elapsed < TIME_MID1:
		_set_frame(1)
	elif _elapsed < TIME_MID2:
		_set_frame(2)
	else:
		_set_frame(3)

	if _elapsed >= TIME_CLOSED and not _impact_emitted:
		_impact_emitted = true
		impact.emit()

	# Scale punch when mouth closes (base size is 1/4)
	if _elapsed < TIME_CLOSED:
		sprite.scale = Vector2(BASE_SCALE, BASE_SCALE)
	elif _elapsed < TIME_SCALE_BACK:
		sprite.scale = Vector2(BASE_SCALE * SCALE_PUNCH, BASE_SCALE * SCALE_PUNCH)
	else:
		sprite.scale = Vector2(BASE_SCALE, BASE_SCALE)

	if _elapsed >= TIME_END:
		queue_free()


func _set_frame(idx: int) -> void:
	if idx >= 0 and idx < _frames.size():
		sprite.texture = _frames[idx]
