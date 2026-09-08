shader_type spatial;
render_mode unshaded;
void fragment() {
 float light = dot(normalize(NORMAL), normalize(vec3(-0.4, 0.65, 0.8)));
 float band = 0.32 + 0.35 * smoothstep(-0.08, 0.04, light) + 0.33 * smoothstep(0.55, 0.65, light);
 ALBEDO = COLOR.rgb * band;
 EMISSION = COLOR.rgb * (0.25 + 0.45 * pow(max(light, 0.0), 6.0));
}
