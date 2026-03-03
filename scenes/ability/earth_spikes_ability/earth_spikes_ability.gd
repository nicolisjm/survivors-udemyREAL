extends Node2D

## Set by controller before add_child.
var damage: float = 0.0
var linger_duration: float = 5.0
## Number of hits before the spike retracts. Default 1 = retract after first hit.
var max_hits: int = 1
## Scale multiplier from generic size upgrades.
var size_mult: float = 1.0
## Knockback impulse; set by controller (e.g. +20% at level 7).
var knockback_strength: float = 20.0

const HURTBOX_LAYER := 32

const _ROCK_DESTROY_SOUND = preload("res://assets/audio/sfx/freesound_community-rock-destroy-6409.mp3")
const _ROCK_SOUND_VOLUME_DB := -32
const _ROCK_SOUND_QUIET_VOLUME_DB := -36
const _ROCK_SOUND_PITCH := 1.2

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _hit_count: int = 0
var _retract_triggered: bool = false


func _ready() -> void:
	scale = Vector2.ONE * size_mult
	hitbox_component.damage = damage
	hitbox_component.collision_mask = HURTBOX_LAYER
	hitbox_component.knockback_strength = knockback_strength
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)
	$Sprite2D.scale = Vector2.ZERO
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("rise")


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	_hit_count += 1
	if _hit_count >= max_hits and not _retract_triggered:
		_trigger_retract()


func _trigger_retract() -> void:
	_retract_triggered = true
	animation_player.play("retract")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "rise":
		_run_linger_timer()
	elif anim_name == "retract":
		queue_free()


## Waits linger_duration seconds but only counts time when the tree is not paused.
func _run_linger_timer() -> void:
	var elapsed := 0.0
	while elapsed < linger_duration:
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()
	if not _retract_triggered:
		_trigger_retract()


## Call from AnimationPlayer (rise or retract) to play the rock destroy SFX.
## Pass quiet=true for a quieter variant (e.g. retract).
## Skips playing when the tree is paused so sounds don't queue up and burst on unpause.
func play_rock_destroy_sound(quiet: bool = false) -> void:
	if get_tree().paused:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _ROCK_DESTROY_SOUND
	player.volume_db = _ROCK_SOUND_QUIET_VOLUME_DB if quiet else _ROCK_SOUND_VOLUME_DB
	player.pitch_scale = _ROCK_SOUND_PITCH
	foreground.add_child(player)
	player.global_position = global_position
	player.finished.connect(player.queue_free)
	player.play()
