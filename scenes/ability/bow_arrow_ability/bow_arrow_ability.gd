extends Node2D

@onready var hitbox_component: HitboxComponent = $HitboxComponent

## Set by controller before add_child. Normalized direction of travel.
var direction: Vector2 = Vector2.RIGHT
## Damage applied per hit (set by controller before add_child).
var damage: float = 0.0
## Max enemies this arrow can hit before being removed (pierce 0 = 1 hit, pierce 2 = 3 hits).
var max_hits: int = 1
## Pixels per second.
var speed: float = 500.0
## Seconds before arrow is removed (pierces until then).
var duration: float = 1.5
## Scale for sprite and hitbox (e.g. from size_multiplier).
var size_mult: float = 1.0

var _lifetime: float = 0.0
var _hit_count: int = 0
var _hit_hurtbox_ids: Dictionary = {}  # instance_id -> true, so we count each enemy once


func _ready() -> void:
	# + PI so the tip points in direction of travel (sprite is drawn tip-left by default).
	rotation = direction.angle() + PI
	scale = Vector2.ONE * size_mult
	hitbox_component.damage = damage
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var id := area.get_instance_id()
	if _hit_hurtbox_ids.get(id, false):
		return
	_hit_hurtbox_ids[id] = true
	_hit_count += 1
	if _hit_count >= max_hits:
		queue_free()


func _process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime += delta
	if _lifetime >= duration:
		queue_free()
