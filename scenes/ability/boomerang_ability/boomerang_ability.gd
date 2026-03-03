extends Node2D

signal collected

@onready var hitbox_component: HitboxComponent = $HitboxComponent

## Hit tree SFX: pitched up, quieter on outbound, even quieter on return.
const _HIT_TREE_SOUND = preload("res://assets/audio/sfx/u_xjrmmgxfru-hit-tree-01-266310.mp3")
const _HIT_VOLUME_DB_OUTBOUND := -18.0
const _HIT_VOLUME_DB_RETURN := -26.0
const _HIT_PITCH_SCALE := 1.15

## Set by controller before add_child.
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300
var max_outbound_distance: float = 200.0
## After the first outbound hit, fly this much further (px) before returning so the hitbox can hit more enemies.
var outbound_extra_after_first_hit: float = 45
var damage: float = 1
var knockback_strength: float = 100.0
var collect_radius: float = 28.0
## Radians per second (constant spin).
var spin_speed: float = 15.0

enum State { OUTBOUND, RETURN }
var _state: State = State.OUTBOUND
var _outbound_traveled: float = 0.0
## When set (>= 0), we return once _outbound_traveled reaches this (after first hit + extra).
var _return_at_traveled: float = -1.0
var _outbound_hit_ids: Dictionary = {}
var _return_hit_ids: Dictionary = {}
var _start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_start_position = global_position
	# We handle hits ourselves so we can do one hit per enemy per phase and control knockback.
	hitbox_component.damage = 0
	hitbox_component.knockback_strength = 0
	# HitboxComponent.tscn has collision_mask = 0; we must mask hurtbox layer (32) so area_entered fires.
	hitbox_component.collision_mask = 32
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)


func _process(delta: float) -> void:
	# Constant spin
	rotation += spin_speed * delta

	if _state == State.OUTBOUND:
		var move := direction * speed * delta
		global_position += move
		_outbound_traveled += move.length()
		var should_return := _outbound_traveled >= max_outbound_distance
		if _return_at_traveled >= 0 and _outbound_traveled >= _return_at_traveled:
			should_return = true
		if should_return:
			_switch_to_return()
	elif _state == State.RETURN:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player == null or not is_instance_valid(player):
			return
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		if dist < collect_radius:
			collected.emit()
			queue_free()
			return
		var move := to_player.normalized() * speed * delta
		global_position += move


func _switch_to_return() -> void:
	_state = State.RETURN
	_return_hit_ids.clear()
	# Ensure no knockback can apply on return (hurtbox uses hitbox.knockback_strength when it runs).
	hitbox_component.knockback_strength = 0
	# We may already be overlapping an enemy (area_entered only fires on NEW overlap). Apply return hit to any we're already touching.
	_apply_return_hits_to_overlapping()


func _play_hit_sound(world_position: Vector2, volume_db: float, pitch_scale: float) -> void:
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = _HIT_TREE_SOUND
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	foreground.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()


func _apply_return_hits_to_overlapping() -> void:
	var spark_config = hitbox_component.hit_spark_config if hitbox_component.hit_spark_config else null
	for area in hitbox_component.get_overlapping_areas():
		if not area is HurtboxComponent:
			continue
		var hurtbox := area as HurtboxComponent
		var id := hurtbox.get_instance_id()
		if _return_hit_ids.get(id, false):
			continue
		_return_hit_ids[id] = true
		hurtbox.apply_damage(damage, spark_config, 0.0, null, hitbox_component.is_crit, null, -12.0, 0.0, 0.0, null, Vector2.ZERO)
		_play_hit_sound(hurtbox.global_position, _HIT_VOLUME_DB_RETURN, _HIT_PITCH_SCALE)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	var id := hurtbox.get_instance_id()
	var spark_config = hitbox_component.hit_spark_config if hitbox_component.hit_spark_config else null

	if _state == State.OUTBOUND:
		if _outbound_hit_ids.get(id, false):
			return
		_outbound_hit_ids[id] = true
		var knockback_impulse := (hurtbox.global_position - global_position).normalized() * knockback_strength
		hurtbox.apply_damage(damage, spark_config, 0.0, null, hitbox_component.is_crit, null, -12.0, 0.0, 0.0, null, knockback_impulse)
		_play_hit_sound(hurtbox.global_position, _HIT_VOLUME_DB_OUTBOUND, _HIT_PITCH_SCALE)
		# After first hit, schedule return after flying a bit further so more enemies can be hit naturally.
		if _return_at_traveled < 0:
			_return_at_traveled = _outbound_traveled + outbound_extra_after_first_hit
	elif _state == State.RETURN:
		if _return_hit_ids.get(id, false):
			return
		_return_hit_ids[id] = true
		hurtbox.apply_damage(damage, spark_config, 0.0, null, hitbox_component.is_crit, null, -12.0, 0.0, 0.0, null, Vector2.ZERO)
		_play_hit_sound(hurtbox.global_position, _HIT_VOLUME_DB_RETURN, _HIT_PITCH_SCALE)
