shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float phase = 0.0;
// 0 muzzle, 1 dust, 2 contact, 3 broken shield arc.
instance uniform float shape = 0.0;
float taper(vec2 p, vec2 tip, float width) {
    float along = clamp(dot(p, tip) / dot(tip, tip), 0.0, 1.0);
    return length(p - tip * along) / max(0.015, width * (1.0 - along));
}
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float edge;
    float alpha = 1.0;
    if (shape < 0.5) {
        // Unequal pointed tongues, with no rotational flower symmetry.
        edge = min(taper(p, vec2(0.91, 0.19), 0.28), taper(p, vec2(-0.46, -0.18), 0.20));
        edge = min(edge, taper(p, vec2(-0.12, 0.62), 0.15));
    } else if (shape < 1.5) {
        float angle = atan(p.y, p.x);
        float radius = 0.63 + sin(angle * 3.0 + 0.7) * 0.09 + sin(angle * 5.0 - 1.1) * 0.05;
        edge = length(p * vec2(1.0, 1.28)) / radius;
        alpha = 0.44 * (1.0 - phase);
    } else if (shape < 2.5) {
        edge = min(taper(p, vec2(0.74, 0.49), 0.16), taper(p, vec2(-0.48, -0.55), 0.13));
        edge = min(edge, taper(p, vec2(-0.41, 0.29), 0.12));
    } else {
        float angle = atan(p.y, p.x);
        float radius = 0.46 + 0.32 * phase;
        edge = abs(length(p) - radius) / (0.045 * (1.0 - 0.5 * phase));
        // Several interrupted arcs keep the impact surface readable.
        alpha = smoothstep(-0.05, 0.2, sin(angle * 3.0 + phase * 1.4)) * (1.0 - phase);
    }
    float mask = 1.0 - smoothstep(0.80, 1.0, edge);
    vec3 band = mix(tint.rgb * 0.25, tint.rgb, step(edge, 0.69));
    if (shape < 0.5 || (shape > 1.5 && shape < 2.5)) {
        band = mix(band, vec3(1.0, 0.98, 0.90), step(edge, 0.34));
    }
    ALBEDO = band;
    EMISSION = band * (shape > 0.5 && shape < 1.5 ? 0.0 : 0.10);
    ALPHA = mask * tint.a * alpha * (1.0 - smoothstep(0.35, 1.0, phase));
}
