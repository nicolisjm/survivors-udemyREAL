extends Area2D

@onready var visuals = $Visuals
@onready var velocity_component = $VelocityComponent

var is_moving = false


func _ready() -> void:
	$HurtboxComponent.hit.connect(on_hit)


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var stun_until: float = get_meta("stun_until", -1.0)
	if now < stun_until:
		modulate = Color(0.6, 0.75, 1.2)  # visible stun: blue tint + dim
		velocity_component.velocity = Vector2.ZERO
		velocity_component.move(self)
		return
	modulate = Color.WHITE
	if is_moving:
		velocity_component.accelerate_to_player()
	else:
		velocity_component.decelerate()
		# Gentle steer toward player during slide so wizards don't drift into crowds.
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player and is_instance_valid(player):
			var dir := (player.global_position - global_position).normalized()
			velocity_component.velocity += dir * 120.0 * _delta
	velocity_component.move(self)
	
	var move_sign = sign(velocity_component.velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)


func set_is_moving(moving: bool):
	is_moving = moving

func on_hit():
	$HitRandomAudioPlayerComponent.play_random()
