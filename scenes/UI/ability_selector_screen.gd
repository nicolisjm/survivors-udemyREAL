extends CanvasLayer

signal back_pressed
signal start_pressed

const ICON_SIZE := 28
const SLOT_SIZE := 44
const LOCKED_MODULATE := Color(0.25, 0.25, 0.25, 1.0)
const SELECTED_BORDER_COLOR := Color(0.9, 0.75, 0.2, 1.0)
const SELECTED_BORDER_WIDTH := 3
const NORMAL_BORDER_WIDTH := 1
const ARENA_SIZE := Vector2(640, 360)

var _click_sound: AudioStreamPlayer

@onready var grid_container: GridContainer = %GridContainer
@onready var back_button: Button = %BackButton
@onready var start_button: Button = %StartButton
@onready var selected_label: Label = $MarginContainer/CenterContainer/PanelContainer/MarginContainer/MainVBox/ButtonRow/SelectedLabel
@onready var preview_panel: PanelContainer = $MarginContainer/CenterContainer/PanelContainer/MarginContainer/MainVBox/MainHBox/PreviewPanel
@onready var preview_content: VBoxContainer = $MarginContainer/CenterContainer/PanelContainer/MarginContainer/MainVBox/MainHBox/PreviewPanel/PreviewContent

var _selected_ability_id: String = "sword"
var _slot_buttons: Dictionary = {}  # ability_id -> PanelContainer
var _slot_styles: Dictionary = {}   # ability_id -> StyleBoxFlat
var _ability_paths: Dictionary = {} # ability_id -> AbilityUpgradePath
var _hovered_ability_id: String = ""


func _ready() -> void:
	var click_component = preload("res://scenes/component/random_stream_player_component.tscn").instantiate()
	var stream_list: Array[AudioStream] = []
	stream_list.append(preload("res://assets/audio/sfx/click1.ogg") as AudioStream)
	click_component.streams = stream_list
	add_child(click_component)
	_click_sound = click_component

	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_setup_preview_panel_style()
	_apply_portrait_layout()
	_populate_grid()
	_update_selection_visual()
	_update_preview(_selected_ability_id)
	_update_selected_label()


func _apply_portrait_layout() -> void:
	var panel: PanelContainer = $MarginContainer/CenterContainer/PanelContainer
	var margin_container: MarginContainer = $MarginContainer
	var vp_size := ViewportHelper.get_viewport_size()

	if ViewportHelper.is_portrait():
		grid_container.columns = 3
		panel.custom_minimum_size = Vector2(320, 420)
		preview_panel.custom_minimum_size = Vector2(120, 80)
		# Center UI in arena (middle 360px)
		var arena_margin := int((vp_size.y - ARENA_SIZE.y) / 2.0)
		margin_container.add_theme_constant_override("margin_top", arena_margin)
		margin_container.add_theme_constant_override("margin_bottom", arena_margin)
	else:
		grid_container.columns = 4
		panel.custom_minimum_size = Vector2(300, 300)
		preview_panel.custom_minimum_size = Vector2(100, 0)
		margin_container.remove_theme_constant_override("margin_top")
		margin_container.remove_theme_constant_override("margin_bottom")


func _setup_preview_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.5, 1)
	style.set_content_margin_all(8)
	preview_panel.add_theme_stylebox_override("panel", style)


func _populate_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_slot_buttons.clear()
	_slot_styles.clear()
	_ability_paths.clear()

	var paths: Array = StartingAbilityRegistry.get_selectable_ability_paths()
	var unlocked: Array = StartingAbilityRegistry.get_unlocked_ability_ids()

	for path in paths:
		if path == null:
			continue
		var ability_id: String = path.ability_id
		var unlocked_slot: bool = ability_id in unlocked
		_ability_paths[ability_id] = path

		var first_upgrade: AbilityUpgrade = path.upgrades[0] as AbilityUpgrade if path.upgrades.size() > 0 else null
		var icon: Texture2D = null
		if first_upgrade is Ability:
			icon = (first_upgrade as Ability).icon

		var slot := _create_slot(ability_id, icon, unlocked_slot)
		grid_container.add_child(slot)
		_slot_buttons[ability_id] = slot


