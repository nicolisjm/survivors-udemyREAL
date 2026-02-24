extends Node2D

const BASE_ORBIT_RADIUS := 25
const BASE_ORBIT_DURATION := 2.5
const CRIT_WINDOW_SEC := 1.0
const SPAWN_SCALE_DURATION := 0.15
const DESPAWN_SCALE_DURATION := 0.12
const CRIT_EVERY_N_TICKS := 3
## Forward ball speed (px/s). Adjust here to make it slower or faster.
const FORWARD_SPEED := 40
## Pixels in front of player where forward ball spawns. Increase to spawn further ahead.
const FORWARD_SPAWN_OFFSET := 15

var _chain_hit_sound: AudioStream = preload("res://assets/audio/sfx/freesound_community-electric_zap_001-6374.mp3") as AudioStream
var _chain_spark_config: HitSparkConfig = preload("res://resources/effects/chain_lightning_spark_config.tres") as HitSparkConfig
const HIT_SOUND_QUIET_DB := -36.0
const HIT_SOUND_CRIT_DB := -24.0

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var tick_timer: Timer = $TickTimer
@onready var crit_particles: GPUParticles2D = $BallColorRect/GPUParticles2D

## Set before adding to tree. NAN = random angle.
var initial_angle: float = NAN
var orbit_direction: float = 1.0
var duration_mult: float = 1.0
var radius_mult: float = 1.0
var tick_interval: float = 0.14
## When true, ball moves straight forward slowly instead of orbiting.
var is_forward_ball: bool = false
## Direction for forward ball (set by controller from player's last move). Default RIGHT if not set.
var forward_direction: Vector2 = Vector2.RIGHT

## Normal hit damage (set by controller).
var damage: float = 1.0
## Crit hit damage = (base + crit_bonus) * 2 * mults (set by controller).
var crit_damage: float = 8.0

var base_rotation := Vector2.RIGHT
var _orbit_radius: float
var _forward_direction: Vector2 = Vector2.RIGHT
var _forward_lifetime: float = 0.0
var _forward_duration: float = 0.0
var _enemy_tick_data: Dictionary = {}  # instance_id -> { count: int, last_tick_time: float }
var _despawning: bool = false


func _ready() -> void:
	if is_nan(initial_angle):
		initial_angle = randf_range(0, TAU)
	base_rotation = Vector2.RIGHT.rotated(initial_angle)
	_orbit_radius = BASE_ORBIT_RADIUS * radius_mult

	if is_forward_ball:
		_forward_direction = forward_direction.normalized() if forward_direction.length_squared() > 0.001 else Vector2.RIGHT
		global_position += _forward_direction * FORWARD_SPAWN_OFFSET
		_forward_duration = BASE_ORBIT_DURATION * duration_mult
		set_process(true)
	else:
		var duration: float = BASE_ORBIT_DURATION * duration_mult
		var tween = create_tween()
		tween.tween_method(_tween_orbit, 0.0, 1.0, duration)
		tween.tween_callback(_start_despawn)

	# Defer spawn so we capture scale after controller sets it (add_child triggers _ready before controller sets scale)
	call_deferred("_play_spawn_animation")

	tick_timer.wait_time = tick_interval
	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()
	_on_tick()
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)


func _play_spawn_animation() -> void:
	var target_scale := scale
	var spawn_tween := create_tween()
	spawn_tween.tween_property(self, "scale", Vector2.ZERO, 0.0)
	spawn_tween.set_trans(Tween.TRANS_BACK)
	spawn_tween.set_ease(Tween.EASE_OUT)
	spawn_tween.tween_property(self, "scale", target_scale, SPAWN_SCALE_DURATION)


func _process(delta: float) -> void:
	if not is_forward_ball or _despawning:
		return
	global_position += _forward_direction * FORWARD_SPEED * delta
	_forward_lifetime += delta
	if _forward_lifetime >= _forward_duration:
		_start_despawn()


func _start_despawn() -> void:
	if _despawning:
		return
	_despawning = true
	set_process(false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, DESPAWN_SCALE_DURATION)
	tween.tween_callback(queue_free)


func _tween_orbit(progress: float) -> void:
	var angle: float = initial_angle + progress * TAU * orbit_direction
	var offset := Vector2.from_angle(angle) * _orbit_radius
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	global_position = player.global_position + offset


func _on_tick() -> void:
	_apply_damage_to_overlapping()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		_apply_damage_to_hurtbox(area as HurtboxComponent)


func _apply_damage_to_overlapping() -> void:
	for area in hitbox_component.get_overlapping_areas():
		if area is HurtboxComponent:
			_apply_damage_to_hurtbox(area as HurtboxComponent)


func _apply_damage_to_hurtbox(hurtbox: HurtboxComponent) -> void:
	var key := hurtbox.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var data = _enemy_tick_data.get(key, { "count": 0, "last_tick_time": 0.0 })

	if now - data.last_tick_time > CRIT_WINDOW_SEC:
		data.count = 0
	data.count += 1
	data.last_tick_time = now
	_enemy_tick_data[key] = data

	var is_crit: bool = (int(data.count) % CRIT_EVERY_N_TICKS == 0)
	var amount: float = crit_damage if is_crit else damage
	var vol_db: float = HIT_SOUND_CRIT_DB if is_crit else HIT_SOUND_QUIET_DB
	var spark_config: HitSparkConfig = _chain_spark_config if is_crit else null
	if is_crit:
		crit_particles.restart()
	hurtbox.apply_damage(amount, spark_config, 0.0, null, is_crit, _chain_hit_sound, vol_db)
