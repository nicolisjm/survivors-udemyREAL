extends CanvasLayer

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

@onready var panel_container: PanelContainer = %PanelContainer
@onready var initials_panel: VBoxContainer = %InitialsEntryPanel
@onready var slot_buttons: Array[Button] = [%Slot0Button, %Slot1Button, %Slot2Button]

var _pending_time_survived: float = 0.0
var _pending_exp: float = 0.0
var _pending_ability_names: Array = []
var _slot_letter_indices: Array[int] = [0, 0, 0]


func _ready() -> void:
	panel_container.pivot_offset = panel_container.size / 2
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0)
	tween.tween_property(panel_container, "scale", Vector2.ONE, .3)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	get_tree().paused = true
	$%RestartButton.pressed.connect(on_restart_button_pressed)
	$%QuitButton.pressed.connect(on_quit_button_pressed)
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_on_slot_clicked.bind(i))
	$%InitialsConfirmButton.pressed.connect(_on_initials_confirm)


func set_game_over(time_survived_seconds: float, exp_collected: float, ability_names: Array = []) -> void:
	$%TitleLabel.text = "Defeat"
	$%DescriptionLabel.text = "You Lost!"
	$%StatsLabel.text = "Time survived: %s\nExperience collected: %d" % [_format_seconds(time_survived_seconds), int(exp_collected)]
	_pending_ability_names = ability_names.duplicate()
	play_jingle(true)
	if HighscoresManager.would_be_highscore(time_survived_seconds):
		_pending_time_survived = time_survived_seconds
		_pending_exp = exp_collected
		_start_initials_entry()
	else:
		$%NewHighscoreLabel.visible = false
		initials_panel.visible = false


func _start_initials_entry() -> void:
	_slot_letter_indices = [0, 0, 0]
	$%NewHighscoreLabel.visible = false
	initials_panel.visible = true
	_update_initials_display()


func _update_initials_display() -> void:
	for i in 3:
		slot_buttons[i].text = LETTERS[_slot_letter_indices[i]]


func _on_slot_clicked(slot_index: int) -> void:
	_slot_letter_indices[slot_index] = (_slot_letter_indices[slot_index] + 1) % LETTERS.length()
	_update_initials_display()


func _on_initials_confirm() -> void:
	var initials: String = ""
	for i in 3:
		initials += LETTERS[_slot_letter_indices[i]]
	HighscoresManager.submit_score(_pending_time_survived, _pending_exp, initials, _pending_ability_names)
	initials_panel.visible = false
	$%NewHighscoreLabel.visible = true


func _format_seconds(seconds: float) -> String:
	var minutes := int(seconds / 60)
	var secs := int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]


func on_restart_button_pressed() -> void:
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	
	
func on_quit_button_pressed() -> void:
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/UI/main_menu.tscn")


func play_jingle(defeat: bool = false):
	if defeat:
		$DefeatStreamPlayer.play()
	else:
		$VictoryStreamPlayer.play()
