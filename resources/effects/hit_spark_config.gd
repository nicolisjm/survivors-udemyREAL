extends Resource
class_name HitSparkConfig

## Configurable hit spark effect used by HurtboxComponent (and any ability that calls apply_damage with a config).
## Create .tres variants per ability (e.g. chain_lightning_sparks.tres, sword_sparks.tres) and assign or pass when dealing damage.

@export var color: Color = Color(0.9, 0.95, 1, 0.9)
@export var amount: int = 10
@export var lifetime: float = 0.2
@export var explosiveness: float = 1.0
@export var direction: Vector2 = Vector2(0, -1)
@export var spread: float = 180.0
@export var initial_velocity_min: float = 20.0
@export var initial_velocity_max: float = 60.0
@export var gravity: Vector2 = Vector2(0, 80)
@export var scale_min: float = 2.0
@export var scale_max: float = 4.0
