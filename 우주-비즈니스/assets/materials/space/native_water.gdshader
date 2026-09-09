shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1);
uniform float flow_time=0.;
uniform sampler2D terrain_mask:filter_linear,repeat_disable;
uniform vec2 mask_origin=vec2(0.);
uniform bool mask_ready=false;
uniform bool viewer_under_land=false;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 mask_uv=(world_pos.xz-mask_origin)/512.;
 bool inside=all(greaterThanEqual(mask_uv,vec2(0.))) && all(lessThan(mask_uv,vec2(1.)));
 if(mask_ready && inside && texture(terrain_mask,mask_uv).r>0.) discard;
 if(viewer_under_land && (!mask_ready || !inside)) discard;
 float wave=sin(world_pos.x*.5+flow_time*.6)+sin(world_pos.z*.65-flow_time*.5);
 ALBEDO=mix(water_color.rgb,vec3(.55,.75,.8),smoothstep(1.85,2.,wave)*.3);
 NORMAL=normalize((VIEW_MATRIX*vec4(-cos(world_pos.x*.5+flow_time*.6)*.05,1.,-cos(world_pos.z*.65-flow_time*.5)*.05,0.)).xyz);
 ROUGHNESS=.3;
 float swell=sin(world_pos.x*.065+world_pos.z*.027-flow_time*.35);
 ALBEDO*=.94+.06*swell;
}
