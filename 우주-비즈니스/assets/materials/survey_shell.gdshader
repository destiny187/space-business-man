shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float progress = 0.0;
uniform bool complete = false;
void fragment() {
	float latitude = UV.y;
	float scan_height = mix(0.94, 0.06, progress);
	float band = exp(-abs(latitude - scan_height) * 110.0);
	float echo = exp(-abs(latitude - scan_height - 0.045) * 80.0) * 0.22;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
	float ticks = pow(max(0.0, cos(UV.x * 100.53)), 22.0) * (1.0 - smoothstep(0.012, 0.025, abs(latitude - 0.5)));
	float confirmed = complete ? rim * 0.65 : 0.0;
	ALBEDO = complete ? vec3(0.51, 0.96, 0.69) : vec3(0.28, 0.82, 0.9);
	EMISSION = ALBEDO * 0.65;
	ALPHA = min(0.85, band * 0.8 + echo + rim * 0.10 + ticks * 0.5 + confirmed);
}
