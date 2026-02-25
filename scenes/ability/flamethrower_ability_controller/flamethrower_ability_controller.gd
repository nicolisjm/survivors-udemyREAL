extends Node

@export var flamethrower_ability_scene: PackedScene

const BURNABLE_COMPONENT_SCENE := preload("res://scenes/component/burnable_component.tscn")

const BASE_TICK_RATE := 0.2
const MIN_TICK_INTERVAL := 0.05
const BURN_DAMAGE_PER_TICK_RATE_UPGRADE := 1
## Base damage per burn tick; levels 3/5/8 add +2 burn damage each.
const BASE_BURN_DAMAGE_PER_TICK := 4.0
const BURN_DURATION_BASE := 3.0
## Offset in pixels so the flame cone starts in front of the character.
const FLAME_OFFSET_PIXELS := 8
## Vertical offset (up = negative Y) so the flame aligns with the character.
const FLAME_OFFSET_UP_PIXELS := -6.0
## Level 8: range for spreading burn to nearby enemies when a burning enemy dies (~experience orb pickup).
const BURN_SPREAD_ON_DEATH_RANGE := 40

var _flamethrower_visual: Node2D = null

# From upgrades
var _burn_damage_bonus: int = 0
var _base_particle_amount: int = 60
var _spread_value: float = 2.0
var _burn_tick_interval_base: float = 1.0
## Level 9 upgrade disabled for now; leave in game for later.
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
	# Level 8: burn spread on death instead of spread 24

	_burn_tick_interval_base = 1.0
	if level >= 4:
		_burn_tick_interval_base = 0.8
	if level >= 7:
		_burn_tick_interval_base = 0.6

	# Level 9: 1% of burning enemy's health as base damage to that burn.
	_burn_refreshes_on_hit = level >= 9


func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	GameEvents.ability_upgrade_added.connect(_on_ability_upgrade_added)
	GameEvents.burning_enemy_died.connect(_on_burning_enemy_died)
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
	if player == null:
		return
	var damage_mult: float = player.get("damage_multiplier") if player.get("damage_multiplier") != null else 1.0
	var duration_mult: float = player.get("duration_multiplier") if player.get("duration_multiplier") != null else 1.0
	var attack_speed: float = player.get("attack_speed_multiplier") if player.get("attack_speed_multiplier") != null else 1.0
	if attack_speed <= 0.0:
		attack_speed = 1.0
	var burn_tick_interval: float = _burn_tick_interval_base / attack_speed

	var overlapping: Array = hitbox.get_overlapping_areas()
	for area in overlapping:
		if not area is HurtboxComponent:
			continue
		var target: Node = area.get_parent()
		if not is_instance_valid(target):
			continue
		_apply_burn_to_target(target, damage_mult, duration_mult, attack_speed, burn_tick_interval)


func _on_flamethrower_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var target: Node = area.get_parent()
	if not is_instance_valid(target):
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
	_apply_burn_to_target(target, damage_mult, duration_mult, attack_speed, burn_tick_interval)


func _on_burning_enemy_died(position: Vector2) -> void:
	if _get_ability_level() < 8:
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
	var range_sq: float = BURN_SPREAD_ON_DEATH_RANGE * BURN_SPREAD_ON_DEATH_RANGE
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	for node in enemies:
		if not node is Node2D:
			continue
		var enemy: Node2D = node as Node2D
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_squared_to(position) > range_sq:
			continue
		var burnable: Node = enemy.get_node_or_null("BurnableComponent")
		if burnable != null and burnable.has_method("is_burning") and burnable.is_burning():
			continue
		_apply_burn_to_target(enemy, damage_mult, duration_mult, attack_speed, burn_tick_interval)


func _apply_burn_to_target(target: Node, damage_mult: float, duration_mult: float, attack_speed: float, burn_tick_interval: float) -> void:
	var burnable: Node = target.get_node_or_null("BurnableComponent")
	if burnable == null:
		burnable = BURNABLE_COMPONENT_SCENE.instantiate()
		target.add_child(burnable)
	if burnable.has_method("apply_burn"):
		var base_damage: float = BASE_BURN_DAMAGE_PER_TICK + float(_burn_damage_bonus)
		if _burn_refreshes_on_hit:
			var hc: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
			if hc != null:
				base_damage += 0.01 * hc.max_health
		burnable.apply_burn(
			base_damage,
			BURN_DURATION_BASE,
			burn_tick_interval,
			damage_mult,
			duration_mult,
			_burn_refreshes_on_hit
		)


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
