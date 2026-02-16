extends Area2D
class_name HurtboxComponent

signal hit

@export var health_component: HealthComponent

var floating_text_scene = preload("res://scenes/UI/floating_text.tscn")
var hit_sparks_scene = preload("res://scenes/effects/hit_sparks.tscn")
var default_spark_config = preload("res://resources/effects/default_hit_spark_config.tres") as HitSparkConfig


func _ready() -> void:
	area_entered.connect(on_area_entered)


## Call when this hurtbox is hit (by overlap or by code, e.g. chain lightning).
## spark_config: optional; use ability-specific .tres for different looks, or null for default sparks.
## stun_duration: if > 0, freezes the parent node (e.g. enemy) in place for this many seconds.
func apply_damage(amount: float, spark_config: HitSparkConfig = null, stun_duration: float = 0.0) -> void:
	if health_component == null:
		return
	health_component.damage(amount)
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
		floating_text.start(format_string % amount)
		# Generic hit sparks: configurable per ability via spark_config.
		var sparks = hit_sparks_scene.instantiate() as Node2D
		sparks.global_position = global_position
		sparks.set_spark_config(spark_config if spark_config else default_spark_config)
		foreground.add_child(sparks)
	hit.emit()


func on_area_entered(other_area: Area2D) -> void:
	if not other_area is HitboxComponent:
		return
	var hitbox_component = other_area as HitboxComponent
	var spark_config = hitbox_component.hit_spark_config if hitbox_component.hit_spark_config else null
	apply_damage(hitbox_component.damage, spark_config)
