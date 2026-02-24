@tool
extends Node

## Add this script to any node in a scene, then run that scene (F5 or F6).
## On _ready it captures the ball lightning as 16x16 PNG and prints the path.

const OUTPUT_PATH := "res://scenes/ability/ball_lightning_ability/ball_lightning_icon_16.png"

func _ready() -> void:
	call_deferred("_do_capture")

func _do_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var err := await _capture()
	if err == OK:
		print("Saved ball lightning 16x16 icon to: ", OUTPUT_PATH)
	else:
		push_error("Failed to save: %s" % error_string(err))

func _capture() -> int:
	var size := 16
	var scene := load("res://scenes/ability/ball_lightning_ability/ball_lightning_ability.tscn") as PackedScene
	var ball := scene.instantiate() as Node2D
	ball.set_script(null)
	# BallColorRect center is at (0, -7) locally; offset to center in viewport
	ball.position = Vector2(size / 2.0, size / 2.0 + 7.0)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(size, size)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(ball)

	get_tree().root.add_child(viewport)
	await get_tree().process_frame
	await get_tree().process_frame

	var tex: ViewportTexture = viewport.get_texture()
	var img: Image = tex.get_image()
	get_tree().root.remove_child(viewport)
	viewport.queue_free()

	return img.save_png(OUTPUT_PATH)
