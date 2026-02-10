extends Node2D

## Generic hit spark effect. Apply a HitSparkConfig (or use built-in default) then add to tree; it plays once and frees itself.
## Spawned by HurtboxComponent.apply_damage(); abilities can pass a config for their own look.

@onready var particles: CPUParticles2D = $CPUParticles2D

var _config: HitSparkConfig


func _ready() -> void:
	particles.finished.connect(queue_free)
	if _config:
		_apply_config(_config)
	particles.emitting = true


## Call before add_child so the effect uses this config. If never set, particles use scene defaults.
func set_spark_config(config: HitSparkConfig) -> void:
	_config = config


func _apply_config(c: HitSparkConfig) -> void:
	particles.amount = c.amount
	particles.lifetime = c.lifetime
	particles.explosiveness = c.explosiveness
	particles.direction = c.direction
	particles.spread = c.spread
	particles.initial_velocity_min = c.initial_velocity_min
	particles.initial_velocity_max = c.initial_velocity_max
	particles.gravity = c.gravity
	particles.scale_amount_min = c.scale_min
	particles.scale_amount_max = c.scale_max
	particles.color = c.color
