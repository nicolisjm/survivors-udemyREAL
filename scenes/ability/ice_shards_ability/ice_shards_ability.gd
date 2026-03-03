extends Node2D

## Set by controller (or chain spawn) before add_child.
var direction: Vector2 = Vector2.RIGHT
var damage: float = 0.0
## Same as damage for initial shards; chained shards use base_damage * 0.5 once (never halved again).
var base_damage: float = 0.0
var speed: float = 500.0
var duration: float = 1.2
var size_mult: float = 1.0
## Max enemies this shard can hit before being removed (pierce + 1).
var max_hits: int = 1
## Chains left: on hit, spawn a new shard toward next nearest; decremented for the new shard.
var chains_remaining: int = 0
## Enemy we just hit (excluded when picking next chain target).
var last_hit_enemy: Node = null
var chain_range: float = 150.0
## Level 9: after last chain hit, keep flying this many px then despawn instead of instant despawn.
var post_chain_fly_distance: float = 0.0
## Same scene for spawning chained projectiles; set by controller.
var chain_scene: PackedScene = null

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var particles: GPUParticles2D = $GPUParticles2D

const HURTBOX_LAYER := 32
## HitboxComponent scene uses layer 4; we set to 0 for chained shards until clear of source enemy.
const _HITBOX_LAYER := 4
const _ICE_HIT_SOUND := preload("res://assets/audio/sfx/spinopel-on-thin-ice-456386.mp3")
const _ICE_HIT_VOLUME_DB := -26.0
const _ICE_HIT_TRIM_END := 0.4
const _ICE_HIT_PITCH := 1.2
## Chained shards: enable hitbox once we're this far (px) from the enemy we spawned from.
const _CHAIN_HITBOX_CLEAR_DIST := 15
## Max concurrent hit particle effects (avoids lag with many chains).
const _MAX_HIT_PARTICLES := 20
const _ICE_PARTICLE_GROUP := "ice_shard_particles"
## Max simultaneous ice hit sounds (avoids lag from many chains).
const _MAX_ICE_HIT_SOUNDS := 8
const _ICE_HIT_SOUND_GROUP := "ice_hit_sound"

var _hit_count: int = 0
var _hit_hurtbox_ids: Dictionary = {}
var _lifetime: float = 0.0
var _post_chain_fly: bool = false
var _post_chain_fly_remaining: float = 0.0
## Chained shards: true until we're far enough from last_hit_enemy to re-enable hitbox.
var _chain_hitbox_pending: bool = false


func _ready() -> void:
	# Spawn position for chained shards (set before add_child, applied here so deferred add works).
	if has_meta("pending_spawn_pos"):
		global_position = get_meta("pending_spawn_pos")
		remove_meta("pending_spawn_pos")
	# Sprite tip points up (-Y) by default; rotate so tip points along direction.
	rotation = direction.angle() + PI / 2.0
	scale = Vector2.ONE * size_mult
	hitbox_component.damage = damage
	hitbox_component.collision_mask = HURTBOX_LAYER
	# Ice hit sound played in _on_hitbox_area_entered with cap; leave hitbox sound null to avoid uncapped playback in hurtbox.
	hitbox_component.hit_sound = null
	hitbox_component.hit_sound_volume_db = _ICE_HIT_VOLUME_DB
	hitbox_component.hit_sound_trim_end = _ICE_HIT_TRIM_END
	hitbox_component.hit_sound_pitch_scale = _ICE_HIT_PITCH
	hitbox_component.area_entered.connect(_on_hitbox_area_entered)
	# Particles disabled: don't process or draw this node to save cost when many shards exist.
	if particles:
		particles.process_mode = Node.PROCESS_MODE_DISABLED
		particles.visible = false
	# Chained shards spawn on top of the source enemy. Hide from hurtbox (collision_layer=0) until we've moved away; _process will re-enable by distance.
	if last_hit_enemy != null:
		hitbox_component.collision_layer = 0
		_chain_hitbox_pending = true


