extends Node2D

## Flamethrower visual + hitbox. Fires continuously while in the tree; controller owns when to add/remove.
##
## Design:
## - Tick-based damage (like ball lightning): controller runs a timer and applies damage to enemies in cone each tick.
## - Generic attack speed: shortens tick interval (more damage ticks/s) and multiplies particle amount (intensity).
## - Main ability upgrades: affect base tick rate and BASE particle amount per level.
## - Particle amount = base_amount_from_upgrades * attack_speed_multiplier (so attack speed feels like intensity).
## - Size / duration / spread upgrades: applied here via apply_parameters(); keep hitbox and particles in sync.

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var flame_particles: GPUParticles2D = $FlameParticles

## Base values from scene (controller overrides at runtime via apply_parameters).
var _base_particle_amount: int = 120
var _base_lifetime: float = 0.2
var _base_cone_angle: float = 90.0
## Base length (tip x); from scene polygon points 2/3.
var _base_length: float = 65.0
## Nozzle half-width (points 0/1 y); from scene.
var _base_nozzle_half_width: float = 3.0
## Minimum half-width at tip when spread is 0 (keeps beam a thin strip).
const MIN_TIP_HALF_WIDTH: float = 0.5
## Scale the whole cone/particles/hitbox so the ability is visibly large (controller uses timer for damage).
const SIZE_SCALE: float = 2

func _ready() -> void:
	_base_particle_amount = flame_particles.amount
	_base_lifetime = flame_particles.lifetime
	if flame_particles.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = flame_particles.process_material as ParticleProcessMaterial
		_base_cone_angle = mat.emission_ring_cone_angle
	var col: CollisionPolygon2D = hitbox_component.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if col and col.polygon.size() >= 4:
		# Points 0,1 = nozzle (x=0), points 2,3 = tip (x=length). Winding: 0 top-left, 1 bottom-left, 2 bottom-right, 3 top-right.
		_base_nozzle_half_width = absf(col.polygon[0].y)
		_base_length = col.polygon[2].x
	flame_particles.emitting = true
	# No queue_free: continuous fire; controller removes this node when ability ends or is removed.

## Call from controller to sync visuals and hitbox with upgrades.
## base_particle_amount: from main ability level (each upgrade can increase this).
## attack_speed_mult: generic attack speed; multiplies particle amount (intensity) and is used by controller for tick interval.
## spread_angle_deg: cone width in degrees (ability upgrade).
## duration_mult: scales particle lifetime and hitbox length (generic duration upgrade).
## size_mult: scales hitbox size and particle scale.
func apply_parameters(
	base_particle_amount: int,
	attack_speed_mult: float,
	spread_angle_deg: float = -1.0,
	duration_mult: float = 1.0,
	size_mult: float = 1.0
) -> void:
	_base_particle_amount = base_particle_amount
	var amount: int = int(base_particle_amount * attack_speed_mult)
	flame_particles.amount = maxi(amount, 8)

	var lifetime: float = _base_lifetime * duration_mult
	flame_particles.lifetime = lifetime

	if spread_angle_deg >= 0.0:
		_base_cone_angle = spread_angle_deg
		if flame_particles.process_material is ParticleProcessMaterial:
			# Duplicate so we don't modify a shared resource; ensures spread upgrades apply per instance.
			var mat: ParticleProcessMaterial = (flame_particles.process_material as ParticleProcessMaterial).duplicate()
			mat.emission_ring_cone_angle = spread_angle_deg
			# Velocity > Spread: increase so particles visually fan out more with spread upgrades (base 2.0 at ~15°).
			mat.spread = maxf(2.0, 2.0 + (spread_angle_deg - 15.0) * 0.5)
			flame_particles.process_material = mat

	flame_particles.scale = Vector2.ONE * size_mult * SIZE_SCALE

	# 4-point trapezoid: points 0,1 = nozzle (left), points 2,3 = tip (right). Spread/length adjust last two points.
	var length: float = _base_length * size_mult * duration_mult * SIZE_SCALE
	var cone_deg: float = spread_angle_deg if spread_angle_deg >= 0.0 else _base_cone_angle
	var half_angle_rad: float = deg_to_rad(cone_deg) * 0.5
	var tip_half_width: float = length * tan(half_angle_rad)
	tip_half_width = maxf(MIN_TIP_HALF_WIDTH, tip_half_width)
	var nozzle_half_width: float = _base_nozzle_half_width * size_mult * SIZE_SCALE

	var col: CollisionPolygon2D = hitbox_component.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if col != null:
		# Winding: 0 top-left, 1 bottom-left, 2 bottom-right, 3 top-right (matches your scene).
		col.polygon = PackedVector2Array([
			Vector2(0, nozzle_half_width),
			Vector2(0, -nozzle_half_width),
			Vector2(length, -tip_half_width),
			Vector2(length, tip_half_width)
		])
