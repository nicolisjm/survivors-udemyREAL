extends CharacterBody2D
## Slow infinite-pierce projectile. Bounces off camera viewport edges and tilemap walls. Spins by direction.

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var sprite: Sprite2D = $Sprite2D

## Set by controller before add_child.
var direction: Vector2 = Vector2.RIGHT
var damage: float = 5.0
var speed: float = 120.0
var duration: float = 5.0
var size_mult: float = 1.0
var knockback_strength: float = 10.0

const HURTBOX_LAYER := 32
const ANGULAR_SPEED := 4.0
const BOUNCE_MARGIN := 2.0
## Physics layer for terrain/tilemap walls (project.godot layer_1 = Terrain).
const TERRAIN_LAYER := 1
## Time before despawn over which scale shrinks to zero (rolls away).
const FADE_DURATION := 0.6

var _lifetime: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = TERRAIN_LAYER
	scale = Vector2.ONE * size_mult
	hitbox_component.damage = damage
	hitbox_component.collision_mask = HURTBOX_LAYER
	hitbox_component.knockback_strength = knockback_strength
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)
	# Spin direction: left = one way, right = other
	if direction.x > 0:
		sprite.scale.x = -1


func _on_hitbox_area_entered(area: Area2D) -> void:
	# Infinite pierce: only apply damage via hurtbox, never despawn on hit
	if not area is HurtboxComponent:
		return
	# Hurtbox handles damage; we don't queue_free


func _get_camera_bounds() -> Rect2:
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(global_position - Vector2(10000, 10000), Vector2(20000, 20000))
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half: Vector2 = (vp_size / cam.zoom) * 0.5
	var center: Vector2 = cam.global_position
	return Rect2(center - half, half * 2.0)


func _process(delta: float) -> void:
	# Move using physics so we get wall collision normals for bouncing
	velocity = direction * speed
	var collision := move_and_collide(velocity * delta)
	if collision:
		direction = direction.bounce(collision.get_normal())

	# Bounce off camera viewport edges (same as before)
	var bounds := _get_camera_bounds()
	var margin := BOUNCE_MARGIN
	if global_position.x < bounds.position.x + margin:
		direction.x = abs(direction.x)
		global_position.x = bounds.position.x + margin
	if global_position.x > bounds.end.x - margin:
		direction.x = -abs(direction.x)
		global_position.x = bounds.end.x - margin
	if global_position.y < bounds.position.y + margin:
		direction.y = abs(direction.y)
		global_position.y = bounds.position.y + margin
	if global_position.y > bounds.end.y - margin:
		direction.y = -abs(direction.y)
		global_position.y = bounds.end.y - margin

	# Spin: left = one way, right = other
	rotation += sign(direction.x) * ANGULAR_SPEED * delta

	_lifetime += delta
	# Scale down to zero over FADE_DURATION before despawn (speed unchanged = rolls away)
	if _lifetime >= duration:
		queue_free()
		return
	if _lifetime >= duration - FADE_DURATION:
		var fade_elapsed: float = _lifetime - (duration - FADE_DURATION)
		var t: float = clampf(fade_elapsed / FADE_DURATION, 0.0, 1.0)
		scale = Vector2.ONE * size_mult * (1.0 - t)