func _create_slot(ability_id: String, icon: Texture2D, unlocked: bool) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
	style.border_width_left = NORMAL_BORDER_WIDTH
	style.border_width_top = NORMAL_BORDER_WIDTH
	style.border_width_right = NORMAL_BORDER_WIDTH
	style.border_width_bottom = NORMAL_BORDER_WIDTH
	style.border_color = Color(0.5, 0.5, 0.6, 1)
	style.set_content_margin_all(4)
	_slot_styles[ability_id] = style

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var btn := Button.new()
	btn.flat = true
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var empty_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("disabled", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.clip_contents = true
	tex_rect.texture = icon
	center.add_child(tex_rect)
	btn.add_child(center)
	panel.add_child(btn)

	if not unlocked:
		btn.disabled = true
		panel.modulate = LOCKED_MODULATE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		btn.pressed.connect(_on_slot_pressed.bind(ability_id))
		btn.mouse_entered.connect(_on_slot_hover_entered.bind(ability_id))
		btn.mouse_exited.connect(_on_slot_hover_exited.bind(ability_id))

	panel.set_meta("_btn", btn)
	return panel


func _on_slot_pressed(ability_id: String) -> void:
	_click_sound.play_random()
	_selected_ability_id = ability_id
	_update_selection_visual()
	_update_preview(ability_id)
	_update_selected_label()


func _on_slot_hover_entered(ability_id: String) -> void:
	_hovered_ability_id = ability_id
	_update_preview(ability_id)


func _on_slot_hover_exited(ability_id: String) -> void:
	if _hovered_ability_id == ability_id:
		_hovered_ability_id = ""
		_update_preview(_selected_ability_id)


func _update_preview(ability_id: String) -> void:
	for child in preview_content.get_children():
		child.queue_free()

	if ability_id.is_empty():
		preview_panel.visible = false
		return

	var path: AbilityUpgradePath = _ability_paths.get(ability_id, null)
	if path == null or path.upgrades.size() == 0:
		preview_panel.visible = false
		return

	var first: AbilityUpgrade = path.upgrades[0] as AbilityUpgrade
	if first == null:
		preview_panel.visible = false
		return

	preview_panel.visible = true

	var name_lbl := Label.new()
	name_lbl.text = first.name
	name_lbl.theme_type_variation = &"BlueOutlineLabel"
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_content.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = first.description
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_content.add_child(desc_lbl)


func _update_selected_label() -> void:
	var name_str: String = StartingAbilityRegistry.get_ability_display_name(_selected_ability_id)
	selected_label.text = "Selected: %s" % name_str


func _update_selection_visual() -> void:
	for aid in _slot_buttons:
		var panel: PanelContainer = _slot_buttons[aid]
		var btn: Button = panel.get_meta("_btn", null)
		var style: StyleBoxFlat = _slot_styles.get(aid, null)

		if btn != null:
			btn.button_pressed = (aid == _selected_ability_id)

		if btn != null and btn.disabled:
			panel.modulate = LOCKED_MODULATE
		else:
			panel.modulate = Color.WHITE

		if style != null:
			var is_selected: bool = aid == _selected_ability_id
			style.border_width_left = SELECTED_BORDER_WIDTH if is_selected else NORMAL_BORDER_WIDTH
			style.border_width_top = SELECTED_BORDER_WIDTH if is_selected else NORMAL_BORDER_WIDTH
			style.border_width_right = SELECTED_BORDER_WIDTH if is_selected else NORMAL_BORDER_WIDTH
			style.border_width_bottom = SELECTED_BORDER_WIDTH if is_selected else NORMAL_BORDER_WIDTH
			style.border_color = SELECTED_BORDER_COLOR if is_selected else Color(0.5, 0.5, 0.6, 1)


func _on_back_pressed() -> void:
	back_pressed.emit()


func _on_start_pressed() -> void:
	StartingAbilityRegistry.selected_starting_ability_id = _selected_ability_id
	start_pressed.emit()
