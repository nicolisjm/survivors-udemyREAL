extends Node

@export var ice_shards_ability_scene: PackedScene

const MIN_WAIT_TIME := 0.01
const MAX_AIM_RANGE := 400.0
const CHAIN_RANGE := 300
const SHARDS_PER_BURST := 3
const BURST_OFFSET_PX := 4
const SHARD_DELAY := 0.1
const BURST_DELAY := 0.3
const POST_CHAIN_FLY_PX := 300.0

var _dart_sound: AudioStream = preload("res://assets/audio/sfx/scratchonix-dart-throw-380649.mp3") as AudioStream
const _DART_VOLUME_DB := -16.0
const _DART_PITCH := 1.25

var base_damage: int = 2
var base_wait_time: float
var projectile_speed: float = 450
var projectile_duration: float = 1
var _burst_count: int = 1
var _chain_count: int = 0
var _rate_reduction: float = 0.0
var _infinite_pierce_after_chain: bool = false


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("ice_shards") if manager else 0


func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	# 1: unlock. 2: +1 chain. 3: -0.2s. 4: +1 burst. 5: -0.2s. 6: +1 chain. 7: +1 burst. 8: +2 chain. 9: infinite pierce after chain.
	_burst_count = 1
	if level >= 4:
		_burst_count = 2
	if level >= 7:
		_burst_count = 3

	_chain_count = 0
	if level >= 2:
		_chain_count += 1
	if level >= 6:
		_chain_count += 1
	if level >= 8:
		_chain_count += 2
	if level >= 9:
		_chain_count += 2

	_rate_reduction = 0.0
	if level >= 3:
		_rate_reduction += 0.2
	if level >= 5:
		_rate_reduction += 0.2

	#_infinite_pierce_after_chain = level >= 9 #changing level 9 to instead chain more.


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
	$Timer.wait_time = max((base_wait_time - _rate_reduction) / mult, MIN_WAIT_TIME)
	if $Timer.is_stopped():
		$Timer.start()


func _wait_unpaused(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()


func _play_dart_sound(at_position: Vector2) -> void:
	if get_tree().paused:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer")
	if foreground == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = _dart_sound
	p.volume_db = _DART_VOLUME_DB
	p.pitch_scale = _DART_PITCH
	foreground.add_child(p)
	p.global_position = at_position
	p.finished.connect(p.queue_free)
	p.play()


func _ready() -> void:
	base_wait_time = $Timer.wait_time
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()


func _on_timer_timeout() -> void:
	$Timer.start()
	if _get_ability_level() <= 0:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		return

	var damage_mult: float = player.damage_multiplier if player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	var damage: float = (base_damage + flat_bonus) * damage_mult

	# Offsets for the 3 shards in a burst: center, right, left
	var offsets: Array[float] = [0.0, BURST_OFFSET_PX, -BURST_OFFSET_PX]

	_do_bursts(foreground, player, damage, size_mult, offsets)


func _do_bursts(foreground: Node2D, player: Node2D, damage: float, size_mult: float, offsets: Array[float]) -> void:
	for burst_idx in _burst_count:
		# Each burst is a fresh attack: re-aim and spawn from player's current position.
		var player_pos: Vector2 = player.global_position if is_instance_valid(player) else Vector2.ZERO
		var base_direction := _get_aim_direction()
		var perpendicular := base_direction.rotated(PI / 2.0)
		for i in SHARDS_PER_BURST:
			var offset_x: float = perpendicular.x * offsets[i]
			var offset_y: float = perpendicular.y * offsets[i]
			var spawn_pos := player_pos + Vector2(offset_x, offset_y)
			var shard = ice_shards_ability_scene.instantiate()
			shard.direction = base_direction
			shard.damage = damage
			shard.base_damage = damage
			shard.speed = projectile_speed
			shard.duration = projectile_duration
			shard.size_mult = size_mult
			shard.max_hits = 1
			shard.chains_remaining = _chain_count
			shard.last_hit_enemy = null
			shard.chain_range = CHAIN_RANGE
			shard.post_chain_fly_distance = POST_CHAIN_FLY_PX if _infinite_pierce_after_chain else 0.0
			shard.chain_scene = ice_shards_ability_scene
			foreground.add_child(shard)
			shard.global_position = spawn_pos

			_play_dart_sound(spawn_pos)

			if i < SHARDS_PER_BURST - 1 or burst_idx < _burst_count - 1:
				var delay := BURST_DELAY if (i == SHARDS_PER_BURST - 1 and burst_idx < _burst_count - 1) else SHARD_DELAY
				await _wait_unpaused(delay)


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "ice_shards":
		_apply_stats_from_level()
		_apply_attack_speed()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
