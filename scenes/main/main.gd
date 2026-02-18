extends Node

@export var end_screen_scene: PackedScene

const ARENA_MUSIC_PATHS := [
	"res://assets/audio/arenaMusic/Alchemist.mp3",
	"res://assets/audio/arenaMusic/Aloe Lite.mp3",
	"res://assets/audio/arenaMusic/Everything Everything.mp3",
	"res://assets/audio/arenaMusic/Faster.mp3",
	"res://assets/audio/arenaMusic/Nomu.mp3",
	"res://assets/audio/arenaMusic/Pox.mp3",
	"res://assets/audio/arenaMusic/Slingshot.mp3",
	"res://assets/audio/arenaMusic/Tell Me You Know.mp3",
	"res://assets/audio/arenaMusic/Witches.mp3",
]

var pause_menu_scene = preload("res://scenes/UI/pause_menu.tscn")
var _arena_playlist: ShufflePlaylistComponent


func _ready() -> void:
	$%Player.health_component.died.connect(on_player_died)
	_setup_arena_music()


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("pause"):
		add_child(pause_menu_scene.instantiate())
		get_tree().root.set_input_as_handled()


func _setup_arena_music() -> void:
	var streams: Array[AudioStream] = []
	for path in ARENA_MUSIC_PATHS:
		var s = load(path) as AudioStream
		if s:
			streams.append(s)
	if streams.is_empty():
		return
	_arena_playlist = preload("res://scenes/component/shuffle_playlist_component.tscn").instantiate() as ShufflePlaylistComponent
	add_child(_arena_playlist)
	_arena_playlist.streams = streams
	_arena_playlist.start_playlist()


func on_player_died(_killer_source: Variant = null) -> void:
	if _arena_playlist:
		_arena_playlist.stop_playlist()
	var time_survived: float = $ArenaTimeManager.get_time_elapsed()
	var total_exp: float = $ExperienceManager.get_total_experience_collected()
	var ability_names: Array = []
	var upgrade_manager: UpgradeManager = get_node_or_null("UpgradeManager") as UpgradeManager
	if upgrade_manager != null:
		for item in upgrade_manager.get_acquired_main_abilities():
			var aid: String = item.get("ability_id", "")
			if aid != "":
				ability_names.append(StartingAbilityRegistry.get_ability_display_name(aid))
				StartingAbilityRegistry.unlock_ability(aid)
	var end_screen_instance = end_screen_scene.instantiate()
	add_child(end_screen_instance)
	end_screen_instance.set_game_over(time_survived, total_exp, ability_names)
