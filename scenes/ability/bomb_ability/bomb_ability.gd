extends Node2D

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var throw_stream_player: AudioStreamPlayer2D = $ThrowStreamPlayer
@onready var explosion_stream_player: AudioStreamPlayer2D = $ExplosionStreamPlayer

## Pitch scale for the throw (cartoon jump) sound. Tweak in inspector until it sounds right.
@export_range(0.5, 2.0, 0.05) var throw_pitch: float = 1.2
## Pitch scale for the explosion sound. Tweak in inspector until it sounds right.
@export_range(0.5, 2.0, 0.05) var explosion_pitch: float = 1.2
## Volume for the throw sound (dB). 0 = full; negative = quieter. Default -6 dB.
@export_range(-24.0, 0.0, 0.5) var throw_volume_db: float = -22
## Volume for the explosion sound (dB). 0 = full; negative = quieter. Default -6 dB.
@export_range(-24.0, 0.0, 0.5) var explosion_volume_db: float = -16

## Set by controller before add_child. World position where the bomb lands.
var land_position: Vector2 = Vector2.ZERO
## Start of the arc (player position); set by controller before add_child so the tween starts at the player.
var start_position: Vector2 = Vector2.ZERO
## Damage applied on explosion (set by controller before add_child).
var damage: float = 0.0
## Scale multiplier on top of scene base scale (scene uses 0.5; final scale = BASE_SCALE * size_mult).
var size_mult: float = 1.0
## Duration of the throw arc in seconds.
var arc_duration: float = 0.4
## Peak height of the arc in pixels (parabola).
var arc_height: float = 50.0

## Level 9: spawn 2 mini bombs from explosion (set by controller when level >= 9).
var spawn_mini_bombs: bool = false
var mini_bomb_scene: PackedScene = null

## Mini bomb lob: farther and wider spread. Size uses MINI_SCALE_MULT; damage is 1/4.
const MINI_THROW_MIN := 40.0
const MINI_THROW_MAX := 80
const MINI_TARGET_RANGE := 200.0
const MINI_SPREAD_ANGLE_DEG := 35
const MINI_ARC_DURATION := 0.4
const MINI_ARC_HEIGHT := 25.0
const MINI_SCALE_MULT := 0.5  # 50% of parent bomb size
const MINI_DAMAGE_MULT := 0.25  # 1/4 damage
## Mini bomb sounds: quieter and slightly higher pitch.
const MINI_THROW_VOLUME_DB := -32
const MINI_THROW_PITCH := 1.7
const MINI_EXPLOSION_VOLUME_DB := -26
const MINI_EXPLOSION_PITCH := 1.7

const BASE_SCALE := 0.5  # Match scene root and sprite (0.5)
var _start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Ensure hitbox is disabled during the arc; explode animation will enable it at t=1.
	var shape: CollisionShape2D = hitbox_component.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = true
	hitbox_component.damage = damage
	# Keep scene base scale 0.5; apply size_mult on top.
	scale = Vector2(BASE_SCALE, BASE_SCALE) * size_mult
	_start_pos = start_position
	global_position = start_position

	animation_player.animation_finished.connect(_on_animation_finished)

	throw_stream_player.pitch_scale = throw_pitch
	throw_stream_player.volume_db = throw_volume_db
	throw_stream_player.play()

	var tween := create_tween()
	tween.tween_method(_arc_tween_method, 0.0, 1.0, arc_duration)
	tween.tween_callback(_on_arc_complete)


func _arc_tween_method(t: float) -> void:
	var x := lerpf(_start_pos.x, land_position.x, t)
	var y := lerpf(_start_pos.y, land_position.y, t) - arc_height * 4.0 * t * (1.0 - t)
	global_position = Vector2(x, y)


func _on_arc_complete() -> void:
	animation_player.play("explode")


## Call from AnimationPlayer (Call Method track) to spawn mini bombs at the explosion moment (level 9 only).
func trigger_mini_bombs() -> void:
	if spawn_mini_bombs and mini_bomb_scene != null:
		_spawn_mini_bombs_from(global_position)


## Call from AnimationPlayer (Call Method track) to play the explosion sound at the right frame.
func play_explosion_sound() -> void:
	explosion_stream_player.pitch_scale = explosion_pitch
	explosion_stream_player.volume_db = explosion_volume_db
	explosion_stream_player.play()


func _on_animation_finished(_anim_name: StringName) -> void:
	await explosion_stream_player.finished
	queue_free()


func _get_mini_bomb_land_positions(explosion_pos: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var tree := get_tree()
	if tree == null:
		return result
	var range_sq := MINI_TARGET_RANGE * MINI_TARGET_RANGE
	var enemies: Array = tree.get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return enemy.global_position.distance_squared_to(explosion_pos) < range_sq
	)
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(explosion_pos) < b.global_position.distance_squared_to(explosion_pos)
	)
	var center_dir: Vector2 = Vector2.RIGHT
	if enemies.size() > 0:
		center_dir = ((enemies[0] as Node2D).global_position - explosion_pos).normalized()
	for i in 2:
		var angle_offset_rad: float = (float(i) - 0.5) * deg_to_rad(MINI_SPREAD_ANGLE_DEG)
		var dir: Vector2 = center_dir.rotated(angle_offset_rad)
		var throw_dist: float
		if i < enemies.size():
			var dist_to_enemy: float = explosion_pos.distance_to((enemies[i] as Node2D).global_position)
			throw_dist = clampf(dist_to_enemy * 0.5, MINI_THROW_MIN, MINI_THROW_MAX)
		else:
			dir = Vector2.from_angle(randf() * TAU)
			throw_dist = (MINI_THROW_MIN + MINI_THROW_MAX) * 0.5
		result.append(explosion_pos + dir * throw_dist)
	return result


func _spawn_mini_bombs_from(explosion_pos: Vector2) -> void:
	var tree := get_tree()
	if tree == null or mini_bomb_scene == null:
		return
	var foreground = tree.get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return
	var land_positions: Array[Vector2] = _get_mini_bomb_land_positions(explosion_pos)
	var mini_damage: float = damage * MINI_DAMAGE_MULT
	var mini_size: float = size_mult * MINI_SCALE_MULT
	for land_pos in land_positions:
		var mini_bomb = mini_bomb_scene.instantiate()
		mini_bomb.land_position = land_pos
		mini_bomb.start_position = explosion_pos
		mini_bomb.damage = mini_damage
		mini_bomb.size_mult = mini_size
		mini_bomb.arc_duration = MINI_ARC_DURATION
		mini_bomb.arc_height = MINI_ARC_HEIGHT
		mini_bomb.spawn_mini_bombs = false
		mini_bomb.throw_volume_db = MINI_THROW_VOLUME_DB
		mini_bomb.throw_pitch = MINI_THROW_PITCH
		mini_bomb.explosion_volume_db = MINI_EXPLOSION_VOLUME_DB
		mini_bomb.explosion_pitch = MINI_EXPLOSION_PITCH
		foreground.add_child(mini_bomb)
