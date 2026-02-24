extends Node

## Persists mobile control settings (joystick size, input mode).
## Uses ConfigFile at user://game_settings.cfg

signal settings_changed

const SAVE_PATH := "user://game_settings.cfg"

const JOYSTICK_PRESETS := {
	"small": {"visual_scale": 0.08, "clampzone_size": 8},
	"medium": {"visual_scale": 0.12, "clampzone_size": 12},
	"large": {"visual_scale": 0.16, "clampzone_size": 16},
}

var _joystick_size: String = "small"
var _input_mode: String = "joystick"


func _ready() -> void:
	_load()


## True when running on a mobile export or when viewport is portrait (mobile-sized), e.g. for testing on PC.
func is_mobile() -> bool:
	return OS.has_feature("mobile") or ViewportHelper.is_portrait()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	_joystick_size = cfg.get_value("mobile", "joystick_size", "small")
	_input_mode = cfg.get_value("mobile", "input_mode", "joystick")


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("mobile", "joystick_size", _joystick_size)
	cfg.set_value("mobile", "input_mode", _input_mode)
	cfg.save(SAVE_PATH)
	settings_changed.emit()


func get_joystick_visual_scale() -> float:
	return JOYSTICK_PRESETS.get(_joystick_size, JOYSTICK_PRESETS["medium"])["visual_scale"]


func get_joystick_clampzone() -> float:
	return JOYSTICK_PRESETS.get(_joystick_size, JOYSTICK_PRESETS["medium"])["clampzone_size"]


func get_joystick_size() -> String:
	return _joystick_size


func get_input_mode() -> String:
	return _input_mode


func set_joystick_size(value: String) -> void:
	if value in JOYSTICK_PRESETS:
		_joystick_size = value
		_save()


func set_input_mode(value: String) -> void:
	if value in ["touch", "joystick"]:
		_input_mode = value
		_save()
