extends Node2D
## Displays a damage number (or other text) that floats up and fades.
## is_crit: if true, text is shown in gold with "!" appended (e.g. "10" -> "10!"); reusable for any ability crit.

const CRIT_COLOR := Color(1.0, 0.80, 0.2, 1.0)


func _ready() -> void:
	pass


func start(text: String, is_crit: bool = false, custom_color: Variant = null) -> void:
	if custom_color != null:
		$Label.text = text
		$Label.add_theme_color_override("font_color", custom_color)
	elif is_crit:
		$Label.text = text + " !"
		$Label.add_theme_color_override("font_color", CRIT_COLOR)
	else:
		$Label.text = text
		$Label.remove_theme_color_override("font_color")
	scale = Vector2.ZERO
	
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "global_position", global_position + (Vector2.UP * 16), .3)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain()
	
	tween.tween_property(self, "global_position", global_position + (Vector2.UP * 72), .6)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, .6)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.chain()
	
	
	#Different than course, idk why his works but mine didn't
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2.ONE * 1.5, .2)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	scale_tween.tween_property(self, "scale", Vector2.ZERO, .2)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC).set_delay(.3)
	
	scale_tween.tween_callback(queue_free)
	
	
	
