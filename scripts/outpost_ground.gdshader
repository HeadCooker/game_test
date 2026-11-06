shader_type spatial;
render_mode cull_disabled;

uniform bool show_grid = true;
uniform float terrain_size = 62.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * terrain_size + 8.0;
	float grain = noise(p * 14.0);
	float layers = noise(p * 0.55 + vec2(1.0, 5.0)) * 0.65 + noise(p * 2.3) * 0.35;
	vec3 soil = mix(vec3(0.28, 0.126, 0.092), vec3(0.63, 0.37, 0.24), layers);
	soil *= 0.92 + grain * 0.15;
	float track = 1.0 - smoothstep(0.07, 0.17, abs(abs(p.x - 8.5) - 0.37));
	soil *= 1.0 - track * 0.18;
	if (show_grid) {
		vec2 edge = min(fract(p), 1.0 - fract(p));
		float grid = 1.0 - smoothstep(0.015, 0.039, min(edge.x, edge.y));
		float border = min(min(p.x, p.y), min(16.0 - p.x, 16.0 - p.y));
		float grid_fade = smoothstep(0.0, 0.7, border);
		soil = mix(soil, vec3(0.76, 0.59, 0.43), grid * grid_fade * 0.23);
	}
	ALBEDO = soil;
	ROUGHNESS = 0.96;
}
