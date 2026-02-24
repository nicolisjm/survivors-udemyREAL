extends Node

@export var flamethrower_ability_scene: PackedScene

const BURNABLE_COMPONENT_SCENE := preload("res://scenes/component/burnable_component.tscn")

const BASE_TICK_RATE := 0.2
const MIN_TICK_INTERVAL := 0.05
const BURN_DAMAGE_PER_TICK_RATE_UPGRADE := 2
const FLAMETHROWER_BASE_DAMAGE := 2
## Base damage per burn tick; levels 2/5/8 add +2 burn damage each instead of faster tick rate.
const BASE_BURN_DAMAGE_PER_TICK := 5.0
const BURN_DURATION_BASE := 3.0
const BURN_TICK_WINDOW := 4.0
const TICKS_TO_APPLY_BURN := 3
## Offset in pixels so the flame cone starts in front of the character.
const FLAME_OFFSET_PIXELS := 8
## Vertical offset (up = negative Y) so the flame aligns with the character.
const FLAME_OFFSET_UP_PIXELS := -6.0

var _flamethrower_visual: Node2D = null
var _target_tick_data: Dictionary = {}  # Node -> { tick_count: int, last_tick_time: float }
var _target_enter_cooldown: Dictionary = {}  # instance_id -> last_apply_time (enter-hit cooldown = tick interval)

# From upgrades
var _burn_damage_bonus: int = 0
var _base_particle_amount: int = 60
var _spread_value: float = 2.0
var _burn_tick_interval_base: float = 1.0
var _burn_refreshes_on_hit: bool = false


func _get_upgrade_manager() -> Node:
	return get_tree().get_first_node_in_group("upgrade_manager")


func _get_ability_level() -> int:
	var manager = _get_upgrade_manager()
	return manager.get_ability_level("flamethrower") if manager else 0


## Level 1=unlock. 2: spread 6. 3: +2 burn damage, pixels ×2. 4: burn rate -0.2. 5: +2 burn damage, pixels ×1.5. 6: spread 12. 7: burn rate -0.2. 8: +2 burn damage, pixels ×1.5 & spread 24. 9: burn refresh + added damage on burned.
func _apply_stats_from_level() -> void:
	var level: int = _get_ability_level()
	_burn_damage_bonus = 0
	if level >= 3:
		_burn_damage_bonus += BURN_DAMAGE_PER_TICK_RATE_UPGRADE
	if level >= 5:
		_burn_damage_bonus += BURN_DAMAGE_PER_TICK_RATE_UPGRADE
	if level >= 8:
		_burn_damage_bonus += BURN_DAMAGE_PER_TICK_RATE_UPGRADE

	_base_particle_amount = 60
	if level >= 3:
		_base_particle_amount = 120
	if level >= 5:
		_base_particle_amount = 150
	if level >= 8:
		_base_particle_amount = 210

	_spread_value = 2.0
	if level >= 2:
		_spread_value = 6.0
	if level >= 6:
		_spread_value = 12.0
	if level >= 8:
		_spread_value = 24.0

	_burn_tick_interval_base = 1.0
	if level >= 4:
		_burn_tick_interval_base = 0.8
	if level >= 7:
		_burn_tick_interval_base = 0.6

	_burn_refreshes_on_hit = level >= 9


func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	_apply_stats_from_level()
	_apply_attack_speed()
	_ensure_visual()


func _process(_delta: float) -> void:
	if _flamethrower_visual == null:
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_flamethrower_visual.global_position = player.global_position + player.last_move_direction * FLAME_OFFSET_PIXELS + Vector2(0, FLAME_OFFSET_UP_PIXELS)
	_flamethrower_visual.rotation = player.last_move_direction.angle()


func _ensure_visual() -> void:
	var level: int = _get_ability_level()
	if level <= 0:
		if _flamethrower_visual != null:
			_flamethrower_visual.queue_free()
			_flamethrower_visual = null
		return
	if _flamethrower_visual != null:
		_apply_parameters_to_visual()
		return
	var player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var visual = flamethrower_ability_scene.instantiate() as Node2D
	player.add_child(visual)
	_flamethrower_visual = visual
	var hitbox: HitboxComponent = _flamethrower_visual.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox != null:
		hitbox.area_entered.connect(_on_flamethrower_hitbox_area_entered)
	_apply_parameters_to_visual()


func _apply_parameters_to_visual() -> void:
	if _flamethrower_visual == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var attack_speed: float = player.get("attack_speed_multiplier") if player.get("attack_speed_multiplier") != null else 1.0
	var duration_mult: float = player.get("duration_multiplier") if player.get("duration_multiplier") != null else 1.0
	var size_mult: float = player.get("size_multiplier") if player.get("size_multiplier") != null else 1.0
	if attack_speed <= 0.0:
		attack_speed = 1.0
	# Spread value (2,6,12,24) -> cone angle; initial mapping (tune in editor).
	var cone_angle: float = 15.0 + (_spread_value - 2.0) * 3.0  # 2->15, 6->27, 12->45, 24->81
	if _flamethrower_visual.has_method("apply_parameters"):
		_flamethrower_visual.apply_parameters(
			_base_particle_amount,
			attack_speed,
			cone_angle,
			duration_mult,
			size_mult
		)
	$Timer.wait_time = max(BASE_TICK_RATE / attack_speed, MIN_TICK_INTERVAL)
	$Timer.start()


func _apply_attack_speed() -> void:
	_apply_parameters_to_visual()


