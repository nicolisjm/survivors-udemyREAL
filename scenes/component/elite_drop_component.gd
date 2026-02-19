extends Node
## Drops items for elite enemies. Pre-10min: always chest + XP; post-10min: roll for chest.
## Can drop multiple items (unlike breakables).

@export var health_component: Node
@export var arena_time_manager: Node
@export var base_vial_amount: float = 1.0

var experience_vial_scene: PackedScene = preload("res://scenes/game_object/experience_vial/experience_vial.tscn")
var health_vial_scene: PackedScene = preload("res://scenes/game_object/item/health_vial.tscn")
var health_potion_scene: PackedScene = preload("res://scenes/game_object/item/health_potion.tscn")
var black_hole_scene: PackedScene = preload("res://scenes/game_object/item/black_hole.tscn")
var chest_scene: PackedScene = preload("res://scenes/game_object/item/chest.tscn")

const DROP_CHANCE_XP := 0.15
const DROP_CHANCE_HEALTH_VIAL := 0.05
const DROP_CHANCE_HEALTH_POTION := 0.02
const DROP_CHANCE_BLACK_HOLE := 0.01
const POST_10_CHEST_CHANCE := 0.005  # 1 in 200 for chest only; post-10min elites drop no other items


func _ready() -> void:
	if health_component is HealthComponent:
		(health_component as HealthComponent).died.connect(on_died)


func _is_pre_10_min() -> bool:
	if arena_time_manager == null:
		return true
	if arena_time_manager.has_method("get_time_elapsed"):
		return arena_time_manager.get_time_elapsed() < 600.0  # 10 min
	return true


func on_died(_killer_source: Variant = null) -> void:
	# Use get_parent(): we're added as child of the enemy; owner can be null for instanced nodes
	var enemy = get_parent()
	if not enemy is Node2D:
		return
	var spawn_position = (enemy as Node2D).global_position
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	if entities_layer == null:
		return

	var is_pre_10 = _is_pre_10_min()

	if is_pre_10:
		# Pre-10min: always XP + chest + extra item rolls
		var xp_amount = (base_vial_amount + 1.0) * 2.0
		var xp_vial = experience_vial_scene.instantiate() as Node2D
		entities_layer.add_child(xp_vial)
		xp_vial.global_position = spawn_position
		if "experience_value" in xp_vial:
			xp_vial.experience_value = xp_amount

		if chest_scene:
			var chest = chest_scene.instantiate() as Node2D
			entities_layer.add_child(chest)
			chest.global_position = spawn_position + Vector2(randf_range(-8, 8), 0)

		_try_drop_item(entities_layer, spawn_position, DROP_CHANCE_BLACK_HOLE, black_hole_scene, {})
		_try_drop_item(entities_layer, spawn_position, DROP_CHANCE_HEALTH_POTION, health_potion_scene, {"heal_amount": 30})
		_try_drop_item(entities_layer, spawn_position, DROP_CHANCE_HEALTH_VIAL, health_vial_scene, {"heal_amount": 10})
		_try_drop_item(entities_layer, spawn_position, DROP_CHANCE_XP, experience_vial_scene, {"experience_value": 1.0})
	else:
		# Post-10min: no XP, no other items; only 1-in-200 chance for chest
		if randf() < POST_10_CHEST_CHANCE and chest_scene:
			var chest = chest_scene.instantiate() as Node2D
			entities_layer.add_child(chest)
			chest.global_position = spawn_position + Vector2(randf_range(-8, 8), 0)


func _try_drop_item(entities_layer: Node, spawn_position: Vector2, chance: float, scene: PackedScene, params: Dictionary) -> void:
	if scene == null or randf() >= chance:
		return
	var instance = scene.instantiate() as Node2D
	entities_layer.add_child(instance)
	instance.global_position = spawn_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
	for key in params:
		if key in instance:
			instance.set(key, params[key])
