extends Node2D

## Time after attack starts when we sample overlaps and apply damage once per enemy (middle = crit).
const HIT_APPLY_DELAY := 0.15
## HurtboxComponent uses collision_layer 32; hitbox must mask it to see overlaps in get_overlapping_areas().
const HURTBOX_LAYER := 32

## If true, use random rotation (old style). If false, use alternating x + offset from controller; no random skew.
@export var use_random_rotation := false

var _slash_sound: AudioStream = preload("res://assets/audio/sfx/u_xjrmmgxfru-sword-slash-02-266315.mp3") as AudioStream

@onready var hitbox_left: HitboxComponent = $HitboxClawLeft
@onready var hitbox_middle: HitboxComponent = $HitboxClawMiddle
@onready var hitbox_right: HitboxComponent = $HitboxClawRight
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _base_damage: float = 0.0
var _crit_multiplier: float = 2.0
var _slow_duration: float = 0.0
var _slow_multiplier: float = 1.0

## Damage is applied once per enemy; if they overlap the middle hitbox it's a crit, otherwise normal.
## slow_duration > 0: reduce enemy movement speed by (1 - slow_multiplier) for this many seconds; each hit refreshes.
func set_damage(base_damage: float, crit_multiplier: float = 2.0, slow_duration: float = 0.0, slow_multiplier: float = 1.0) -> void:
	_base_damage = base_damage
	_crit_multiplier = crit_multiplier
	_slow_duration = slow_duration
	_slow_multiplier = slow_multiplier
	hitbox_left.damage = 0
	hitbox_right.damage = 0
	hitbox_middle.damage = 0
	hitbox_left.is_crit = false
	hitbox_right.is_crit = false
	hitbox_middle.is_crit = false


func _ready() -> void:
	# So get_overlapping_areas() returns hurtboxes (base HitboxComponent has mask 0).
	hitbox_left.collision_mask = HURTBOX_LAYER
	hitbox_middle.collision_mask = HURTBOX_LAYER
	hitbox_right.collision_mask = HURTBOX_LAYER
	rotation = randf_range(0, TAU) if use_random_rotation else 0.0
	animation_player.animation_finished.connect(_on_attack_finished)
	animation_player.play("attack")
	get_tree().create_timer(HIT_APPLY_DELAY).timeout.connect(_apply_damage_once)


func _apply_damage_once() -> void:
	var overlapping_left := _get_hurtboxes_from(hitbox_left)
	var overlapping_middle := _get_hurtboxes_from(hitbox_middle)
	var overlapping_right := _get_hurtboxes_from(hitbox_right)
	var seen: Array[HurtboxComponent] = []
	for hurtbox in overlapping_left + overlapping_middle + overlapping_right:
		if hurtbox in seen:
			continue
		seen.append(hurtbox)
		var is_crit := false #no need for crit at the moment
		var amount := _base_damage * _crit_multiplier if is_crit else _base_damage
		hurtbox.apply_damage(amount, null, 0.0, null, is_crit)
		# Slow: reduce movement speed; each hit refreshes duration (no stacking).
		if _slow_duration > 0.0:
			var enemy := hurtbox.get_parent()
			if enemy != null:
				var now := Time.get_ticks_msec() / 1000.0
				enemy.set_meta("slow_until", now + _slow_duration)
				enemy.set_meta("slow_multiplier", _slow_multiplier)


func _get_hurtboxes_from(hitbox: HitboxComponent) -> Array[HurtboxComponent]:
	var list: Array[HurtboxComponent] = []
	for area in hitbox.get_overlapping_areas():
		if area is HurtboxComponent:
			list.append(area as HurtboxComponent)
	return list


## Call from AnimationPlayer keyframe when the slash should be heard (e.g. at strike impact).
func play_slash_sound() -> void:
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _slash_sound
	player.volume_db = -21.0
	player.global_position = global_position
	foreground.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _on_attack_finished(_anim_name: StringName) -> void:
	queue_free()
