extends CanvasLayer


func _ready() -> void:
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.player_healed.connect(_on_player_healed)


func _on_player_damaged() -> void:
	$AnimationPlayer.play("hit")


func _on_player_healed() -> void:
	$AnimationPlayer.play("heal")
