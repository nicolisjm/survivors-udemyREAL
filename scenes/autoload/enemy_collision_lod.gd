extends Node
## Disables collision for enemies far from the player so the physics engine has fewer
## active shapes in the broad-phase. Re-enables when they come back in range.
## No gameplay change: off-screen enemies don't need to collide with the player or hitboxes.

const LOD_DISTANCE: float = 300.0
const LOD_DISTANCE_SQ: float = LOD_DISTANCE * LOD_DISTANCE

const ENEMY_LAYER: int = 8


func _process(_delta: float) -> void:
	var tree := get_tree()
	var player: Node2D = tree.get_first_node_in_group("player") as Node2D
	if not player or not is_instance_valid(player):
		return
	var player_pos: Vector2 = player.global_position
	var enemies: Array = tree.get_nodes_in_group("enemy")
	for node in enemies:
		if not is_instance_valid(node):
			continue
		var enemy := node as Node2D
		# Breakables must always have monitorable=true so HitboxComponent can detect them
		if enemy.is_in_group("breakable"):
			var hurtbox: Area2D = enemy.get_node_or_null("HurtboxComponent") as Area2D
			if hurtbox:
				hurtbox.monitorable = true
			continue
		var dist_sq: float = enemy.global_position.distance_squared_to(player_pos)
		var in_range: bool = dist_sq <= LOD_DISTANCE_SQ
		if enemy is Area2D:
			(enemy as Area2D).collision_layer = ENEMY_LAYER if in_range else 0
		var hurtbox: Area2D = enemy.get_node_or_null("HurtboxComponent") as Area2D
		if hurtbox:
			hurtbox.monitorable = in_range
