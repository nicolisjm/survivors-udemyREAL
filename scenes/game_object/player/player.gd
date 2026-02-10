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

## Applied to all ability damage: final_damage = base_damage * damage_multiplier
var damage_multiplier: float = 1.0
## Applied to all ability cooldowns: wait_time = base_wait_time / attack_speed_multiplier (e.g. 1.1 = 10% faster)
var attack_speed_multiplier: float = 1.0


func _ready() -> void:
	base_speed = velocity_component.max_speed
	
	$CollisionArea2D.body_entered.connect(on_body_entered)
	$CollisionArea2D.body_exited.connect(on_body_exited)
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
	else:
		animation_player.play("RESET")
	
	var move_sign = sign(movement_vector.x)
	if move_sign != 0:
		visuals.scale = Vector2(move_sign, 1)


func get_movement_vector():
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
	print(health_component.current_health)


func on_body_entered(other_body: Node2D):
	num_colliding_bodies += 1
	check_deal_damage()


func on_body_exited(other_body: Node2D):
	num_colliding_bodies -= 1
	
	
func on_damage_interval_timer_timeout():
	check_deal_damage()
	
	
func on_health_changed():
	GameEvents.emit_player_damaged()
	update_health_display()
	$HealthBarAnimationPlayer.play("damage")
	$HitRandomStreamPlayer.play_random()
	

func on_ability_upgrade_added(ability_upgrade: AbilityUpgrade, current_upgrades: Dictionary):
	if ability_upgrade is Ability:
		var ability = ability_upgrade as Ability
		Abilities.add_child(ability.ability_controller_scene.instantiate())
	elif ability_upgrade.id == "move_speed":
		velocity_component.max_speed = base_speed + (base_speed * current_upgrades["move_speed"]["quantity"] * 0.1)
	elif ability_upgrade.id in ["generic_damage_10", "generic_damage_20", "generic_damage_30", "generic_attack_speed_10", "generic_attack_speed_20", "generic_attack_speed_30"]:
		_update_generic_multipliers(current_upgrades)


func _update_generic_multipliers(current_upgrades: Dictionary) -> void:
	damage_multiplier = 1.0
	if current_upgrades.has("generic_damage_10"):
		damage_multiplier += 0.10 * current_upgrades["generic_damage_10"]["quantity"]
	if current_upgrades.has("generic_damage_20"):
		damage_multiplier += 0.20 * current_upgrades["generic_damage_20"]["quantity"]
	if current_upgrades.has("generic_damage_30"):
		damage_multiplier += 0.30 * current_upgrades["generic_damage_30"]["quantity"]

	attack_speed_multiplier = 1.0
	if current_upgrades.has("generic_attack_speed_10"):
		attack_speed_multiplier += 0.10 * current_upgrades["generic_attack_speed_10"]["quantity"]
	if current_upgrades.has("generic_attack_speed_20"):
		attack_speed_multiplier += 0.20 * current_upgrades["generic_attack_speed_20"]["quantity"]
	if current_upgrades.has("generic_attack_speed_30"):
		attack_speed_multiplier += 0.30 * current_upgrades["generic_attack_speed_30"]["quantity"]
		
	
