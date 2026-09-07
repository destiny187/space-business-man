shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){float r=length(UV*2.0-1.0);ALBEDO=mix(vec3(.12,.45,1.0),vec3(.7,1.,1.),max(0.,1.-r))*4.;ALPHA=pow(max(0.,1.-r),2.);}
