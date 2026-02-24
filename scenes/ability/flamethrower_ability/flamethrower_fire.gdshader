shader_type canvas_item;

// Planck-style fire: temperature lookup + cooling over particle lifetime.
// Temperature gradient: use EXR from resources/effects/ (e.g. color_temp_800_6000.exr or color_temp_600_60000.exr from plancks-law-colors), or fire_temperature_gradient.tres.
// Particle age is passed as COLOR.r (0 = birth, 1 = end) via color_ramp in ParticleProcessMaterial.
render_mode blend_add, unshaded;

uniform sampler2D texture_plancks_emission : hint_default_black, filter_linear, repeat_disable;
uniform float plancks_emission_energy : hint_range(0.0, 2.0) = 0.4;
uniform float plancks_emission_temperature_celcius : hint_range(500.0, 3000.0) = 1200.0;
uniform float temperature_cooling_rate : hint_range(0.1, 2.0) = 0.5;
// Scale particle age to "time" for cooling (higher = particles stay hot longer).
uniform float age_to_time_scale : hint_range(0.5, 4.0) = 2.0;
// Temperature range of the gradient texture (e.g. 800-6000 for fire EXR, 600-60000 for full Planck).
uniform float temperature_texture_min_k : hint_range(400.0, 1000.0) = 800.0;
uniform float temperature_texture_max_k : hint_range(5000.0, 60000.0) = 6000.0;

const float KELVIN = 273.15;

float unmap_temperature(float temperature, sampler2D tex) {
	float min_temp = temperature_texture_min_k;
	float max_temp = temperature_texture_max_k;
	if (temperature < min_temp) {
		return 0.0;
	}
	float normalized = log(temperature / min_temp) / log(max_temp / min_temp);
	normalized = clamp(normalized, 0.0, 1.0);
	return texture(tex, vec2(normalized, 0.0)).r; // sample R for 1D grayscale; use .rgb for full color
}

vec3 unmap_temperature_rgb(float temperature, sampler2D tex) {
	float min_temp = temperature_texture_min_k;
	float max_temp = temperature_texture_max_k;
	if (temperature < min_temp) {
		return vec3(0.0);
	}
	float normalized = log(temperature / min_temp) / log(max_temp / min_temp);
	normalized = clamp(normalized, 0.0, 1.0);
	return texture(tex, vec2(normalized, 0.0)).rgb;
}

float calculate_cooling_temperature(float time, float initial_temp, float ambient_temp, float cooling_rate) {
	float decay = exp(-cooling_rate * time);
	float temp_diff = initial_temp - ambient_temp;
	return temp_diff * decay + ambient_temp;
}

void fragment() {
	// COLOR.r = normalized particle age (0 at birth, 1 at end) when color_ramp goes black->red
	float normalized_age = COLOR.r;
	float time = normalized_age * age_to_time_scale;
	float initial_k = KELVIN + plancks_emission_temperature_celcius;
	float ambient_k = KELVIN + 20.0;
	float temp_k = calculate_cooling_temperature(time, initial_k, ambient_k, temperature_cooling_rate);
	vec3 fire_rgb = unmap_temperature_rgb(temp_k, texture_plancks_emission);

	// Fallback if texture is empty: simple fire gradient (dark red -> orange -> yellow -> white)
	vec3 fallback = mix(vec3(0.2, 0.0, 0.0), vec3(1.0, 0.5, 0.0), smoothstep(0.0, 0.5, 1.0 - normalized_age));
	fallback = mix(fallback, vec3(1.0, 1.0, 0.8), smoothstep(0.5, 0.85, 1.0 - normalized_age));
	float luminance = dot(fire_rgb, vec3(0.299, 0.587, 0.114));
	if (luminance < 0.001) {
		fire_rgb = fallback;
	}

	vec4 particle_shape = texture(TEXTURE, UV);
	float alpha = particle_shape.a * (1.0 - smoothstep(0.7, 1.0, normalized_age));
	// Soft circle mask so particles look round instead of square (UV is 0–1 per particle)
	float dist = length(UV - 0.5);
	alpha *= 1.0 - smoothstep(0.48, 0.5, dist);
	COLOR = vec4(fire_rgb * plancks_emission_energy, alpha);
}
