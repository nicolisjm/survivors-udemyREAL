extends Node

@export_range(0, 1) var drop_percent: float = .5
@export_range(0, 10) var amount: float = 1
@export var health_component: Node
@export var vial_scene: PackedScene



func _ready() -> void:
	(health_component as HealthComponent).died.connect(on_died)


func on_died(_killer_source: Variant = null) -> void:
	if randf() > drop_percent:
		return
	
	if vial_scene == null:
		return
	
	if not owner is Node2D:
		return
	
	var spawn_position = (owner as Node2D).global_position
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")

	var vial_instance = vial_scene.instantiate() as Node2D
	if "experience_value" in vial_instance:
		vial_instance.experience_value = amount
	entities_layer.add_child(vial_instance)
	vial_instance.global_position = spawn_position
