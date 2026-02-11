class_name ShufflePlaylistComponent
extends Node

## Plays a shuffled playlist of streams in order; reshuffles and repeats when the list ends.
## Call start_playlist() to begin, stop_playlist() to stop (e.g. when player dies).

@export var streams: Array[AudioStream]
var _playlist: Array[AudioStream] = []
var _current_index := 0
var _playing := false

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	_player.finished.connect(_on_stream_finished)


func start_playlist() -> void:
	if streams.is_empty():
		return
	_playing = true
	_playlist = streams.duplicate()
	_playlist.shuffle()
	_current_index = 0
	_player.stream = _playlist[_current_index]
	_player.play()


func stop_playlist() -> void:
	_playing = false
	_player.stop()


func _on_stream_finished() -> void:
	if not _playing or _playlist.is_empty():
		return
	_current_index += 1
	if _current_index >= _playlist.size():
		_playlist.shuffle()
		_current_index = 0
	_player.stream = _playlist[_current_index]
	_player.play()
