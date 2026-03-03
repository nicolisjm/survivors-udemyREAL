extends Area2D
class_name HurtboxComponent

signal hit

@export var health_component: HealthComponent

var floating_text_scene = preload("res://scenes/UI/floating_text.tscn")
var hit_sparks_scene = preload("res://scenes/effects/hit_sparks.tscn")
var default_spark_config = preload("res://resources/effects/default_hit_spark_config.tres") as HitSparkConfig

const HIT_SOUND_PITCH_MIN := 0.8
const HIT_SOUND_PITCH_MAX := 1.2


func _ready() -> void:
	area_entered.connect(on_area_entered)


## Call when this hurtbox is hit (by overlap or by code, e.g. chain lightning).
## spark_config: optional; use ability-specific .tres for different looks, or null for default sparks.
## stun_duration: if > 0, freezes the parent node (e.g. enemy) in place for this many seconds.
## source: optional; if the damage kills the target, passed through to health_component.died(killer_source) for kill attribution.
## is_crit: if true, floating text shows damage in gold with "!" (e.g. 10!); use for crits from Bite or other abilities.
## hit_sound: optional; ability-specific sound (e.g. bite chomp, chain zap). Played at hit position, use hit_sound_volume_db for level.
## hit_sound_trim_end: if > 0 and hit_sound set, stop playback this many seconds before stream end.
## hit_sound_pitch_scale: if > 0, use this pitch for hit_sound; else use default random 0.8–1.2.
## floating_text_color: optional; if set (e.g. Color), floating damage text uses this color (e.g. burn = red-ish fire).
## knockback_impulse: optional; if non-zero, added to the parent's VelocityComponent.velocity (e.g. boomerang knockback).
func apply_damage(amount: float, spark_config: HitSparkConfig = null, stun_duration: float = 0.0, source: Variant = null, is_crit: bool = false, hit_sound: AudioStream = null, hit_sound_volume_db: float = -12.0, hit_sound_trim_end: float = 0.0, hit_sound_pitch_scale: float = 0.0, floating_text_color: Variant = null, knockback_impulse: Vector2 = Vector2.ZERO) -> void:
	var hc = health_component
	if hc == null:
		hc = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if hc == null:
		return
	hc.damage(amount, source)
	if stun_duration > 0.0:
		var parent_node = get_parent()
		if parent_node:
			parent_node.set_meta("stun_until", Time.get_ticks_msec() / 1000.0 + stun_duration)
	if knockback_impulse != Vector2.ZERO:
		var parent_node = get_parent()
		if parent_node:
			var vc = parent_node.get_node_or_null("VelocityComponent") as Node
			if vc != null and vc.get("velocity") != null:
				var magnitude: float = knockback_impulse.length()
				if parent_node.is_in_group("flying_enemy"):
					magnitude *= 0.25
				# Scale by enemy acceleration so knockback feels more consistent: high-accel (e.g. spider) re-accelerates quickly so use stronger impulse; low-accel (e.g. ogre) gets less so they don't get launched off-screen.
				var accel: Variant = vc.get("acceleration")
				if accel != null and typeof(accel) == TYPE_FLOAT:
					var scale_factor: float = clampf(float(accel) / 10.0, 0.4, 2.0)
					magnitude *= scale_factor
				# Always knock back away from the player for consistent direction and to avoid odd interactions (wizard slide, separation).
				var player = get_tree().get_first_node_in_group("player") as Node2D
				var away_from_player: Vector2
				if player != null and is_instance_valid(player):
					away_from_player = (parent_node.global_position - player.global_position)
					if away_from_player.length_squared() > 1.0:
						away_from_player = away_from_player.normalized()
					else:
						away_from_player = Vector2.RIGHT
				else:
					away_from_player = knockback_impulse.normalized()
				vc.velocity += away_from_player * magnitude
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground:
		var floating_text = floating_text_scene.instantiate() as Node2D
		foreground.add_child(floating_text)
		floating_text.global_position = global_position + (Vector2.UP * 16)
		var format_string = "%0.0f"
		var custom_color: Variant = floating_text_color
		floating_text.start(format_string % amount, is_crit, custom_color)
		# Generic hit sparks: configurable per ability via spark_config.
		var sparks = hit_sparks_scene.instantiate() as Node2D
		sparks.global_position = global_position
		sparks.set_spark_config(spark_config if spark_config else default_spark_config)
		foreground.add_child(sparks)
		# Optional ability-specific hit sound (pitch: override or 0.8–1.2). Skip when paused to avoid burst on unpause.
		if hit_sound != null and not get_tree().paused:
			var sound_player := AudioStreamPlayer2D.new()
			sound_player.stream = hit_sound
			sound_player.volume_db = hit_sound_volume_db
			sound_player.pitch_scale = hit_sound_pitch_scale if hit_sound_pitch_scale > 0.0 else randf_range(HIT_SOUND_PITCH_MIN, HIT_SOUND_PITCH_MAX)
			foreground.add_child(sound_player)
			sound_player.global_position = global_position
			sound_player.finished.connect(sound_player.queue_free)
			sound_player.play()
			if hit_sound_trim_end > 0.0 and hit_sound.get_length() > 0.0:
				var trim_time := maxf(0.0, hit_sound.get_length() - hit_sound_trim_end)
				if trim_time > 0.0:
					var t := get_tree().create_timer(trim_time)
					var player_ref = weakref(sound_player)
					t.timeout.connect(func():
						var p = player_ref.get_ref()
						if p:
							p.stop()
					)
	hit.emit()


func on_area_entered(other_area: Area2D) -> void:
	if not other_area is HitboxComponent:
		return
	var hitbox_component = other_area as HitboxComponent
	# Skip overlap-based damage when hitbox uses 0 (e.g. flamethrower applies damage on timer only).
	if hitbox_component.damage <= 0:
		return
	var spark_config = hitbox_component.hit_spark_config if hitbox_component.hit_spark_config else null
	var knockback_impulse := Vector2.ZERO
	if hitbox_component.knockback_strength > 0:
		var away: Vector2 = (global_position - hitbox_component.global_position).normalized()
		knockback_impulse = away * hitbox_component.knockback_strength
	var h_sound: AudioStream = hitbox_component.hit_sound if hitbox_component.get("hit_sound") != null else null
	var h_vol: float = hitbox_component.hit_sound_volume_db if hitbox_component.get("hit_sound_volume_db") != null else -12.0
	var h_trim: float = hitbox_component.hit_sound_trim_end if hitbox_component.get("hit_sound_trim_end") != null else 0.0
	var h_pitch: float = hitbox_component.hit_sound_pitch_scale if hitbox_component.get("hit_sound_pitch_scale") != null else 0.0
	apply_damage(hitbox_component.damage, spark_config, 0.0, null, hitbox_component.is_crit, h_sound, h_vol, h_trim, h_pitch, null, knockback_impulse)
