shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec4 tint:source_color=vec4(.12,.45,1.0,1);
uniform float strength=4.0;
void vertex(){
 vec3 particle_scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*particle_scale.x,INV_VIEW_MATRIX[1]*particle_scale.y,INV_VIEW_MATRIX[2]*particle_scale.z,MODEL_MATRIX[3]);
}
void fragment(){float r=length(UV*2.0-1.0);ALBEDO=mix(tint.rgb,vec3(.7,1.,1.),max(0.,1.-r))*strength;ALPHA=pow(max(0.,1.-r),2.)*COLOR.a;}
