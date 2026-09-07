shader_type spatial;
render_mode unshaded, depth_draw_never;
uniform float progress = 0.0;
uniform bool complete = false;
uniform float bottom = 0.0;
uniform float top = 2.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float height = max(0.2, top - bottom);
	float sweep = mix(bottom - 0.05, top + 0.05, progress);
	float band = exp(-abs(world_position.y - sweep) * 55.0 / height);
	float echo = exp(-abs(world_position.y - sweep + height * 0.075) * 70.0 / height) * 0.22;
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
	float grid = pow(max(0.0, cos(world_position.y * 42.0)), 24.0) * 0.045;
	ALBEDO = complete ? vec3(0.45, 0.95, 0.65) : vec3(0.28, 0.87, 0.94);
	EMISSION = ALBEDO * 0.65;
	ALPHA = complete ? rim * 0.65 + 0.06 : min(0.8, band * 0.8 + echo + grid + rim * 0.045);
}
