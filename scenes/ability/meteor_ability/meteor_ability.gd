extends Node2D
## Meteor falls from top of screen to a target position. No hitbox while falling; AOE explosion on impact.
## Optionally spawns burning ground (level 9) for DoT in same AOE.

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: GPUParticles2D = $GPUParticles2D
@onready var aoe_ring: Node2D = $AoeRing
@onready var explosion_stream_player: AudioStreamPlayer2D = $ExplosionStreamPlayer

## Set by controller before add_child. World position where the meteor lands (lead-predicted).
var land_position: Vector2 = Vector2.ZERO
## Damage applied in the AOE on impact.
var damage: float = 5.0
## Radius of the explosion AOE (pixels).
var aoe_radius: float = 40.0
## Fall speed (pixels per second).
var fall_speed: float = 400.0
## Visual scale of the meteor sprite.
var size_mult: float = 1.0
## If true, spawn burning ground at impact (level 9).
var spawn_burning_ground: bool = false
## Burning ground: damage per tick.
var burning_ground_damage_per_tick: float = 1.0
## Burning ground: seconds between ticks.
var burning_ground_tick_interval: float = 0.2
## Burning ground: total duration in seconds.
var burning_ground_duration: float = 2.0
## Burning ground: radius (usually same as aoe_radius).
var burning_ground_radius: float = 40.0

## PackedScene for burning ground (set by controller if spawn_burning_ground).
var burning_ground_scene: PackedScene = null

## Impact sound: same as bomb explosion but quieter and pitched down (bomb uses -16 dB, 1.2 pitch).
const EXPLOSION_VOLUME_DB := -23.0
const EXPLOSION_PITCH := 0.8

const HURTBOX_LAYER := 32
## How long the explosion hitbox stays active (one frame might miss; short window is safe).
const EXPLOSION_HITBOX_DURATION := 0.12
## Break animation: shake + scale down duration.
const BREAK_DURATION := 0.28
const BREAK_SHAKE_AMOUNT := 4.0

var _start_y: float = 0.0
var _impacted: bool = false
var _breaking: bool = false
var _break_elapsed: float = 0.0
var _sprite_base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	# No hitbox while falling
	var shape_node: CollisionShape2D = hitbox_component.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is CircleShape2D:
		var circle: CircleShape2D = (shape_node.shape as CircleShape2D).duplicate()
		circle.radius = aoe_radius
		shape_node.shape = circle
		shape_node.set_deferred("disabled", true)
	hitbox_component.collision_layer = 0
	hitbox_component.collision_mask = 0

	sprite.scale = Vector2(0.5, 0.5) * size_mult
	# Start above the top of the screen
	var cam = get_viewport().get_camera_2d()
	if cam != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var half: Vector2 = (vp_size / cam.zoom) * 0.5
		_start_y = cam.global_position.y - half.y - 50.0
	else:
		_start_y = land_position.y - 400.0

	global_position = Vector2(land_position.x, _start_y)


func _process(delta: float) -> void:
	if _breaking:
		_break_elapsed += delta
		sprite.position = Vector2(randf_range(-BREAK_SHAKE_AMOUNT, BREAK_SHAKE_AMOUNT), randf_range(-BREAK_SHAKE_AMOUNT, BREAK_SHAKE_AMOUNT))
		sprite.scale = _sprite_base_scale.lerp(Vector2.ZERO, clampf(_break_elapsed / BREAK_DURATION, 0.0, 1.0))
		if _break_elapsed >= BREAK_DURATION:
			queue_free()
		return
	if _impacted:
		return
	# Fall straight down
	global_position.y += fall_speed * delta
	if global_position.y >= land_position.y:
		global_position.y = land_position.y
		_on_impact()


func _on_impact() -> void:
	if _impacted:
		return
	_impacted = true

	# Enable AOE hitbox briefly so overlapping hurtboxes take damage
	hitbox_component.damage = damage
	hitbox_component.collision_layer = 4
	hitbox_component.collision_mask = HURTBOX_LAYER
	var shape_node: CollisionShape2D = hitbox_component.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		shape_node.disabled = false

	if particles:
		particles.emitting = true

	explosion_stream_player.volume_db = EXPLOSION_VOLUME_DB
	explosion_stream_player.pitch_scale = EXPLOSION_PITCH
	explosion_stream_player.play()

	# AOE wave/ring effect at impact
	if aoe_ring and aoe_ring.get("radius") != null:
		aoe_ring.radius = aoe_radius
		aoe_ring.run()

	# Disable hitbox after a short window so we don't double-hit
	await get_tree().create_timer(EXPLOSION_HITBOX_DURATION).timeout
	if not is_instance_valid(self):
		return
	if shape_node:
		shape_node.disabled = true
	hitbox_component.collision_mask = 0

	# Spawn burning ground if level 9
	if spawn_burning_ground and burning_ground_scene != null:
		var foreground = get_tree().get_first_node_in_group("foreground_layer")
		if foreground:
			var ground = burning_ground_scene.instantiate()
			ground.global_position = global_position
			ground.damage_per_tick = burning_ground_damage_per_tick
			ground.tick_interval = burning_ground_tick_interval
			ground.duration = burning_ground_duration
			ground.radius = burning_ground_radius
			foreground.add_child(ground)

	# Start break animation: shake + scale down, then despawn
	_sprite_base_scale = sprite.scale
	_breaking = true
