extends Node
## Added at runtime to enemies/breakables when burn is first applied.
## Runs a timer-based DoT; each tick applies damage via the parent's HurtboxComponent.
## Pass refresh_if_burning = true (e.g. level 9) to extend duration on re-apply.

signal burn_ended

const BURN_FLOATING_TEXT_COLOR := Color(0.95, 0.35, 0.1, 1.0)  # Red-ish fire
const BURN_SOUND := preload("res://assets/audio/sfx/u_xjrmmgxfru-burn-flesh-01-266302.mp3")
const BURN_SOUND_APPLY_VOLUME_DB := -17.0
const BURN_SOUND_DAMAGE_VOLUME_DB := -22.0
const BURN_SOUND_PITCH_MIN := 0.9
const BURN_SOUND_PITCH_MAX := 1.1

var _hurtbox: HurtboxComponent
var _burn_timer: Timer
var _duration_timer: Timer
var _damage_per_tick_base: float = 0.0
var _remaining_duration: float = 0.0
var _ember_visual: Node2D = null  # Set when we add ember particles
## Base tick interval (set in apply_burn); used to shorten next tick when in flame hitbox.
var _base_tick_interval: float = 1.0
## Multiplier for next tick interval (e.g. 1.25 = ticks 25% faster while in flamethrower hitbox).
var _tick_speed_mult: float = 1.0


func _ready() -> void:
	_hurtbox = get_parent().get_node_or_null("HurtboxComponent") as HurtboxComponent
	var hc: HealthComponent = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if hc != null:
		hc.died.connect(_on_parent_died)
	_burn_timer = Timer.new()
	_burn_timer.one_shot = false
	add_child(_burn_timer)
	_duration_timer = Timer.new()
	_duration_timer.one_shot = true
	add_child(_duration_timer)
	_duration_timer.timeout.connect(_on_duration_ended)


## damage_per_tick_base: base damage each timer tick deals (e.g. 5).
## duration_seconds: how long the burn lasts (e.g. 3).
## tick_interval: timer interval; attack speed and burn rate make this smaller so ticks happen more often.
## damage_mult: player damage multiplier (scales per-tick damage).
## duration_mult: scales duration (generic duration upgrade).
## refresh_if_burning: if true and already burning, only reset remaining duration to full.
func apply_burn(
	damage_per_tick_base: float,
	duration_seconds: float,
	tick_interval: float,
	damage_mult: float = 1.0,
	duration_mult: float = 1.0,
	refresh_if_burning: bool = false
) -> void:
	var full_duration: float = duration_seconds * duration_mult
	_damage_per_tick_base = damage_per_tick_base

	if _burn_timer.timeout.is_connected(_on_burn_tick):
		if refresh_if_burning:
			# Extend duration only; do not reset the burn damage timer (keeps tick rhythm).
			_remaining_duration = full_duration
			_stop_duration_timer()
			_start_duration_timer(full_duration)
			_damage_per_tick_base = damage_per_tick_base
			return
		# Already burning and not refresh: could stack or ignore; we stop and reapply so new params take effect.
		_burn_timer.stop()
		_burn_timer.timeout.disconnect(_on_burn_tick)

	_remaining_duration = full_duration
	_burn_timer.wait_time = tick_interval
	_base_tick_interval = tick_interval
	_burn_timer.timeout.connect(_on_burn_tick)
	_burn_timer.start()
	_start_duration_timer(full_duration)
	_spawn_ember_visual()
	_play_burn_sound(BURN_SOUND_APPLY_VOLUME_DB)


## Call when already burning to add time without resetting the burn tick timer.
## seconds_to_add: e.g. 3 — added to current remaining duration.
## max_total_duration: cap so remaining never exceeds this (e.g. 8).
func add_burn_duration(seconds_to_add: float, max_total_duration: float) -> void:
	if not is_burning():
		return
	var current_left: float = _duration_timer.time_left
	var new_remaining: float = minf(current_left + seconds_to_add, max_total_duration)
	_remaining_duration = new_remaining
	_duration_timer.wait_time = new_remaining
	_duration_timer.start()


## Call while enemy is in flamethrower hitbox so the next burn tick happens sooner (e.g. 1.25x).
func set_burn_tick_speed_mult(mult: float) -> void:
	if not is_burning():
		return
	_tick_speed_mult = maxf(_tick_speed_mult, mult)


func _start_duration_timer(duration: float) -> void:
	_duration_timer.wait_time = duration
	_duration_timer.start()


func _stop_duration_timer() -> void:
	_duration_timer.stop()


func _play_burn_sound(volume_db: float) -> void:
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground == null:
		return
	var sound_player := AudioStreamPlayer2D.new()
	sound_player.stream = BURN_SOUND
	sound_player.volume_db = volume_db
	sound_player.pitch_scale = randf_range(BURN_SOUND_PITCH_MIN, BURN_SOUND_PITCH_MAX)
	foreground.add_child(sound_player)
	sound_player.global_position = parent_2d.global_position
	sound_player.finished.connect(sound_player.queue_free)
	sound_player.play()


## Uses current player damage_multiplier and damage_flat_bonus so generic damage upgrades affect burn.
func _get_current_burn_damage() -> float:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return _damage_per_tick_base
	var mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var flat: float = float(player.damage_flat_bonus) if player.get("damage_flat_bonus") != null else 0.0
	return _damage_per_tick_base * mult + flat


func _on_burn_tick() -> void:
	if _hurtbox == null or not is_instance_valid(_hurtbox):
		return
	if _remaining_duration <= 0.0:
		return
	var damage: float = _get_current_burn_damage()
	_play_burn_sound(BURN_SOUND_DAMAGE_VOLUME_DB)
	_hurtbox.apply_damage(
		damage,
		null, 0.0, null, false, null, -12.0, 0.0, 0.0,
		BURN_FLOATING_TEXT_COLOR
	)
	# Next tick: shorter interval if we're in the flame hitbox (_tick_speed_mult > 1).
	_burn_timer.stop()
	_burn_timer.wait_time = _base_tick_interval / _tick_speed_mult
	_tick_speed_mult = 1.0
	_burn_timer.start()


func _on_duration_ended() -> void:
	_burn_timer.stop()
	if _burn_timer.timeout.is_connected(_on_burn_tick):
		_burn_timer.timeout.disconnect(_on_burn_tick)
	_remaining_duration = 0.0
	_remove_ember_visual()
	burn_ended.emit()


func is_burning() -> bool:
	return _duration_timer.time_left > 0.0


func _on_parent_died(_killer_source: Variant = null) -> void:
	if is_burning():
		var parent_2d: Node2D = get_parent() as Node2D
		if parent_2d != null:
			GameEvents.emit_burning_enemy_died(parent_2d.global_position)


func _spawn_ember_visual() -> void:
	if _ember_visual != null:
		return
	var parent_2d: Node2D = get_parent() as Node2D
	if parent_2d == null:
		return
	var mat := ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 90.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -25, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(1.0, 0.4, 0.1, 0.8)
	var particles := GPUParticles2D.new()
	particles.process_material = mat
	particles.amount = 12
	particles.lifetime = 0.8
	particles.explosiveness = 0.0
	particles.emitting = true
	parent_2d.add_child(particles)
	_ember_visual = particles


func _remove_ember_visual() -> void:
	if _ember_visual != null and is_instance_valid(_ember_visual):
		_ember_visual.emitting = false
		_ember_visual.queue_free()
		_ember_visual = null
