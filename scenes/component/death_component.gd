extends Node2D

@export var health_component: Node
@export var sprite: Sprite2D

func _ready() -> void:
	if sprite and sprite.texture:
		$GPUParticles2D.texture = sprite.texture
	if health_component is HealthComponent:
		(health_component as HealthComponent).died.connect(on_died)
	
	
func on_died(_killer_source: Variant = null) -> void:
	if owner == null || not owner is Node2D:
		return
	
	var spawn_position = owner.global_position
	
	var entities = get_tree().get_first_node_in_group("entities_layer")
	get_parent().remove_child(self)
	entities.add_child(self)
	
	global_position = spawn_position
	$AnimationPlayer.play("default")
	$HitRandomAudioPlayerComponent.play_random()
	
