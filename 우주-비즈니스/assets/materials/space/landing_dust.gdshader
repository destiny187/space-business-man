shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.6, 0.5, 0.4, 1.0);
void vertex() { MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]); }
void fragment() {
 float r=length(UV*2.0-1.0);
 ALBEDO=tint.rgb;
 ALPHA=pow(max(0.0,1.0-r),2.0)*0.3;
}
