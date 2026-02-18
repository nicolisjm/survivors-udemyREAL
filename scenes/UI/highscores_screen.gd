extends CanvasLayer

signal back_pressed

@onready var entries_container: VBoxContainer = %EntriesContainer
@onready var back_button: Button = $%BackButton

const COLUMN_SEPARATION := 8
const ENTRY_FONT_SIZE := 16
const ARENA_SIZE := Vector2(640, 360)


func _ready() -> void:
	_apply_portrait_layout()
	back_button.text = "Back"


func _apply_portrait_layout() -> void:
	var margin_container: MarginContainer = $MarginContainer
	var vp_size := ViewportHelper.get_viewport_size()
	if ViewportHelper.is_portrait():
		var arena_margin := int((vp_size.y - ARENA_SIZE.y) / 2.0)
		margin_container.add_theme_constant_override("margin_top", arena_margin)
		margin_container.add_theme_constant_override("margin_bottom", arena_margin)
	else:
		margin_container.remove_theme_constant_override("margin_top")
		margin_container.remove_theme_constant_override("margin_bottom")
	back_button.pressed.connect(on_back_pressed)
	_populate_highscores()


func _populate_highscores() -> void:
	for child in entries_container.get_children():
		child.queue_free()

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", COLUMN_SEPARATION)
	grid.add_theme_constant_override("v_separation", 4)
	entries_container.add_child(grid)

	_add_grid_header(grid)
	var entries: Array = HighscoresManager.get_highscores()
	for entry in entries:
		_add_grid_entry_row(grid, entry)


func _add_grid_header(grid: GridContainer) -> void:
	grid.add_child(_make_column_label("NAME", HORIZONTAL_ALIGNMENT_LEFT))
	grid.add_child(_make_column_label("TIME", HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(_make_column_label("POINTS", HORIZONTAL_ALIGNMENT_RIGHT))
	grid.add_child(_make_column_label("ABILITIES", HORIZONTAL_ALIGNMENT_LEFT))


func _add_grid_entry_row(grid: GridContainer, entry: Dictionary) -> void:
	var initials: String = entry.get("initials", "---")
	var time_survived: float = entry.get("time_survived", 0.0)
	var exp_collected: int = entry.get("exp_collected", 0)
	var ability_names: Array = entry.get("ability_names", [])
	var time_str := _format_seconds(time_survived)
	var abilities_str: String = ", ".join(ability_names) if ability_names.size() > 0 else "—"
	grid.add_child(_make_column_label(initials, HORIZONTAL_ALIGNMENT_LEFT))
	grid.add_child(_make_column_label(time_str, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(_make_column_label(str(exp_collected), HORIZONTAL_ALIGNMENT_RIGHT))
	grid.add_child(_make_column_label(abilities_str, HORIZONTAL_ALIGNMENT_LEFT))


func _make_column_label(text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BlueOutlineLabel"
	label.add_theme_font_size_override("font_size", ENTRY_FONT_SIZE)
	label.horizontal_alignment = alignment
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _format_seconds(seconds: float) -> String:
	var minutes := int(seconds / 60)
	var secs := int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]


func on_back_pressed() -> void:
	back_pressed.emit()
