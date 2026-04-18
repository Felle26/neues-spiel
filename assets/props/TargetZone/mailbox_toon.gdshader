shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shade_steps : hint_range(1.0, 8.0) = 3.0;
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.4;
uniform float rim_width : hint_range(0.0, 1.0) = 0.5;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo_color.rgb * (1.0 + highlight_strength * 0.45);
}

void light() {
	vec3 normal = normalize(NORMAL);
	vec3 light_dir = normalize(LIGHT);

	float ndotl = max(dot(normal, light_dir), 0.0);
	float toon = floor(ndotl * shade_steps) / shade_steps;

	float spec = pow(max(dot(reflect(-light_dir, normal), VIEW), 0.0), 32.0);
	spec = step(0.5, spec) * specular_intensity;

	float rim = 1.0 - max(dot(normal, VIEW), 0.0);
	rim = smoothstep(rim_width, 1.0, rim) * rim_strength;

	DIFFUSE_LIGHT += ALBEDO * toon * LIGHT_COLOR * ATTENUATION;
	SPECULAR_LIGHT += vec3(spec + rim + highlight_strength * 0.2) * LIGHT_COLOR * ATTENUATION;
}
