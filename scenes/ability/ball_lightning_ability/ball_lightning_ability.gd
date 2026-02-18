extends Node2D
## Ball lightning visual: static-y lightning ball using animated noise shader.
## Single ColorRect + shader; full ball always visible. With viewport stretch the static
## can look a bit softer at runtime than in the editor—no SubViewport to avoid scaling quirks.

@export var pixel_size: int = 16

@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var ball_rect: ColorRect = $BallColorRect


func _ready() -> void:
	ball_rect.custom_minimum_size = Vector2(pixel_size, pixel_size)
	ball_rect.size = Vector2(pixel_size, pixel_size)
	ball_rect.position = Vector2(-pixel_size / 2.0, -pixel_size / 2.0)
	var mat: ShaderMaterial = ball_rect.material as ShaderMaterial
	if mat != null:
		if mat.get_shader_parameter("noise_tex") == null:
			mat.set_shader_parameter("noise_tex", _make_noise_texture())


func _make_noise_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.08
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 64
	tex.height = 64
	tex.seamless = true
	return tex
