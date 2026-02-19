extends Node2D
## Free upgrade selection without level-up. Stays still (no pickup tween), gold particles from open chest.

@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D


func _ready() -> void:
	$Area2D.area_entered.connect(on_area_entered)


func on_area_entered(_other_area: Area2D) -> void:
	# Defer: cannot change collision/monitoring state while physics is flushing queries
	call_deferred("_deferred_collect")


func _deferred_collect() -> void:
	if not is_instance_valid(collision_shape_2d) or collision_shape_2d.disabled:
		return
	collision_shape_2d.disabled = true
	collect()


func collect() -> void:
	var pickup_sound: AudioStreamPlayer = $PickupSound
	pickup_sound.reparent(get_tree().root)
	# Play while upgrade screen pauses the tree
	pickup_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	pickup_sound.finished.connect(pickup_sound.queue_free)
	pickup_sound.play()

	var upgrade_manager = get_tree().get_first_node_in_group("upgrade_manager") as UpgradeManager
	if upgrade_manager:
		print("[Chest] Opening free upgrade selection")
		upgrade_manager.show_free_upgrade_selection()
	queue_free()
