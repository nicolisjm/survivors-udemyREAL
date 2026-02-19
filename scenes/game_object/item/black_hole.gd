extends Node2D
## Black orb with particles swirling in. On pickup: sucks all experience orbs to the player.

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
	var orb_count = get_tree().get_nodes_in_group("experience_vial").size()
	print("[BlackHole] Activated - sucking %d XP orbs to player" % orb_count)
	GameEvents.emit_black_hole_activated()
	queue_free()
