extends Node

signal arena_difficulty_increased(arena_difficulty: int)

## Seconds between each difficulty step. Smaller = difficulty rises faster (harder sooner).
@export var difficulty_interval: float = 5.0

var arena_difficulty = 0
var _elapsed_time: float = 0.0


func _process(delta: float) -> void:
	_elapsed_time += delta
	var next_difficulty_time = (arena_difficulty + 1) * difficulty_interval
	if _elapsed_time >= next_difficulty_time:
		arena_difficulty += 1
		arena_difficulty_increased.emit(arena_difficulty)


func get_time_elapsed() -> float:
	return _elapsed_time
