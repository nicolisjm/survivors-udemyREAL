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
## floating_text_color: optional; if set (e.g. Color), floating damage text uses this color (e.g. burn = red-ish fire).
func apply_damage(amount: float, spark_config: HitSparkConfig = null, stun_duration: float = 0.0, source: Variant = null, is_crit: bool = false, hit_sound: AudioStream = null, hit_sound_volume_db: float = -12.0, floating_text_color: Variant = null) -> void:
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
		# Optional ability-specific hit sound (pitch variation 0.8–1.2).
		if hit_sound != null:
			var sound_player := AudioStreamPlayer2D.new()
			sound_player.stream = hit_sound
			sound_player.volume_db = hit_sound_volume_db
			sound_player.pitch_scale = randf_range(HIT_SOUND_PITCH_MIN, HIT_SOUND_PITCH_MAX)
			foreground.add_child(sound_player)
			sound_player.global_position = global_position
			sound_player.finished.connect(sound_player.queue_free)
			sound_player.play()
	hit.emit()


func on_area_entered(other_area: Area2D) -> void:
	if not other_area is HitboxComponent:
		return
	var hitbox_component = other_area as HitboxComponent
	# Skip overlap-based damage when hitbox uses 0 (e.g. flamethrower applies damage on timer only).
	if hitbox_component.damage <= 0:
		return
	var spark_config = hitbox_component.hit_spark_config if hitbox_component.hit_spark_config else null
	apply_damage(hitbox_component.damage, spark_config)
