shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.6, 0.5, 0.4, 1.0);
void vertex() {
 vec3 scale_value=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*scale_value.x,INV_VIEW_MATRIX[1]*scale_value.y,INV_VIEW_MATRIX[2]*scale_value.z,MODEL_MATRIX[3]);
}
void fragment() {
 float r=length(UV*2.0-1.0);
 ALBEDO=tint.rgb;
 ALPHA=pow(max(0.0,1.0-r),2.0)*0.45*COLOR.a;
}
