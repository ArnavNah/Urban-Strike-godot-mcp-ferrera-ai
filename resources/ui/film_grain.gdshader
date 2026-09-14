shader_type canvas_item;

// Vintage military footage film grain
// Lightweight GL Compatibility safe shader with subtle 2-4% intensity
uniform float grain_strength : hint_range(0.0, 0.1) = 0.032;
uniform float grain_speed : hint_range(0.0, 30.0) = 14.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 stepped_time = vec2(floor(TIME * grain_speed) * 0.13, floor(TIME * grain_speed) * 0.07);
	float n = hash(UV * 400.0 + stepped_time);
	// Soft centered grain: deviations around 0.5 blended subtly
	COLOR = vec4(vec3(n), grain_strength);
}
