extends Area2D
class_name HitboxComponent

var damage = 0
## When true, hurtbox shows crit-style floating text (gold, "!").
@export var is_crit: bool = false
## Optional. When this hitbox hits a hurtbox, that hurtbox uses this config for hit sparks (else default).
@export var hit_spark_config: HitSparkConfig
## If > 0, hurtbox applies this as impulse (pixels) in direction away from hitbox (e.g. boomerang knockback).
@export var knockback_strength: float = 0.0
## Optional. Played at hit position when this hitbox hits a hurtbox. Leave null for no sound.
@export var hit_sound: AudioStream = null
@export var hit_sound_volume_db: float = -12.0
## If > 0, stop playback this many seconds before the end of the stream (e.g. 0.4 to trim tail).
@export var hit_sound_trim_end: float = 0.0
## If > 0, use this pitch for hit_sound; otherwise hurtbox uses default random pitch.
@export var hit_sound_pitch_scale: float = 0.0
