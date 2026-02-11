extends Node

## Tracks rapid experience vial pickups and returns pitch + delay so each pickup
## plays at a slightly higher pitch with a small stagger delay. Resets after no pickups for a while.

const BASE_PITCH: float = 3
const PITCH_INCREMENT: float = 0.2
const MAX_PITCH: float = 9
const RESET_SECONDS: float = 0.75
const BASE_DELAY: float = 0.02
const DELAY_PER_PICKUP: float = 0.025

var _pitch_level: int = 0
var _last_pickup_time: float = -999.0


func get_pickup_sound_params() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_pickup_time > RESET_SECONDS:
		_pitch_level = 0
	_last_pickup_time = now
	var delay := BASE_DELAY + _pitch_level * DELAY_PER_PICKUP
	var pitch := clampf(BASE_PITCH + _pitch_level * PITCH_INCREMENT, BASE_PITCH, MAX_PITCH)
	_pitch_level += 1
	_pitch_level = min(_pitch_level, 30)
	return { "pitch": pitch, "delay": delay }
