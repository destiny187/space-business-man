shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// One exterior camera shares the cabin camera's projection and head rotation.
// All apertures sample the same screen ray, including port/starboard/zenith.
uniform sampler2D exterior : source_color, filter_linear, repeat_disable;
void fragment() {
	ALBEDO = texture(exterior, SCREEN_UV).rgb;
}
