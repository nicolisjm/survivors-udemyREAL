shader_type canvas_item;

// Your NoiseTexture2D with color ramp – its colors are used directly and animated like TV static.
uniform sampler2D noise_tex : hint_default_white;
// How fast the static moves (higher = more frantic).
uniform float speed : hint_range(0.0, 50.0) = 15.0;
// Zoom into noise: higher = more detail visible on the ball (e.g. 3–6).
uniform float noise_scale : hint_range(0.5, 10.0) = 4.0;

// Cheap pseudo-random from uv + time for TV static jitter.
float _rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	float d = length(uv - center);
	if (d > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		float t = TIME * speed;
		// Scroll so the whole pattern moves (seamless wrap).
		vec2 scroll = vec2(t * 0.7, t * 0.43);
		// Zoom into noise so your gradient detail is visible on the ball.
		vec2 uv_anim = uv * noise_scale + scroll;
		// TV static: time-based jitter so the pattern never sits still (updates many times per second).
		float jitter = 0.2;
		float t_fast = t * 25.0;
		uv_anim += vec2(_rand(vec2(floor(t_fast), 0.0)), _rand(vec2(floor(t_fast), 1.0))) * jitter;
		uv_anim += vec2(_rand(vec2(floor(t_fast * 1.7), 2.0)), _rand(vec2(floor(t_fast * 1.7), 3.0))) * (jitter * 0.6);
		// Wrap UV so we always sample inside the texture (otherwise we clamp to edge = solid blue, no movement).
		uv_anim = fract(uv_anim);
		vec4 tex = texture(noise_tex, uv_anim);
		float edge = 1.0 - smoothstep(0.35, 0.5, d);
		COLOR.rgb = tex.rgb;
		COLOR.a = tex.a * edge;
	}
}
