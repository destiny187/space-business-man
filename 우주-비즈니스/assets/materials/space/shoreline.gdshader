shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
uniform float flow_time=0.;
varying vec3 shore_point;
void vertex(){shore_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float wash=.5+.5*sin(shore_point.x*.23+shore_point.z*.19-flow_time*.8);
 float edge=1.-smoothstep(.25+wash*.3,1.,COLOR.r);
 float distance_fade=1.-smoothstep(75.,120.,distance(CAMERA_POSITION_WORLD,shore_point));
 ALBEDO=vec3(.56,.68,.66);ALPHA=edge*(.08+wash*.24)*distance_fade;
}
