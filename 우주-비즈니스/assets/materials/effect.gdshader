shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
instance uniform vec4 effect_color : source_color = vec4(0.5, 1.0, 0.8, 1.0);
void fragment() {
	ALBEDO = effect_color.rgb * (0.55 + 0.45 * max(dot(normalize(NORMAL),normalize(vec3(-0.4,0.6,0.9))),0.0));
	EMISSION = effect_color.rgb * 0.18;
	ALPHA = effect_color.a;
}
