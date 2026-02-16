extends Node

signal experience_updated(current_experience: float, target_experience: float)
signal level_up(new_level: int)

var TARGET_EXPERIENCE_GROWTH = 5

var current_experience = 0
var current_level = 1
var target_experience = 1
var total_experience_collected: float = 0


func _ready() -> void:
	GameEvents.experience_vial_collected.connect(on_experience_vial_collected)


func increment_experience(number: float):
	var remaining := number
	while remaining > 0:
		var space: float = target_experience - current_experience
		var to_add := minf(remaining, space)
		current_experience += to_add
		remaining -= to_add
		experience_updated.emit(current_experience, target_experience)
		if current_experience >= target_experience:
			current_level += 1
			target_experience += TARGET_EXPERIENCE_GROWTH
			current_experience = 0
			experience_updated.emit(current_experience, target_experience)
			level_up.emit(current_level)


func on_experience_vial_collected(number: float):
	total_experience_collected += number
	increment_experience(number)


func get_total_experience_collected() -> float:
	return total_experience_collected
