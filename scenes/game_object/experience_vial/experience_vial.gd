extends Node2D

## Minecraft-style experience orbs: random color variation, simple circle + soft glow.

const ORB_COLORS := [
	Color("4ade80"),   # green
	Color("22d3ee"),   # cyan
	Color("a3e635"),   # lime
	Color("2dd4bf"),   # teal
	Color("86efac"),   # light green
	Color("5eead4"),   # light teal
	Color("facc15"),   # amber (slight variation)
]
const INNER_RADIUS := 3.0
const GLOW_RADIUS := 4.0
const CIRCLE_POINTS := 32
## If collect() took longer than this (e.g. game was paused for level-up), skip the sound to avoid a burst when unpausing.
const MAX_COLLECT_DURATION_BEFORE_SKIP_SOUND := 0.6

@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var orb_visual: Node2D = $OrbVisual
@onready var inner_orb: Polygon2D = $OrbVisual/InnerOrb
@onready var glow_ring: Polygon2D = $OrbVisual/GlowRing
@onready var glow_particles: GPUParticles2D = $OrbVisual/GlowParticles


func _ready() -> void:
	_setup_orb_appearance()
	$Area2D.area_entered.connect(on_area_entered)


func _setup_orb_appearance() -> void:
	var base_color: Color = ORB_COLORS.pick_random()
	base_color = base_color.lerp(Color.WHITE, randf_range(0.0, 0.25))
	inner_orb.polygon = _make_circle_polygon(INNER_RADIUS)
	inner_orb.color = base_color
	glow_ring.polygon = _make_circle_polygon(GLOW_RADIUS)
	glow_ring.color = Color(base_color.r, base_color.g, base_color.b, 0.35)
	if glow_particles:
		_setup_particle_color(base_color)


func _make_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in CIRCLE_POINTS:
		var angle := i * TAU / CIRCLE_POINTS
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points


func _setup_particle_color(orb_color: Color) -> void:
	var mat: ParticleProcessMaterial = glow_particles.process_material
	if mat == null:
		return
	# Use a small white texture so color_ramp tints the particles
	if glow_particles.texture == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		glow_particles.texture = ImageTexture.create_from_image(img)
	mat = mat.duplicate() as ParticleProcessMaterial
	var grad := Gradient.new()
	grad.add_point(0.0, orb_color)
	grad.add_point(1.0, Color(orb_color.r, orb_color.g, orb_color.b, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	glow_particles.process_material = mat
	glow_particles.emitting = true
	
	
func tween_collect(percent: float, start_position: Vector2):
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	global_position = start_position.lerp(player.global_position, percent)
	var direction_from_start = player.global_position - start_position
	
	var target_rotation = direction_from_start.angle() + deg_to_rad(90)
	rotation = lerp_angle(rotation, target_rotation, 1 - exp(-2 * get_process_delta_time()))


func collect():
	GameEvents.emit_experience_vial_collected(1)
	var collect_start_time := Time.get_ticks_msec() / 1000.0
	var params: Dictionary = ExperienceVialSoundManager.get_pickup_sound_params()
	if params.delay > 0.0:
		await get_tree().create_timer(params.delay).timeout
	# If we were paused (e.g. level-up screen), skip sound so we don't get a burst when unpausing
	var elapsed := Time.get_ticks_msec() / 1000.0 - collect_start_time
	if elapsed > MAX_COLLECT_DURATION_BEFORE_SKIP_SOUND:
		queue_free()
		return
	var player := $PickupStreamPlayer as AudioStreamPlayer2D
	player.pitch_scale = params.pitch
	player.play()
	await player.finished
	queue_free()


func disable_collision():
	collision_shape_2d.disabled = true


func on_area_entered(other_area: Area2D):
	Callable(disable_collision).call_deferred()
	if glow_particles:
		glow_particles.emitting = false
		glow_particles.visible = false
	
	var tween = create_tween()
	tween.set_parallel()
	# Multi line tween
	tween.tween_method(tween_collect.bind(global_position), 0.0, 1.0, .5)\
	.set_ease(Tween.EASE_IN)\
	.set_trans(Tween.TRANS_BACK)
	tween.tween_property(orb_visual, "scale", Vector2.ZERO, .07).set_delay(.43)
	tween.chain()
	tween.tween_callback(collect)
	
	
