extends Node
class_name HealthComponent

signal died(killer_source)
signal health_changed(old_health: float, new_health: float)

@export var max_health: float = 10

var current_health: float
var _last_damage_source: Variant = null
var _has_emitted_died := false


func _ready() -> void:
	current_health = max_health


func damage(damage_amount: float, source: Variant = null) -> void:
	_last_damage_source = source
	var old_health: float = current_health
	current_health = max(current_health - damage_amount, 0)
	health_changed.emit(old_health, current_health)
	Callable(check_death).call_deferred()


func heal(amount: float) -> void:
	var old_health: float = current_health
	current_health = min(current_health + amount, max_health)
	health_changed.emit(old_health, current_health)


func get_health_percent():
	if max_health <= 0:
		return 0
	return min(current_health / max_health, 1)


func check_death() -> void:
	if current_health != 0:
		return
	if _has_emitted_died:
		return
	_has_emitted_died = true
	died.emit(_last_damage_source)
	owner.queue_free()
