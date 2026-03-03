extends Node2D

@onready var hitbox_component: HitboxComponent = $HitboxComponent

## Set by spawner. Direction of travel (normalized).
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 2.0
var knockback_strength: float = 50.0
## Radians per second.
var spin_speed: float = 15.0
## Pixels outside visible rect to allow before queue_free.
const OFF_SCREEN_MARGIN := 80.0

var _hit_ids: Dictionary = {}


func _ready() -> void:
	hitbox_component.damage = 0
	hitbox_component.knockback_strength = 0
	hitbox_component.collision_mask = 32
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)


func _process(delta: float) -> void:
	rotation += spin_speed * delta
	global_position += direction * speed * delta
	var rect := get_viewport().get_visible_rect()
	rect = rect.grow(OFF_SCREEN_MARGIN)
	if not rect.has_point(global_position):
		queue_free()


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	var id := hurtbox.get_instance_id()
	if _hit_ids.get(id, false):
		return
	_hit_ids[id] = true
	var spark_config = hitbox_component.hit_spark_config if hitbox_component.hit_spark_config else null
	var knockback_impulse := (hurtbox.global_position - global_position).normalized() * knockback_strength
	hurtbox.apply_damage(damage, spark_config, 0.0, null, hitbox_component.is_crit, null, -12.0, 0.0, 0.0, null, knockback_impulse)
