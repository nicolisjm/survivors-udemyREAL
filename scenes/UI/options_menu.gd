extends CanvasLayer

signal back_pressed

@onready var window_button: Button = $%WindowButton
@onready var sfx_slider: HSlider = %SFXSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var back_button: Button = $%BackButton


const ARENA_SIZE := Vector2(640, 360)


func _ready() -> void:
	_apply_portrait_layout()
	back_button.pressed.connect(on_back_pressed)


func _apply_portrait_layout() -> void:
	var vp_size := ViewportHelper.get_viewport_size()
	var tilemap: Node2D = get_node_or_null("TileMapLayer")
	var margin_container: MarginContainer = $MarginContainer

	if ViewportHelper.is_portrait():
		if tilemap != null:
			var offset_x := -(ARENA_SIZE.x - vp_size.x) / 2.0
			var offset_y := (vp_size.y - ARENA_SIZE.y) / 2.0
			tilemap.position = Vector2(offset_x, offset_y)
		var arena_margin := int((vp_size.y - ARENA_SIZE.y) / 2.0)
		margin_container.add_theme_constant_override("margin_top", arena_margin)
		margin_container.add_theme_constant_override("margin_bottom", arena_margin)
	else:
		if tilemap != null:
			tilemap.position = Vector2.ZERO
		margin_container.remove_theme_constant_override("margin_top")
		margin_container.remove_theme_constant_override("margin_bottom")
	window_button.pressed.connect(on_window_button_pressed)
	sfx_slider.value_changed.connect(on_audio_slider_changed.bind("sfx"))
	music_slider.value_changed.connect(on_audio_slider_changed.bind("music"))
	update_display()
	
	
func update_display():
	window_button.text = "Windowed"
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		window_button.text = "Fullscreen"
	sfx_slider.value = get_bus_volume_percent("sfx")
	music_slider.value = get_bus_volume_percent("music")
	

func get_bus_volume_percent(bus_name: String):
	var bus_index = AudioServer.get_bus_index(bus_name)
	var volume_db = AudioServer.get_bus_volume_db(bus_index)
	return db_to_linear(volume_db)
	
	
func set_bus_volume_percent(bus_name: String, percent: float):
	var bus_index = AudioServer.get_bus_index(bus_name)
	var volume_db = linear_to_db(percent)
	AudioServer.set_bus_volume_db(bus_index, volume_db)


func on_window_button_pressed():
	var mode = DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	update_display()
	
	
func on_audio_slider_changed(value: float, bus_name: String):
	set_bus_volume_percent(bus_name, value)


func on_back_pressed():
	back_pressed.emit()
