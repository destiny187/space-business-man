shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float phase = 0.0;
instance uniform float soft = 0.0;
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float a = atan(p.y, p.x);
    float lobes = pow(abs(cos(a * 3.0 + 0.4)), 5.0);
    float edge = mix(0.48 + lobes * 0.48, 0.82, soft);
    float radius = length(p) / edge;
    float mask = 1.0 - smoothstep(0.84, 1.0, radius);
    vec3 band = mix(tint.rgb * 0.65, tint.rgb, step(radius, 0.70));
    band = mix(band, vec3(1.0, 0.97, 0.86), step(radius, 0.29) * (1.0 - soft));
    ALBEDO = band;
    EMISSION = band * 0.15 * (1.0 - soft);
    ALPHA = mask * tint.a * (1.0 - smoothstep(0.25, 1.0, phase));
}
