extends CanvasLayer

@export var arena_time_manager: Node
@onready var label = %Label


func _ready() -> void:
	if ViewportHelper.is_portrait():
		label.add_theme_font_size_override("font_size", 32)


func _process(delta: float) -> void:
	if arena_time_manager == null:
		return
	var time_elapsed = arena_time_manager.get_time_elapsed()
	label.text = format_seconds_to_string(time_elapsed)


func format_seconds_to_string(seconds: float):
	var minutes = floor(seconds / 60)
	var remaining_seconds = seconds - (minutes * 60)
	return ("%02d" % minutes) + ":" + ("%02d" % floor(remaining_seconds))
