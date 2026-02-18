extends CanvasLayer

signal upgrade_selected(upgrade: AbilityUpgrade)

@export var upgrade_card_scene: PackedScene
@export var upgrade_card_scene_mobile: PackedScene

var card_container: BoxContainer


func _ready() -> void:
	get_tree().paused = true
	if ViewportHelper.is_portrait() and upgrade_card_scene_mobile != null:
		# Mobile cards are smaller, fit side-by-side in HBox
		card_container = $MarginContainer/CardContainer
		$MarginContainer/CardContainerVBox.visible = false
	elif ViewportHelper.is_portrait():
		# No mobile scene: stack regular cards vertically
		card_container = $MarginContainer/CardContainerVBox
		$MarginContainer/CardContainer.visible = false
	else:
		card_container = $MarginContainer/CardContainer
		$MarginContainer/CardContainerVBox.visible = false
	if ViewportHelper.is_portrait():
		card_container.add_theme_constant_override("separation", 6)


func _get_card_scene() -> PackedScene:
	if ViewportHelper.is_portrait() and upgrade_card_scene_mobile != null:
		return upgrade_card_scene_mobile
	return upgrade_card_scene


func set_ability_upgrades(upgrades: Array[AbilityUpgrade]):
	var upgrade_manager: UpgradeManager = get_parent() as UpgradeManager
	var card_scene := _get_card_scene()
	var delay = 0
	for upgrade in upgrades:
		var card_instance = card_scene.instantiate()
		card_container.add_child(card_instance)
		card_instance.set_ability_upgrade(upgrade, upgrade_manager)
		card_instance.play_in(delay)
		card_instance.selected.connect(on_upgrade_selected.bind(upgrade))
		delay += .2


func on_upgrade_selected(upgrade: AbilityUpgrade):
	upgrade_selected.emit(upgrade)
	$AnimationPlayer.play("out")
	await $AnimationPlayer.animation_finished
	get_tree().paused = false
	queue_free()
