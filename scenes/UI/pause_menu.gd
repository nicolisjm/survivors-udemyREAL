extends CanvasLayer

@onready var panel_container: PanelContainer = %PanelContainer
@export var end_screen_scene: PackedScene

var options_menu_scene = preload("res://scenes/UI/options_menu.tscn")
var is_closing


func _ready():
	get_tree().paused = true
	panel_container.pivot_offset = (panel_container.size / 2)
	
	$%ResumeButton.pressed.connect(on_resume_pressed)
	$%OptionsButton.pressed.connect(on_options_pressed)
	$%QuitButton.pressed.connect(on_quit_pressed)
	
	$AnimationPlayer.play("default")
	
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ZERO, 0)
	tween.tween_property(panel_container, "scale", Vector2.ONE, .3)\
	.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("pause"):
		close()
		get_tree().root.set_input_as_handled()
		
func close():
	if is_closing:
		return
	is_closing = true
	
	$AnimationPlayer.play_backwards("default")
	
	var tween = create_tween()
	tween.tween_property(panel_container, "scale", Vector2.ONE, 0)
	tween.tween_property(panel_container, "scale", Vector2.ZERO, .3)\
	.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	
	await tween.finished
	get_tree().paused = false
	queue_free()


func on_resume_pressed():
	close()
	
	
func on_options_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	var options_menu_instance = options_menu_scene.instantiate()
	add_child(options_menu_instance)
	options_menu_instance.back_pressed.connect(on_options_back_pressed.bind(options_menu_instance))
	
	
func on_quit_pressed():
	if is_closing:
		return
	is_closing = true
	var player: Node = get_tree().get_first_node_in_group("player")
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent if player else null
	if health != null:
		health.damage(9999, null)
	get_tree().paused = false
	queue_free()
	
	
func on_options_back_pressed(options_menu: Node):
	options_menu.queue_free()
