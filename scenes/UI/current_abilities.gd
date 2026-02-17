extends CanvasLayer
## Shows the player's acquired main abilities (up to 3): icon + level in each panel.
## Refreshes when any ability upgrade is added.

const DEFAULT_ICON: Texture2D = preload("res://scenes/game_object/player/player.png")

@onready var _panel_1: PanelContainer = $MarginContainer/HBoxContainer/PanelContainer
@onready var _panel_2: PanelContainer = $MarginContainer/HBoxContainer/PanelContainer2
@onready var _panel_3: PanelContainer = $MarginContainer/HBoxContainer/PanelContainer3


func _ready() -> void:
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	# Defer so UpgradeManager has run _ready() and set the starting ability (e.g. sword level 1).
	call_deferred("_refresh")


func _on_ability_upgrade_added(_upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	_refresh()


func _refresh() -> void:
	var manager = get_tree().get_first_node_in_group("upgrade_manager")
	if not manager or not manager.has_method("get_acquired_main_abilities"):
		_clear_all_panels()
		return

	var acquired: Array = manager.get_acquired_main_abilities()
	var panels: Array[PanelContainer] = [_panel_1, _panel_2, _panel_3]

	for i in panels.size():
		_clear_children(panels[i])
		if i < acquired.size():
			_build_slot(panels[i], acquired[i])


func _clear_all_panels() -> void:
	_clear_children(_panel_1)
	_clear_children(_panel_2)
	_clear_children(_panel_3)


func _clear_children(panel: PanelContainer) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()


func _build_slot(panel: PanelContainer, data: Dictionary) -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(28, 28)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.texture = data.get("icon") if data.get("icon") else DEFAULT_ICON

	var level_label := Label.new()
	level_label.theme_type_variation = &"BlueOutlineLabel"
	level_label.add_theme_constant_override("shadow_outline_size", 1)
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.text = "Lv.%d" % data.get("level", 1)

	vbox.add_child(icon_rect)
	vbox.add_child(level_label)
	panel.add_child(vbox)
