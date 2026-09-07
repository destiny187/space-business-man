shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float wave=sin(world_pos.x*.5+TIME*.6)+sin(world_pos.z*.65-TIME*.5);
 ALBEDO=mix(water_color.rgb,vec3(.55,.75,.8),smoothstep(1.85,2.,wave)*.3);
 NORMAL=normalize((VIEW_MATRIX*vec4(-cos(world_pos.x*.5+TIME*.6)*.05,1.,-cos(world_pos.z*.65-TIME*.5)*.05,0.)).xyz);
 ROUGHNESS=.3;
}
