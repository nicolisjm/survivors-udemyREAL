extends Node

signal experience_updated(current_experience: float, target_experience: float)
signal level_up(new_level: int)

## XP needed for first level up (1 -> 2)
const XP_LEVEL_1 = 1
## Level at which exponential scaling starts
const EXPONENTIAL_START_LEVEL = 30
## Levels 2-6: easier than old; XP = EARLY_GROWTH * (level - 1)
const EARLY_GROWTH = 3.0
## Levels 7-12: same-ish as old; XP = MID_START + (level - 7) * MID_GROWTH
const MID_START = 30.0
const MID_GROWTH = 5.0
## Levels 13-29: gently harder than old; ramps from HARD_START to value at 29 (exponential base)
const HARD_START = 65.0
const HARD_END_LEVEL = 29
const XP_AT_29 = 155.0  # XP for 29->30; level 30+ starts one step higher to avoid double level-up
## Exponential: first step (30->31) uses this; then gentler every 3 levels (see EXP_GENTLER_PER_3).
const EXPONENTIAL_FACTOR = 1.16
## Every 3 levels the per-level multiplier drops by this much (min EXP_FACTOR_MIN).
const EXP_GENTLER_PER_3 = 0.01
const EXP_FACTOR_MIN = 1.10

var current_experience = 0
var current_level = 1
var target_experience = 1
var total_experience_collected: float = 0


func _ready() -> void:
	GameEvents.experience_vial_collected.connect(on_experience_vial_collected)


## Returns the XP required to go from [param level] to [param level] + 1.
## 1: 1 XP; 2-6: easier; 7-12: same-ish as old; 13-29: gently harder; 30+: exponential.
func get_xp_required_for_level(level: int) -> float:
	if level <= 0:
		return XP_LEVEL_1
	if level == 1:
		return XP_LEVEL_1
	if level <= 6:
		return EARLY_GROWTH * (level - 1)
	if level <= 12:
		return MID_START + (level - 7) * MID_GROWTH
	if level <= HARD_END_LEVEL:
		var t := float(level - 13) / float(HARD_END_LEVEL - 13)
		return HARD_START + t * (XP_AT_29 - HARD_START)
	# Exponential from level 30 onward: first step is already higher (no double level-up),
	# then per-level factor gets gentler every 3 levels
	var base := XP_AT_29 * EXPONENTIAL_FACTOR  # 30->31 requires this (step up from 155)
	var levels_into_exp := level - EXPONENTIAL_START_LEVEL
	if levels_into_exp <= 0:
		return base
	var xp := base
	for k in range(1, levels_into_exp + 1):
		var tier := (k - 1) / 3
		var factor := EXPONENTIAL_FACTOR - EXP_GENTLER_PER_3 * tier
		factor = maxf(factor, EXP_FACTOR_MIN)
		xp *= factor
	return xp


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
			target_experience = get_xp_required_for_level(current_level)
			current_experience = 0
			experience_updated.emit(current_experience, target_experience)
			level_up.emit(current_level)


func on_experience_vial_collected(number: float):
	total_experience_collected += number
	increment_experience(number)


func get_total_experience_collected() -> float:
	return total_experience_collected
