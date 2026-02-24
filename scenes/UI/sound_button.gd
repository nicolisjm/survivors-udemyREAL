extends Button


func _ready() -> void:
	pressed.connect(on_pressed)


func on_pressed() -> void:
	# Play from root so sound continues when this button/screen is freed (e.g. Back button)
	var comp = $RandomStreamPlayerComponent
	if not comp.streams or comp.streams.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"sfx"
	player.stream = comp.streams.pick_random()
	player.pitch_scale = randf_range(0.9, 1.1)
	player.finished.connect(player.queue_free)
	get_tree().root.add_child(player)
	player.play()
