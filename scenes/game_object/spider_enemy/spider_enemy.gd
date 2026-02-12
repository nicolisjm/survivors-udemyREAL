extends CharacterBody2D

@onready var visuals = $Visuals
@onready var velocity_component = $VelocityComponent


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
	velocity_component.accelerate_to_player()
	velocity_component.move(self)
	
	var move_sign = sign(velocity.x)
	if move_sign != 0:
		visuals.scale = Vector2(-move_sign, 1)


func on_hit():
	$HitRandomAudioPlayerComponent.play_random()
