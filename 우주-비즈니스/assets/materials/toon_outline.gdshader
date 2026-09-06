shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 ink : source_color = vec4(0.055, 0.075, 0.09, 1.0);
uniform float thickness = 0.008;

void vertex() {
	float distance_to_camera = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * thickness * clamp(distance_to_camera * 0.16, 0.22, 1.0);
}

void fragment() {
	ALBEDO = ink.rgb;
}
