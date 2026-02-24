extends CanvasLayer

signal back_pressed

@onready var window_button: Button = $%WindowButton
@onready var window_option_container: VBoxContainer = $%WindowOptionContainer
@onready var joystick_size_option: OptionButton = $%JoystickSizeOption
@onready var input_mode_option: OptionButton = $%InputModeOption
@onready var joystick_size_option_container: VBoxContainer = $%JoystickSizeOptionContainer
@onready var input_mode_option_container: VBoxContainer = $%InputModeOptionContainer
@onready var sfx_slider: HSlider = %SFXSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var back_button: Button = $%BackButton
@onready var _game_settings: Node = get_node("/root/GameSettings")


const ARENA_SIZE := Vector2(640, 360)
const JOYSTICK_SIZE_KEYS := ["small", "medium", "large"]
const JOYSTICK_SIZE_LABELS := ["Small", "Medium", "Large"]
const INPUT_MODE_KEYS := ["touch", "joystick"]
const INPUT_MODE_LABELS := ["Touch", "Joystick"]


func _ready() -> void:
	_apply_portrait_layout()
	back_button.pressed.connect(on_back_pressed)
	_setup_mobile_options()
	sfx_slider.value_changed.connect(on_audio_slider_changed.bind("sfx"))
	music_slider.value_changed.connect(on_audio_slider_changed.bind("music"))
	update_display()


func _setup_mobile_options() -> void:
	if _game_settings.is_mobile():
		window_option_container.visible = false
		joystick_size_option_container.visible = true
		input_mode_option_container.visible = true
		joystick_size_option.clear()
		for label in JOYSTICK_SIZE_LABELS:
			joystick_size_option.add_item(label)
		input_mode_option.clear()
		for label in INPUT_MODE_LABELS:
			input_mode_option.add_item(label)
		joystick_size_option.item_selected.connect(_on_joystick_size_selected)
		input_mode_option.item_selected.connect(_on_input_mode_selected)
		update_mobile_display()
	else:
		window_option_container.visible = true
		joystick_size_option_container.visible = false
		input_mode_option_container.visible = false
		window_button.pressed.connect(on_window_button_pressed)


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
	
	
func update_display() -> void:
	if not _game_settings.is_mobile():
		window_button.text = "Windowed"
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_button.text = "Fullscreen"
	sfx_slider.value = get_bus_volume_percent("sfx")
	music_slider.value = get_bus_volume_percent("music")


func update_mobile_display() -> void:
	var size_idx := JOYSTICK_SIZE_KEYS.find(_game_settings.get_joystick_size())
	if size_idx >= 0:
		joystick_size_option.selected = size_idx
	var mode_idx := INPUT_MODE_KEYS.find(_game_settings.get_input_mode())
	if mode_idx >= 0:
		input_mode_option.selected = mode_idx


func _on_joystick_size_selected(index: int) -> void:
	if index >= 0 and index < JOYSTICK_SIZE_KEYS.size():
		_game_settings.set_joystick_size(JOYSTICK_SIZE_KEYS[index])


func _on_input_mode_selected(index: int) -> void:
	if index >= 0 and index < INPUT_MODE_KEYS.size():
		_game_settings.set_input_mode(INPUT_MODE_KEYS[index])
	

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
