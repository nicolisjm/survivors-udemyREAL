extends Node2D

## Tornado projectile: tick damage (no crits), erratic loop‑de‑loop movement, weak pull on enemies.
## Controller sets direction, damage, duration, tick_interval, size_mult, pull_strength before add_child.

const BASE_RADIUS := 18
const MOVE_SPEED := 80.0
const STRAIGHT_DURATION := 0.25
## Time to complete one full 360° loop; larger = bigger circle (radius ≈ MOVE_SPEED * SPIN_DURATION / TAU).
const SPIN_DURATION := 1.8

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var pull_area: Area2D = $PullArea
@onready var tick_timer: Timer = $TickTimer
@onready var collision_shape: CollisionShape2D = $HitboxComponent/CollisionShape2D

var direction: Vector2 = Vector2.RIGHT
var damage: float = 3.0
var duration: float = 4.0
var tick_interval: float = 0.3
var size_mult: float = 1.0
var pull_strength: float = 60
var move_speed: float = MOVE_SPEED

var _current_direction: Vector2 = Vector2.RIGHT
var _phase: StringName = &"straight"
var _phase_time: float = 0.0
var _lifetime: float = 0.0
## 1 = clockwise, -1 = counter-clockwise; chosen randomly per tornado.
var _spin_direction: float = 1.0


func _ready() -> void:
	_current_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	_spin_direction = 1.0 if randf() > 0.5 else -1.0

	# Scale and hitbox to match size_mult (root scale multiplies shape; use base radius so effective = BASE_RADIUS * size_mult)
	scale = Vector2.ONE * size_mult
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle: CircleShape2D = (collision_shape.shape as CircleShape2D).duplicate()
		circle.radius = BASE_RADIUS
		collision_shape.shape = circle

	tick_timer.wait_time = tick_interval
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()
	_on_tick()


func _process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= duration:
		tick_timer.stop()
		queue_free()
		return

	# Pull: add velocity toward tornado for enemies in pull radius (separate 36px shape, scales with size_mult)
	for area in pull_area.get_overlapping_areas():
		if not area is HurtboxComponent:
			continue
		var enemy: Node2D = area.get_parent() as Node2D
		if not is_instance_valid(enemy):
			continue
		var vc = enemy.get_node_or_null("VelocityComponent")
		if vc != null and vc.get("velocity") != null:
			var to_center: Vector2 = global_position - enemy.global_position
			var dist_sq := to_center.length_squared()
			if dist_sq < 0.0001:
				continue
			var pull_dir: Vector2 = to_center / sqrt(dist_sq)
			vc.velocity += pull_dir * pull_strength * delta

	# Movement: straight then spin (loop‑de‑loop)
	if _phase == &"straight":
		position += _current_direction * move_speed * delta
		_phase_time += delta
		if _phase_time >= STRAIGHT_DURATION:
			_phase = &"spin"
			_phase_time = 0.0
	else:
		var spin_angle: float = TAU * delta / SPIN_DURATION * _spin_direction
		_current_direction = _current_direction.rotated(spin_angle)
		position += _current_direction * move_speed * delta
		_phase_time += delta
		if _phase_time >= SPIN_DURATION:
			_phase = &"straight"
			_phase_time = 0.0


func _on_tick() -> void:
	for area in hitbox_component.get_overlapping_areas():
		if area is HurtboxComponent:
			(area as HurtboxComponent).apply_damage(damage)
