shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.18, 0.20, 0.24, 0.8);
uniform float outline_width : hint_range(0.0, 0.05) = 0.005;
uniform bool enabled = false;

void vertex() {
	if (enabled && outline_width > 0.0001) {
		// In Godot 4 spatial shaders, VERTEX and NORMAL are already in view space.
		float dist = max(1.0, -VERTEX.z);
		float dist_scale = clamp(dist * 0.025, 0.5, 1.3);
		float thickness = outline_width * dist_scale;
		VERTEX += NORMAL * thickness;
	} else {
		POSITION = vec4(0.0);
	}
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
