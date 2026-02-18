extends Node
## Provides viewport size and orientation helpers for responsive UI and gameplay.
## Use this to adapt layouts for portrait (mobile) vs landscape (PC).


func get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func is_portrait() -> bool:
	var size := get_viewport_size()
	return size.y > size.x
