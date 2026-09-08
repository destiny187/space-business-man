shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.0;
uniform float softness = 1.0;
varying float distance_fade;
void vertex() {
 vec3 center=(MODEL_MATRIX*vec4(0.,0.,0.,1.)).xyz;
 float size=length(MODEL_MATRIX[0].xyz);
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size,INV_VIEW_MATRIX[2]*size,vec4(center,1.));
 float distance_to_eye=length((VIEW_MATRIX*vec4(center,1.)).xyz);
 distance_fade=smoothstep(1.5,4.,distance_to_eye)*(1.-smoothstep(16.,24.,distance_to_eye));
}
void fragment() {
 float radius=length(UV*2.-1.);
 float shape=pow(max(0.,1.-radius*radius),softness);
 ALBEDO=tint.rgb;
 ALPHA=shape*tint.a*strength*COLOR.a*distance_fade;
}
