shader_type spatial;
render_mode cull_disabled;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1);
uniform float flow_time=0.;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float ripple=sin(world_pos.x*2.7+world_pos.z*1.3-flow_time*2.4)*sin(world_pos.z*3.1+flow_time);
 float crest=smoothstep(.91,1.,ripple);
 ALBEDO=mix(water_color.rgb,vec3(.42,.7,.74),crest*.45);
 ROUGHNESS=.35;
}
