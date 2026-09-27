shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_texture = false;

// 3-tone diffuse lighting with soft readable shadows
uniform float shadow_factor : hint_range(0.0, 1.0) = 0.38;
uniform float midtone_factor : hint_range(0.0, 1.0) = 0.72;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.20;
uniform float midtone_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float step_smoothness : hint_range(0.001, 0.2) = 0.12;

// Restrained highlights
uniform float specular_size : hint_range(0.0, 1.0) = 0.05;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.05;
uniform float specular_smoothness : hint_range(0.001, 0.2) = 0.04;

// Rim lighting (subtle edge enhancement)
uniform float rim_size : hint_range(0.0, 1.0) = 0.50;
uniform float rim_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float rim_smoothness : hint_range(0.001, 0.2) = 0.08;

// Emission
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;

// UV transforms
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 base_color = albedo_color;
	if (use_texture) {
		base_color *= texture(albedo_texture, UV);
	}
	ALBEDO = base_color.rgb;
	ALPHA = base_color.a;
	if (emission_energy > 0.001) {
		EMISSION = emission_color.rgb * emission_energy;
	}
}

void light() {
	// Stepped diffuse toon lighting:
	// Shadow region receives shadow_factor (38%) direct illumination to preserve textures & panels.
	// Midtone region receives midtone_factor (72%) direct illumination.
	// Fully lit region receives 100% direct illumination.
	// Soft transitions prevent crawling/flickering banding artifacts across low-poly surfaces.
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float light_intensity = NdotL * ATTENUATION;

	float mid_step = smoothstep(shadow_threshold - step_smoothness, shadow_threshold + step_smoothness, light_intensity);
	float lit_step = smoothstep(midtone_threshold - step_smoothness, midtone_threshold + step_smoothness, light_intensity);

	float diffuse_mult = mix(shadow_factor, midtone_factor, mid_step);
	diffuse_mult = mix(diffuse_mult, 1.0, lit_step);

	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * diffuse_mult;

	// Restrained specular glint (satin sheen rather than plastic dots)
	if (specular_intensity > 0.005) {
		vec3 half_vec = normalize(VIEW + LIGHT);
		float NdotH = clamp(dot(NORMAL, half_vec), 0.0, 1.0);
		float spec = smoothstep(1.0 - specular_size - specular_smoothness, 1.0 - specular_size + specular_smoothness, NdotH);
		SPECULAR_LIGHT += LIGHT_COLOR * spec * specular_intensity * ATTENUATION;
	}

	// Subtle rim light
	if (rim_intensity > 0.005) {
		float NdotV = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(1.0 - rim_size - rim_smoothness, 1.0 - rim_size + rim_smoothness, NdotV);
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * rim * rim_intensity * NdotL;
	}
}
