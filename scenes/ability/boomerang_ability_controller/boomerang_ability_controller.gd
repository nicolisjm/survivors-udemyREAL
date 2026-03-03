extends Node

@export var boomerang_ability_scene: PackedScene

const MAX_OUTBOUND_DISTANCE := 200.0
const MIN_WAIT_TIME := 0.01
const BASE_WAIT_TIME := 0.6
const BASE_SPEED := 300

var base_damage: int = 1
var base_wait_time: float = BASE_WAIT_TIME
var _knockback_strength: float = 125.0
var _speed_mult: float = 1.0
var _boomerang_count: int = 1
var _timer_started: Array[bool] = [false, false, false, false]

const _TIMER_NAMES: Array[NodePath] = [NodePath("Timer"), NodePath("Timer2"), NodePath("Timer3"), NodePath("Timer4")]

func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")

func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("boomerang") if manager else 0

func _apply_stats_from_level() -> void:
	var level := _get_ability_level()
	# 1: unlock. 2–7: attack rate, speed, knockback. 8: +1 boomerang (2 total). 9: +2 boomerangs (4 total).
	base_wait_time = BASE_WAIT_TIME
	if level >= 2:
		base_wait_time -= 0.2
	if level >= 5:
		base_wait_time -= 0.2
	base_wait_time = clampf(base_wait_time, MIN_WAIT_TIME, 2.0)

	_speed_mult = 1.0
	if level >= 3:
		_speed_mult *= 1.2
	if level >= 6:
		_speed_mult *= 1.2

	var kb_base := 80.0 + level * 15.0
	_knockback_strength = kb_base
	if level >= 4:
		_knockback_strength *= 1.2
	if level >= 7:
		_knockback_strength *= 1.2

	_boomerang_count = 4 if level >= 9 else (2 if level >= 8 else 1)

func _ready() -> void:
	for i in range(_TIMER_NAMES.size()):
		var t: Timer = get_node(_TIMER_NAMES[i])
		t.one_shot = true
		t.timeout.connect(_on_timer_timeout.bind(i))
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	for i in range(_boomerang_count):
		if not _timer_started[i]:
			var t: Timer = get_node(_TIMER_NAMES[i])
			t.wait_time = base_wait_time
			t.start()
			_timer_started[i] = true

func _on_timer_timeout(slot: int) -> void:
	if _get_ability_level() <= 0:
		return
	_spawn_boomerang(slot)

func _spawn_boomerang(slot: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var foreground = get_tree().get_first_node_in_group("foreground_layer") as Node2D
	if foreground == null:
		foreground = get_tree().current_scene
	var boomerang = boomerang_ability_scene.instantiate()
	boomerang.global_position = player.global_position
	boomerang.direction = _get_throw_direction(player, slot)
	boomerang.speed = BASE_SPEED * _speed_mult
	boomerang.max_outbound_distance = MAX_OUTBOUND_DISTANCE
	boomerang.outbound_extra_after_first_hit = 30.0
	var damage_mult: float = player.get("damage_multiplier") if player.get("damage_multiplier") != null else 1.0
	var flat_bonus: int = player.get("damage_flat_bonus") if player.get("damage_flat_bonus") != null else 0
	boomerang.damage = (base_damage + flat_bonus) * damage_mult
	boomerang.knockback_strength = _knockback_strength
	boomerang.collected.connect(_on_boomerang_collected.bind(slot))
	foreground.add_child(boomerang)

func _get_throw_direction(player: Node2D, target_index: int = 0) -> Vector2:
	var raw: Array = get_tree().get_nodes_in_group("enemy")
	var enemies: Array[Node2D] = []
	for e in raw:
		if is_instance_valid(e) and e is Node2D:
			enemies.append(e as Node2D)
	if enemies.is_empty():
		return Vector2.RIGHT
	enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
	)
	var idx: int = min(target_index, enemies.size() - 1)
	return (enemies[idx].global_position - player.global_position).normalized()

func _on_boomerang_collected(slot: int) -> void:
	var t: Timer = get_node(_TIMER_NAMES[slot])
	t.wait_time = base_wait_time
	t.start()

func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "boomerang":
		_apply_stats_from_level()
		for i in range(_timer_started.size()):
			if i < _boomerang_count and not _timer_started[i]:
				var t: Timer = get_node(_TIMER_NAMES[i])
				t.wait_time = base_wait_time
				t.start()
				_timer_started[i] = true
