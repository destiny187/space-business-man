shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec4 tint:source_color=vec4(1.0,.55,.12,1.0);
uniform float strength=1.0;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);float a=atan(p.y,p.x);
 float rays=.8+.2*sin(a*19.0+TIME*.05);
 ALBEDO=tint.rgb*strength;
 ALPHA=pow(max(0.0,1.0-r),3.0)*rays;
}
