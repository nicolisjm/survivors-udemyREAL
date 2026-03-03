extends Node

@export var bow_arrow_ability_scene: PackedScene

const MIN_WAIT_TIME := 0.01
## Max distance to consider an enemy for aiming (pixels).
const MAX_AIM_RANGE := 400.0

var _bow_fire_sound: AudioStream = preload("res://assets/audio/sfx/freesound_community-bow-release-bow-and-arrow-4-101936.mp3") as AudioStream
const BOW_FIRE_VOLUME_DB := -8.0
## Pitch multiplier (1.0 = normal, >1 = higher, e.g. 1.1 for slightly sharper).
const BOW_FIRE_PITCH_SCALE := 1.3
## Skip this many seconds at the start of the sound file (if the file has leading silence).
const BOW_FIRE_TRIM_START := 0.15

var _bow_sound_player: AudioStreamPlayer2D

var base_damage: int = 5
var base_wait_time: float
## Number of arrows (odd: 1, 3, 5, 7, 9). Center targets nearest enemy, others spread.
var _quantity: int = 1
## Pierce: extra targets after the first (0 = hit 1 and stop, 2 = hit 3 then stop).
var _pierce: int = 0
## +2 base damage at level 4.
var _damage_flat_bonus: int = 0
## Seconds reduced from base wait time (level 5: -0.2s, level 9: -0.6s).
var _rate_reduction: float = 0.0
## Arrow speed in pixels per second (level 9: 600).
var projectile_speed: float = 400
## How long each arrow lives before being removed.
var projectile_duration: float = 1
## Half-spread in degrees (total spread = 2 * this; e.g. 45 = ±45°).
var spread_angle_deg: float = 45.0


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("bow_arrow") if manager else 0


func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	# 1: unlock. 2: +2 pierce. 3: +2 arrows. 4: +2 base damage. 5: -0.2s attack rate. 6: +2 pierce. 7: +2 arrows. 8: +4 arrows. 9: -0.6s attack rate, 600 projectile speed.
	_quantity = 1
	if level >= 3:
		_quantity += 2   # 3 arrows
	if level >= 7:
		_quantity += 2   # 5 arrows
	if level >= 8:
		_quantity += 4   # 9 arrows

	_pierce = 1
	if level >= 2:
		_pierce += 2
	if level >= 6:
		_pierce += 2

	_damage_flat_bonus = 2 if level >= 4 else 0

	_rate_reduction = 0.0
	if level >= 5:
		_rate_reduction = 0.2
	if level >= 9:
		_rate_reduction += 0.8

	projectile_speed = 600.0 if level >= 9 else 400


func _get_aim_direction() -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return Vector2.RIGHT
	var enemies = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(enemy: Node2D) -> bool:
		return enemy.global_position.distance_squared_to(player.global_position) < pow(MAX_AIM_RANGE, 2)
	)
	if enemies.is_empty():
		var last_move = player.get("last_move_direction")
		if last_move != null and (last_move as Vector2).length_squared() > 0.0001:
			return (last_move as Vector2).normalized()
		return Vector2.RIGHT
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)
	var nearest = (enemies[0] as Node2D).global_position
	return (nearest - player.global_position).normalized()


func _apply_attack_speed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var mult: float = player.get("attack_speed_multiplier") if player else 1.0
	if mult <= 0.0:
		mult = 1.0
	var wait: float = (base_wait_time - _rate_reduction) / mult
	$Timer.wait_time = max(wait, MIN_WAIT_TIME)
	if $Timer.is_stopped():
		$Timer.start()


func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()
	# Reuse one player so we avoid creation/add_child delay when firing (reduces perceived sound delay).
	_bow_sound_player = AudioStreamPlayer2D.new()
	_bow_sound_player.stream = _bow_fire_sound
	_bow_sound_player.volume_db = BOW_FIRE_VOLUME_DB
	_bow_sound_player.pitch_scale = BOW_FIRE_PITCH_SCALE
	add_child(_bow_sound_player)


func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	# Play bow fire sound immediately (reused player, no node creation; trim start if file has leading silence).
	_bow_sound_player.global_position = player.global_position
	if _bow_sound_player.playing:
		_bow_sound_player.stop()
	_bow_sound_player.play(BOW_FIRE_TRIM_START)

	var base_direction := _get_aim_direction()
	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	var damage: float = (base_damage + _damage_flat_bonus + flat_bonus) * damage_mult

	for i in _quantity:
		# Center arrow (middle index) gets 0° offset; others spread symmetrically (e.g. 3 arrows: -45°, 0°, +45°).
		var center_index: float = (_quantity - 1) / 2.0
		var angle_offset_deg: float = (float(i) - center_index) * (2.0 * spread_angle_deg / maxf(1.0, float(_quantity - 1)))
		var dir: Vector2 = base_direction.rotated(deg_to_rad(angle_offset_deg))
		var arrow = bow_arrow_ability_scene.instantiate()
		arrow.direction = dir
		arrow.damage = damage
		arrow.max_hits = _pierce + 1
		arrow.speed = projectile_speed
		arrow.duration = projectile_duration
		arrow.size_mult = size_mult
		foreground.add_child(arrow)
		arrow.global_position = player.global_position


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "bow_arrow":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage", "generic_damage_prestige", "generic_size", "generic_size_prestige", "generic_duration", "generic_duration_prestige"]:
		pass
