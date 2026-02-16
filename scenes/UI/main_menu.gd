extends CanvasLayer

var options_scene = preload("res://scenes/UI/options_menu.tscn")
var highscores_scene = preload("res://scenes/UI/highscores_screen.tscn")

func _ready():
	$%PlayButton.pressed.connect(on_play_pressed)
	$%OptionsButton.pressed.connect(on_options_pressed)
	$%HighscoresButton.pressed.connect(on_highscores_pressed)
	$%QuitButton.pressed.connect(on_quit_pressed)


func on_play_pressed():
	ScreenTransition.transition()
	await ScreenTransition.transitioned_halfway
	$MainMenuMusic.stop()
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	
	
func on_options_pressed():
	var options_instance = options_scene.instantiate()
	add_child(options_instance)
	options_instance.back_pressed.connect(on_options_closed.bind(options_instance))


func on_highscores_pressed():
	var highscores_instance = highscores_scene.instantiate()
	# Add to root so it's a sibling of MainMenu, not a child - ensures correct layer/input order
	get_tree().root.add_child(highscores_instance)
	highscores_instance.back_pressed.connect(on_highscores_closed.bind(highscores_instance))


func on_highscores_closed(highscores_instance: Node):
	highscores_instance.queue_free()


func on_quit_pressed():
	get_tree().quit()
	
	
func on_options_closed(options_instance: Node):
	options_instance.queue_free()
