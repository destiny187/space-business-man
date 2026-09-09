shader_type spatial;
render_mode cull_disabled;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
#include "res://assets/materials/space/water_surface.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1);
uniform float flow_time=0.;
varying vec3 world_pos;
varying float top_face;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;top_face=max(NORMAL.y,0.);}
void fragment(){
 float distance_to_eye=length(VERTEX);
 float detail=1.-smoothstep(25.,110.,distance_to_eye);
 vec3 wave=water_wave(world_pos.xz,flow_time,detail);
 if(top_face>.5) NORMAL=normalize((VIEW_MATRIX*vec4(-wave.y*.34,1.,-wave.z*.34,0.)).xyz);
 float fresnel=pow(1.-max(dot(NORMAL,VIEW),0.),4.);
 ALBEDO=water_tint(water_color.rgb,wave,world_pos.xz,flow_time,distance_to_eye,fresnel);
 ROUGHNESS=water_quality==0 ? .65 : .32;
}
