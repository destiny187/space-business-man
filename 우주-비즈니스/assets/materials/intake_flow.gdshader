shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength = 0.0;
uniform float phase = 0.0;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 1.6);
	float streak = pow(max(0.0, sin(UV.y * 37.0 - phase * 23.0)), 5.0);
	float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.94, 1.0, UV.y));
	ALBEDO = vec3(0.48, 0.84, 0.82);
	EMISSION = ALBEDO * 0.5;
	ALPHA = edge * (0.08 + streak * 0.7) * ends * strength;
}
