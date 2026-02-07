extends AudioStreamPlayer2D

@export var streams: Array[AudioStream]
@export var min_pitch = .9
@export var max_pitch = 1.1


func play_random():
	if streams == null || streams.size() == 0:
		return
	
	stream = streams.pick_random()
	play()
