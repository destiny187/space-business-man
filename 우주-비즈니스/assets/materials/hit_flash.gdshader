shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform float strength = 1.0;
uniform vec4 tint : source_color = vec4(0.45, 1.0, 0.8, 1.0);
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = strength * (0.25 + 0.7 * pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0));
}
