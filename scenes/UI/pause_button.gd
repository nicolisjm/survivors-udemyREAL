extends CanvasLayer

## Opens the pause menu on press. Works with mouse (PC) and touch (mobile).

var _pause_menu_scene := preload("res://scenes/UI/pause_menu.tscn")

@onready var _button: Button = $MarginContainer/Button


func _ready() -> void:
	_button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if get_tree().paused:
		return
	get_tree().current_scene.add_child(_pause_menu_scene.instantiate())
