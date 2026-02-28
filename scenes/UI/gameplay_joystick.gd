extends CanvasLayer

## Wraps the Virtual Joystick addon. Visible only during active gameplay (not paused).
## Uses move_left, move_right, move_up, move_down for player movement.
## Size and visibility (Touch vs Joystick) from GameSettings.

@onready var joystick: VirtualJoystick = $"Virtual Joystick"
@onready var _game_settings: Node = get_node("/root/GameSettings")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	joystick.action_left = "move_left"
	joystick.action_right = "move_right"
	joystick.action_up = "move_up"
	joystick.action_down = "move_down"
	joystick.use_input_actions = true
	_game_settings.settings_changed.connect(_apply_settings)
	call_deferred("_apply_settings")


func _apply_settings() -> void:
	var visual_scale: float = _game_settings.get_joystick_visual_scale()
	var clampzone: float = _game_settings.get_joystick_clampzone()
	joystick.clampzone_size = clampzone
	var base := joystick.get_node("Base") as TextureRect
	base.scale = Vector2(visual_scale, visual_scale)
	base.pivot_offset = Vector2(100, 100)


func _process(_delta: float) -> void:
	var use_joystick: bool = (_game_settings.get_input_mode() == "joystick") and (not get_tree().paused)
	visible = use_joystick
	## When in touch mode, disable joystick input so touch events reach the player as mouse (left_click + position).
	joystick.process_mode = Node.PROCESS_MODE_ALWAYS if use_joystick else Node.PROCESS_MODE_DISABLED
