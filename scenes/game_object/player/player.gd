extends CharacterBody2D

@onready var damage_interval_timer = $DamageIntervalTimer
@onready var health_component = $HealthComponent
@onready var health_bar = $HealthBar
@onready var Abilities = $Abilities
@onready var animation_player = $AnimationPlayer
@onready var visuals = $Visuals
@onready var velocity_component: Node = $VelocityComponent

var num_colliding_bodies = 0
var base_speed = 0
## Last non-zero movement direction (for abilities like ball lightning forward ball).
var last_move_direction: Vector2 = Vector2.RIGHT

## Applied to all ability damage: final_damage = base_damage * damage_multiplier
var damage_multiplier: float = 1.0
## Applied to all ability cooldowns: wait_time = base_wait_time / attack_speed_multiplier (e.g. 1.1 = 10% faster)
var attack_speed_multiplier: float = 1.0
## Applied to ability size, AOE, or range
var size_multiplier: float = 1.0
## Applied to ability duration and debuffs
var duration_multiplier: float = 1.0
## Flat damage added to all ability base damage (generic_flat_damage upgrade).
var damage_flat_bonus: int = 0


func _ready() -> void:
	base_speed = velocity_component.max_speed
	
	$CollisionArea2D.body_entered.connect(_on_collision_entered)
	$CollisionArea2D.body_exited.connect(_on_collision_exited)
	$CollisionArea2D.area_entered.connect(_on_collision_entered)
	$CollisionArea2D.area_exited.connect(_on_collision_exited)
	damage_interval_timer.timeout.connect(on_damage_interval_timer_timeout)
	health_component.health_changed.connect(on_health_changed)
	GameEvents.ability_upgrade_added.connect(on_ability_upgrade_added)
	update_health_display()


func _process(delta: float) -> void:
	var movement_vector = get_movement_vector()
	var direction = movement_vector.normalized()
	velocity_component.accelerate_in_direction(direction)
	velocity_component.move(self)
	
	if movement_vector.x != 0 || movement_vector.y != 0:
		animation_player.play("walk")
		last_move_direction = direction
	else:
		animation_player.play("RESET")
	
	var move_sign = sign(movement_vector.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)


func get_movement_vector():
	if Input.is_action_pressed("left_click"):
		var dir = (get_global_mouse_position() - global_position).normalized()
		if dir.length_squared() > 0.0001:
			return dir
	var x_movement = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y_movement = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return Vector2(x_movement, y_movement)


func update_health_display():
	health_bar.value = health_component.get_health_percent()


func check_deal_damage():
	if num_colliding_bodies == 0 || !(damage_interval_timer.is_stopped()):
		return
	health_component.damage(10)
	damage_interval_timer.start()


func _on_collision_entered(_body_or_area: Node):
	num_colliding_bodies += 1
	check_deal_damage()


func _on_collision_exited(_body_or_area: Node):
	num_colliding_bodies -= 1
	
	
func on_damage_interval_timer_timeout():
	check_deal_damage()
	
	
func on_health_changed(old_health: float, new_health: float) -> void:
	update_health_display()
	if new_health > old_health:
		# Healing: vignette heal animation, health bar heal color flash, health pickup sound
		GameEvents.emit_player_healed()
		$HealthBarAnimationPlayer.play("heal")
		$HealStreamPlayer.play()
	else:
		# Damage: vignette hit, health bar damage flash, damage sound
		GameEvents.emit_player_damaged()
		$HealthBarAnimationPlayer.play("damage")
		$HitRandomStreamPlayer.play_random()
	

func on_ability_upgrade_added(ability_upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	if ability_upgrade is Ability:
		var ability = ability_upgrade as Ability
		Abilities.add_child(ability.ability_controller_scene.instantiate())
	elif ability_upgrade.id == "move_speed":
		velocity_component.max_speed = base_speed + (base_speed * current_upgrades["move_speed"]["quantity"] * 0.1)
	elif ability_upgrade.id == "generic_flat_damage":
		damage_flat_bonus = current_upgrades["generic_flat_damage"]["quantity"]
	elif ability_upgrade.id in ["generic_damage", "generic_damage_prestige", "generic_attack_speed", "generic_attack_speed_prestige", "generic_size", "generic_size_prestige", "generic_duration", "generic_duration_prestige"]:
		_update_generic_multipliers(current_upgrades)


func _update_generic_multipliers(current_upgrades: Dictionary) -> void:
	damage_multiplier = 1.0
	if current_upgrades.has("generic_damage"):
		damage_multiplier += 0.15 * current_upgrades["generic_damage"]["quantity"]
	if current_upgrades.has("generic_damage_prestige"):
		damage_multiplier += 0.05 * current_upgrades["generic_damage_prestige"]["quantity"]

	attack_speed_multiplier = 1.0
	if current_upgrades.has("generic_attack_speed"):
		attack_speed_multiplier += 0.10 * current_upgrades["generic_attack_speed"]["quantity"]
	if current_upgrades.has("generic_attack_speed_prestige"):
		attack_speed_multiplier += 0.03 * current_upgrades["generic_attack_speed_prestige"]["quantity"]

	size_multiplier = 1.0
	if current_upgrades.has("generic_size"):
		size_multiplier += 0.10 * current_upgrades["generic_size"]["quantity"]
	if current_upgrades.has("generic_size_prestige"):
		size_multiplier += 0.03 * current_upgrades["generic_size_prestige"]["quantity"]

	duration_multiplier = 1.0
	if current_upgrades.has("generic_duration"):
		duration_multiplier += 0.10 * current_upgrades["generic_duration"]["quantity"]
	if current_upgrades.has("generic_duration_prestige"):
		duration_multiplier += 0.03 * current_upgrades["generic_duration_prestige"]["quantity"]
		
	