func _on_timer_timeout() -> void:
	if _get_ability_level() <= 0:
		return
	if _flamethrower_visual == null:
		_ensure_visual()
		return
	var hitbox: HitboxComponent = _flamethrower_visual.get_node_or_null("HitboxComponent") as HitboxComponent
	if hitbox == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	var damage_mult: float = player.get("damage_multiplier") if player and player.get("damage_multiplier") != null else 1.0
	var duration_mult: float = player.get("duration_multiplier") if player and player.get("duration_multiplier") != null else 1.0
	var attack_speed: float = player.get("attack_speed_multiplier") if player and player.get("attack_speed_multiplier") != null else 1.0
	if attack_speed <= 0.0:
		attack_speed = 1.0
	var now: float = Time.get_ticks_msec() / 1000.0
	var burn_tick_interval: float = _burn_tick_interval_base / attack_speed
	var burn_damage_per_tick: float = (BASE_BURN_DAMAGE_PER_TICK + float(_burn_damage_bonus)) * damage_mult

	var tick_interval: float = $Timer.wait_time
	var overlapping: Array = hitbox.get_overlapping_areas()
	for area in overlapping:
		if not area is HurtboxComponent:
			continue
		var target: Node = area.get_parent()
		if not is_instance_valid(target):
			continue
		# Skip tick if this target was just hit by enter (avoids double hit within one tick window).
		var key := target.get_instance_id()
		if _target_enter_cooldown.get(key, -999.0) + tick_interval > now:
			continue
		_apply_one_tick_to_target(target, area as HurtboxComponent, now, damage_mult, duration_mult, attack_speed, burn_tick_interval, burn_damage_per_tick)

	_prune_tick_data()


## Applies one tick of damage and burn buildup to a single target. Used by both timer and enter-hit.
func _apply_one_tick_to_target(
	target: Node,
	hurtbox: HurtboxComponent,
	now: float,
	damage_mult: float,
	duration_mult: float,
	attack_speed: float,
	burn_tick_interval: float,
	burn_damage_per_tick: float
) -> void:
	var tick_damage: float = float(FLAMETHROWER_BASE_DAMAGE) * damage_mult
	var burnable: Node = target.get_node_or_null("BurnableComponent")
	if burnable != null and burnable.has_method("is_burning") and burnable.is_burning() and _burn_refreshes_on_hit:
		tick_damage += burn_damage_per_tick
	hurtbox.apply_damage(tick_damage)

	var key := target.get_instance_id()
	var data: Dictionary = _target_tick_data.get(key, { "tick_count": 0, "last_tick_time": 0.0 })
	if now - data.last_tick_time > BURN_TICK_WINDOW:
		data.tick_count = 0
	data.tick_count += 1
	data.last_tick_time = now
	_target_tick_data[key] = data

	if data.tick_count >= TICKS_TO_APPLY_BURN:
		data.tick_count = 0
		_target_tick_data[key] = data
		_apply_burn_to_target(target, damage_mult, duration_mult, attack_speed, burn_tick_interval)


func _on_flamethrower_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var target: Node = area.get_parent()
	if not is_instance_valid(target):
		return
	var tick_interval: float = $Timer.wait_time
	var now: float = Time.get_ticks_msec() / 1000.0
	var key := target.get_instance_id()
	if _target_enter_cooldown.get(key, -999.0) + tick_interval > now:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var damage_mult: float = player.get("damage_multiplier") if player.get("damage_multiplier") != null else 1.0
	var duration_mult: float = player.get("duration_multiplier") if player.get("duration_multiplier") != null else 1.0
	var attack_speed: float = player.get("attack_speed_multiplier") if player.get("attack_speed_multiplier") != null else 1.0
	if attack_speed <= 0.0:
		attack_speed = 1.0
	var burn_tick_interval: float = _burn_tick_interval_base / attack_speed
	var burn_damage_per_tick: float = (BASE_BURN_DAMAGE_PER_TICK + float(_burn_damage_bonus)) * damage_mult
	_apply_one_tick_to_target(target, area as HurtboxComponent, now, damage_mult, duration_mult, attack_speed, burn_tick_interval, burn_damage_per_tick)
	_target_enter_cooldown[key] = now


func _apply_burn_to_target(target: Node, damage_mult: float, duration_mult: float, attack_speed: float, burn_tick_interval: float) -> void:
	var burnable: Node = target.get_node_or_null("BurnableComponent")
	if burnable == null:
		burnable = BURNABLE_COMPONENT_SCENE.instantiate()
		target.add_child(burnable)
	if burnable.has_method("apply_burn"):
		# Base damage per tick (5) + bonus from levels 2/5/8 (+2 each).
		burnable.apply_burn(
			BASE_BURN_DAMAGE_PER_TICK + float(_burn_damage_bonus),
			BURN_DURATION_BASE,
			burn_tick_interval,
			damage_mult,
			duration_mult,
			_burn_refreshes_on_hit
		)


func _prune_tick_data() -> void:
	var to_erase: Array = []
	for key in _target_tick_data:
		var node: Object = instance_from_id(key)
		if node == null or not is_instance_valid(node):
			to_erase.append(key)
	for k in to_erase:
		_target_tick_data.erase(k)
		_target_enter_cooldown.erase(k)


func _on_ability_upgrade_added(upgrade: AbilityUpgrade, _current: Dictionary) -> void:
	if upgrade.ability_id == "flamethrower":
		_apply_stats_from_level()
		_apply_attack_speed()
		_ensure_visual()
	elif upgrade.id in ["generic_attack_speed", "generic_attack_speed_prestige"]:
		_apply_attack_speed()
	elif upgrade.id in ["generic_damage", "generic_damage_prestige"]:
		pass
	elif upgrade.id in ["generic_size", "generic_size_prestige", "generic_duration", "generic_duration_prestige"]:
		_apply_parameters_to_visual()
