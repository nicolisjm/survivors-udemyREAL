extends Area2D
class_name HitboxComponent

var damage = 0
## Optional. When this hitbox hits a hurtbox, that hurtbox uses this config for hit sparks (else default).
@export var hit_spark_config: HitSparkConfig
