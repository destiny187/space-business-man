shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 rock_color : source_color = vec4(.43,.32,.25,1);
uniform vec4 dust_color : source_color = vec4(.67,.53,.39,1);
uniform float restoration = 0.0;
uniform bool molten=false;
uniform float local_heat=1.;
uniform vec3 restoration_center = vec3(0.0);
uniform float restoration_radius = 65.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 float terrace=sin(world_position.y*.60+sin(world_position.x*.045)*.55)*.5+.5;
 vec3 strata=mix(rock_color.rgb*.76,rock_color.rgb*1.16,smoothstep(.23,.70,terrace));
 float upward=smoothstep(.50,.88,normalize(world_normal).y);
 ALBEDO=mix(strata,dust_color.rgb,upward*.87);float managed=1.0-smoothstep(restoration_radius*.7,restoration_radius,distance(world_position.xz,restoration_center.xz));
 ALBEDO=mix(ALBEDO,vec3(.22,.35,.22),restoration*managed*upward*.72);ROUGHNESS=.96;
 if(molten){float heat=mix(1.,local_heat,managed);float fissure=1.-smoothstep(.025,.1,abs(sin(world_position.x*.17+sin(world_position.z*.13)*2.)));
 float pulse=.85+.15*sin(TIME*1.3+world_position.z*.2);ALBEDO=mix(ALBEDO,vec3(.65,.07,.005),fissure*heat);EMISSION=vec3(1.,.12,.005)*fissure*heat*pulse*1.6;}

}
