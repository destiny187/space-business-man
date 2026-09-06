shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 rock_color : source_color = vec4(.43,.32,.25,1);
uniform vec4 dust_color : source_color = vec4(.67,.53,.39,1);
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 float terrace=sin(world_position.y*.60+sin(world_position.x*.045)*.55)*.5+.5;
 vec3 strata=mix(rock_color.rgb*.76,rock_color.rgb*1.16,smoothstep(.23,.70,terrace));
 float upward=smoothstep(.50,.88,normalize(world_normal).y);
 ALBEDO=mix(strata,dust_color.rgb,upward*.87);ROUGHNESS=.96;
}
