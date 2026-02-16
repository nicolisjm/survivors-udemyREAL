extends PanelContainer

signal selected

## Fallback icon for generic upgrades (move speed, damage%, etc.) and abilities without an icon.
const _default_icon: Texture2D = preload("res://scenes/game_object/player/player.png")

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var description_label: Label = %DescriptionLabel
@onready var sub_name_label: Label = %SubNameLabel
@onready var icon_texture_rect: TextureRect = %IconTextureRect

var disabled = false

func _ready() -> void:
	gui_input.connect(on_gui_input)
	mouse_entered.connect(on_mouse_entered)
	mouse_exited.connect(on_mouse_exited)


func play_in(delay: float = 0):
	modulate = Color.TRANSPARENT
	await get_tree().create_timer(delay).timeout
	$AnimationPlayer.play("in")
	
	
func play_discard():
	$AnimationPlayer.play("discard")


func set_ability_upgrade(upgrade: AbilityUpgrade, upgrade_manager: UpgradeManager = null):
	description_label.text = upgrade.description

	if upgrade_manager == null:
		name_label.text = upgrade.name
		sub_name_label.text = upgrade.sub_name if upgrade.sub_name != "" else ""
		sub_name_label.visible = upgrade.sub_name != ""
		level_label.visible = false
		icon_texture_rect.texture = _default_icon
		icon_texture_rect.visible = true
		return

	var level_info: Dictionary = upgrade_manager.get_display_level_info(upgrade)
	var display_level: int = mini(level_info.current + 1, level_info.max)
	var level_str: String = "[%d/%d]" % [display_level, level_info.max]
	var main_name: String
	var sub_name: String = ""
	var icon: Texture2D = null

	var path: AbilityUpgradePath = upgrade_manager.get_path_for_ability(upgrade.ability_id)
	if path != null and path.upgrades.size() > 0:
		var first_upgrade: Resource = path.upgrades[0]
		main_name = (first_upgrade as AbilityUpgrade).name
		if upgrade.sub_name != "":
			sub_name = upgrade.sub_name
		elif upgrade.level >= 2:
			sub_name = upgrade.name
		if first_upgrade is Ability:
			icon = (first_upgrade as Ability).icon
	else:
		main_name = upgrade.name
		if upgrade.sub_name != "":
			sub_name = upgrade.sub_name

	name_label.text = main_name
	level_label.text = level_str
	level_label.visible = true
	sub_name_label.text = sub_name
	sub_name_label.visible = sub_name != ""

	icon_texture_rect.texture = icon if icon != null else _default_icon
	icon_texture_rect.visible = true
	
	
func select_card():
	disabled = true
	$AnimationPlayer.play("selected")
	
	for other_card in get_tree().get_nodes_in_group("upgrade_card"):
		if other_card == self:
			continue
		other_card.play_discard()
		await get_tree().create_timer(0.05).timeout
	
	await $AnimationPlayer.animation_finished
	selected.emit()
	
	

func on_gui_input(event: InputEvent):
	if disabled:
		return
	
	if event.is_action_pressed("left_click"):
		select_card()


func on_mouse_entered():
	if disabled:
		return
	if $AnimationPlayer.is_playing():
		return
	$HoverAnimationPlayer.play("hover")
	
	
func on_mouse_exited():
	if disabled:
		return
	
	if $AnimationPlayer.is_playing():
		return
	$HoverAnimationPlayer.play_backwards("hover")
	
	
