shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
void vertex() {
 float scale = length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale, INV_VIEW_MATRIX[1] * scale, INV_VIEW_MATRIX[2] * scale, MODEL_MATRIX[3]);
}
void fragment() {
 float r = length(UV * 2.0 - 1.0);
 float glow = exp(-r*r*6.0) * (1.0-smoothstep(0.65,1.0,r));
 ALBEDO = COLOR.rgb;
 ALPHA = glow * 0.18;
}
