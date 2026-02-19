extends Node2D
## Heals the player on pickup. Uses same pick-up animation as experience orbs.

var heal_amount: float = 30.0

const HEALTH_BAR_COLOR := Color(0.2627451, 0.88235295, 0.7019608, 1)
const FLOATING_TEXT_SCENE := preload("res://scenes/UI/floating_text.tscn")

@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var visual: Node2D = $Visual


func _ready() -> void:
	$Area2D.area_entered.connect(on_area_entered)


func disable_collision() -> void:
	collision_shape_2d.disabled = true


func tween_collect(percent: float, start_position: Vector2) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	global_position = start_position.lerp(player.global_position, percent)


func on_area_entered(other_area: Area2D) -> void:
	Callable(disable_collision).call_deferred()

	var tween = create_tween()
	tween.set_parallel()
	tween.tween_method(tween_collect.bind(global_position), 0.0, 1.0, 0.5)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(visual, "scale", Vector2.ZERO, 0.07).set_delay(0.43)
	tween.chain()
	tween.tween_callback(collect)


func collect() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var health = player.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.heal(heal_amount)
			print("[HealthPotion] Healed %.0f HP (player now %.0f/%.0f)" % [heal_amount, health.current_health, health.max_health])
			var foreground = get_tree().get_first_node_in_group("foreground_layer")
			if foreground:
				var floating_text = FLOATING_TEXT_SCENE.instantiate() as Node2D
				foreground.add_child(floating_text)
				floating_text.global_position = global_position + (Vector2.UP * 16)
				floating_text.start("%0.0f" % heal_amount, false, HEALTH_BAR_COLOR)
	queue_free()
