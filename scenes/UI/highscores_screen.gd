extends CanvasLayer

signal back_pressed

@onready var entries_container: VBoxContainer = %EntriesContainer
@onready var back_button: Button = $%BackButton

const COLUMN_SEPARATION := 8
const COLUMN_MIN_WIDTH_NAME := 48
const COLUMN_MIN_WIDTH_TIME := 48
const COLUMN_MIN_WIDTH_POINTS := 48
const ENTRY_FONT_SIZE := 16


func _ready() -> void:
	back_button.text = "Back"
	back_button.pressed.connect(on_back_pressed)
	_populate_highscores()


func _populate_highscores() -> void:
	for child in entries_container.get_children():
		child.queue_free()

	_add_header_row()
	var entries: Array = HighscoresManager.get_highscores()
	for i in entries.size():
		_add_entry_row(entries[i])


func _add_header_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", COLUMN_SEPARATION)
	row.add_child(_make_column_label("NAME", COLUMN_MIN_WIDTH_NAME, HORIZONTAL_ALIGNMENT_LEFT, true))
	row.add_child(_make_column_label("TIME", COLUMN_MIN_WIDTH_TIME, HORIZONTAL_ALIGNMENT_CENTER, false))
	row.add_child(_make_column_label("POINTS", COLUMN_MIN_WIDTH_POINTS, HORIZONTAL_ALIGNMENT_RIGHT, true))
	entries_container.add_child(row)


func _add_entry_row(entry: Dictionary) -> void:
	var initials: String = entry.get("initials", "---")
	var time_survived: float = entry.get("time_survived", 0.0)
	var exp_collected: int = entry.get("exp_collected", 0)
	var time_str := _format_seconds(time_survived)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", COLUMN_SEPARATION)
	row.add_child(_make_column_label(initials, COLUMN_MIN_WIDTH_NAME, HORIZONTAL_ALIGNMENT_LEFT, true))
	row.add_child(_make_column_label(time_str, COLUMN_MIN_WIDTH_TIME, HORIZONTAL_ALIGNMENT_CENTER, false))
	row.add_child(_make_column_label(str(exp_collected), COLUMN_MIN_WIDTH_POINTS, HORIZONTAL_ALIGNMENT_RIGHT, true))
	entries_container.add_child(row)


func _make_column_label(text: String, min_width: int, alignment: HorizontalAlignment, expand: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BlueOutlineLabel"
	label.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	label.custom_minimum_size.x = min_width
	label.horizontal_alignment = alignment
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _format_seconds(seconds: float) -> String:
	var minutes := int(seconds / 60)
	var secs := int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]


func on_back_pressed() -> void:
	back_pressed.emit()
