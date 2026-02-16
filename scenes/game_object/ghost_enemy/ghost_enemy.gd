extends Area2D

## How much to blend toward player each frame (a bit better aim than bat).
const STEER_STRENGTH := 0.18
const RETARGET_DELAY := 0.3
const OFF_SCREEN_MARGIN := 80.0

enum State { FLYING, RETARGET_WAIT }
var _state := State.FLYING
var _retarget_timer := 0.0

@onready var visuals = $Visuals
@onready var velocity_component = $VelocityComponent


func _ready() -> void:
	$HurtboxComponent.hit.connect(on_hit)


func _process(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var stun_until: float = get_meta("stun_until", -1.0)
	if now < stun_until:
		modulate = Color(0.6, 0.75, 1.2)
		velocity_component.velocity = Vector2.ZERO
		velocity_component.move(self)
		return
	modulate = Color.WHITE

	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity_component.move(self)
		_update_facing()
		return

	if _state == State.RETARGET_WAIT:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			var dir = (player.global_position - global_position).normalized()
			velocity_component.velocity = dir * velocity_component.max_speed
			_state = State.FLYING
		velocity_component.move(self)
		_update_facing()
		return

	# FLYING: slight aim toward player (better than bat). Throttle off-screen check.
	if Engine.get_process_frames() % 3 == 0 and _is_off_screen():
		_state = State.RETARGET_WAIT
		_retarget_timer = RETARGET_DELAY
		velocity_component.move(self)
		_update_facing()
		return

	# Throttle steering updates every 2 frames to reduce CPU.
	if Engine.get_process_frames() % 2 == 0:
		var dir_to_player: Vector2 = (player.global_position - global_position).normalized()
		var current_dir: Vector2 = velocity_component.velocity.normalized() if velocity_component.velocity.length() > 1.0 else dir_to_player
		var steer_dir: Vector2 = current_dir.lerp(dir_to_player, STEER_STRENGTH)
		var desired_velocity: Vector2 = steer_dir * velocity_component.max_speed
		velocity_component.velocity = velocity_component.velocity.lerp(desired_velocity, 1 - exp(-velocity_component.acceleration * delta))
	velocity_component.move(self)
	_update_facing()


func _is_off_screen() -> bool:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return false
	var vp_rect = get_viewport().get_visible_rect()
	var world_size = vp_rect.size / cam.zoom
	var visible_rect = Rect2(cam.get_screen_center_position() - world_size / 2, world_size)
	visible_rect = visible_rect.grow(OFF_SCREEN_MARGIN)
	return not visible_rect.has_point(global_position)


func _update_facing() -> void:
	var move_sign = sign(velocity_component.velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(-move_sign, 1)


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()