func _on_hitbox_area_entered(area: Area2D) -> void:
	if not area is HurtboxComponent:
		return
	# Don't count or damage the enemy we chained from (in case we still overlap). Zero damage so the hurtbox's callback won't apply either.
	if last_hit_enemy != null and area.get_parent() == last_hit_enemy:
		hitbox_component.damage = 0
		return
	var id := area.get_instance_id()
	if _hit_hurtbox_ids.get(id, false):
		return
	_hit_hurtbox_ids[id] = true
	_hit_count += 1

	var enemy: Node = area.get_parent()
	var hit_pos: Vector2 = global_position
	var hurtbox: HurtboxComponent = area as HurtboxComponent

	# Apply damage ourselves so it always happens regardless of area_entered callback order.
	# Use shard's damage (hitbox may be 0 if we already zeroed it to skip the source enemy).
	var amount: float = damage
	hitbox_component.damage = 0
	var knockback := Vector2.ZERO
	if hitbox_component.knockback_strength > 0:
		knockback = (hurtbox.global_position - global_position).normalized() * hitbox_component.knockback_strength
	hurtbox.apply_damage(
		amount,
		hitbox_component.hit_spark_config,
		0.0, null, hitbox_component.is_crit,
		null, hitbox_component.hit_sound_volume_db, hitbox_component.hit_sound_trim_end, hitbox_component.hit_sound_pitch_scale,
		null, knockback
	)

	var tree := get_tree()
	var foreground = tree.get_first_node_in_group("foreground_layer")

	# Play ice hit sound with cap (avoids many simultaneous sounds from chains).
	if foreground and not tree.paused:
		var n_playing := tree.get_nodes_in_group(_ICE_HIT_SOUND_GROUP).size()
		if n_playing < _MAX_ICE_HIT_SOUNDS:
			var p := AudioStreamPlayer2D.new()
			p.add_to_group(_ICE_HIT_SOUND_GROUP)
			p.stream = _ICE_HIT_SOUND
			p.volume_db = _ICE_HIT_VOLUME_DB
			p.pitch_scale = _ICE_HIT_PITCH
			foreground.add_child(p)
			p.global_position = hit_pos
			p.finished.connect(p.queue_free)
			p.play()
			if _ICE_HIT_TRIM_END > 0.0 and _ICE_HIT_SOUND.get_length() > 0.0:
				var trim_time := maxf(0.0, _ICE_HIT_SOUND.get_length() - _ICE_HIT_TRIM_END)
				if trim_time > 0.0:
					var t := tree.create_timer(trim_time)
					var pref = weakref(p)
					t.timeout.connect(func():
						var x = pref.get_ref()
						if x:
							x.stop()
							x.queue_free()
					)

	# Chain: spawn one new shard from this enemy toward next nearest (exclude only this enemy).
	# Defer add_child so we don't modify the scene tree during physics overlap (avoids "flushing queries" error).
	if chains_remaining > 0 and chain_scene != null:
		var next_target := _get_next_chain_target(enemy)
		if next_target != null:
			var to_next: Vector2 = (next_target.global_position - enemy.global_position).normalized()
			var chained := chain_scene.instantiate()
			chained.direction = to_next
			# Chained shards always deal half of base_damage once (never halved again).
			chained.base_damage = base_damage
			chained.damage = base_damage * 0.5
			chained.speed = speed
			chained.duration = duration
			chained.size_mult = size_mult
			chained.max_hits = max_hits
			chained.chains_remaining = chains_remaining - 1
			chained.last_hit_enemy = enemy
			chained.chain_range = chain_range
			chained.post_chain_fly_distance = post_chain_fly_distance
			chained.chain_scene = chain_scene
			chained.set_meta("pending_spawn_pos", enemy.global_position)
			if foreground:
				foreground.call_deferred("add_child", chained)

	# Pierce / despawn
	if _hit_count >= max_hits:
		if chains_remaining == 0 and post_chain_fly_distance > 0.0:
			_post_chain_fly = true
			_post_chain_fly_remaining = post_chain_fly_distance
			# Disable hitbox so we don't hit more (deferred: can't change during overlap callback).
			hitbox_component.set_deferred("monitoring", false)
		else:
			queue_free()


func _get_next_chain_target(from_enemy: Node) -> Node:
	var center: Vector2 = from_enemy.global_position
	var range_sq: float = chain_range * chain_range
	var enemies: Array = get_tree().get_nodes_in_group("enemy")
	enemies = enemies.filter(func(e: Node) -> bool:
		if e == from_enemy:
			return false
		if not is_instance_valid(e):
			return false
		return (e as Node2D).global_position.distance_squared_to(center) <= range_sq
	)
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as Node2D).global_position.distance_squared_to(center) < (b as Node2D).global_position.distance_squared_to(center)
	)
	return enemies[0] as Node


func _physics_process(delta: float) -> void:
	# Chained shards: enable hitbox as soon as we're clear of the source enemy. Do this in _physics_process
	# so we're on the correct layer when physics runs (physics runs after _physics_process), otherwise we
	# can fly past a close enemy before overlap is detected and "miss" the hit.
	if _chain_hitbox_pending and last_hit_enemy != null and is_instance_valid(last_hit_enemy):
		var dist_sq := global_position.distance_squared_to((last_hit_enemy as Node2D).global_position)
		if dist_sq >= _CHAIN_HITBOX_CLEAR_DIST * _CHAIN_HITBOX_CLEAR_DIST:
			_chain_hitbox_pending = false
			if is_instance_valid(hitbox_component):
				hitbox_component.collision_layer = _HITBOX_LAYER


func _process(delta: float) -> void:
	if _post_chain_fly:
		var step := speed * delta
		_post_chain_fly_remaining -= step
		global_position += direction * step
		if _post_chain_fly_remaining <= 0.0:
			queue_free()
		return
	global_position += direction * speed * delta
	_lifetime += delta
	if _lifetime >= duration:
		queue_free()
