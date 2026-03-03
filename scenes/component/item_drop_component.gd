extends Node
## Drops at most one item when the owner dies. Used by breakables.
## Drop rates: XP 15%, health vial 5%, health potion 2%, black hole 1%.
## TESTING: health vial, potion, black hole set to 33% each for verification.

@export var health_component: Node

var experience_vial_scene: PackedScene = preload("res://scenes/game_object/experience_vial/experience_vial.tscn")
var health_vial_scene: PackedScene = preload("res://scenes/game_object/item/health_vial.tscn")
var health_potion_scene: PackedScene = preload("res://scenes/game_object/item/health_potion.tscn")
var black_hole_scene: PackedScene = preload("res://scenes/game_object/item/black_hole.tscn")

const DROP_CHANCE_XP := 0.01  # Low for testing
const DROP_CHANCE_HEALTH_VIAL := 0.50
const DROP_CHANCE_HEALTH_POTION := 0.25
const DROP_CHANCE_BLACK_HOLE := 0.25


func _ready() -> void:
	var health = health_component as HealthComponent
	if health == null and owner:
		health = owner.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.died.connect(on_died)


func on_died(_killer_source: Variant = null) -> void:
	if not owner is Node2D:
		return
	print("[ItemDrop] Breakable %s destroyed at %s" % [owner.name, (owner as Node2D).global_position])

	var roll := randf()
	var spawn_scene: PackedScene = null
	var spawn_params: Dictionary = {}

	if roll < DROP_CHANCE_BLACK_HOLE and black_hole_scene:
		spawn_scene = black_hole_scene
	elif roll < DROP_CHANCE_BLACK_HOLE + DROP_CHANCE_HEALTH_POTION and health_potion_scene:
		spawn_scene = health_potion_scene
		spawn_params["heal_amount"] = 30
	elif roll < DROP_CHANCE_BLACK_HOLE + DROP_CHANCE_HEALTH_POTION + DROP_CHANCE_HEALTH_VIAL and health_vial_scene:
		spawn_scene = health_vial_scene
		spawn_params["heal_amount"] = 10
	elif roll < DROP_CHANCE_BLACK_HOLE + DROP_CHANCE_HEALTH_POTION + DROP_CHANCE_HEALTH_VIAL + DROP_CHANCE_XP and experience_vial_scene:
		spawn_scene = experience_vial_scene
		spawn_params["experience_value"] = 1.0

	if spawn_scene == null:
		print("[ItemDrop] Breakable %s no drop (roll %.3f)" % [owner.name, roll])
		return

	var spawn_position = (owner as Node2D).global_position
	var entities_layer = get_tree().get_first_node_in_group("entities_layer")
	if entities_layer == null:
		return

	var instance = spawn_scene.instantiate() as Node2D
	entities_layer.add_child(instance)
	instance.global_position = spawn_position

	for key in spawn_params:
		if key in instance:
			instance.set(key, spawn_params[key])
	print("[ItemDrop] Breakable %s dropped %s (roll %.3f)" % [owner.name, instance.name, roll])
