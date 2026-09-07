shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 rock_color : source_color = vec4(.43,.32,.25,1);
uniform vec4 dust_color : source_color = vec4(.67,.53,.39,1);
uniform float restoration = 0.0;
uniform bool molten=false;
uniform float local_heat=1.;
uniform int surface_pattern=0;
uniform vec3 restoration_center = vec3(0.0);
uniform float restoration_radius = 65.0;
varying vec3 world_position;
varying vec3 world_normal;
float ground_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float ground_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(ground_hash(i),ground_hash(i+vec2(1,0)),f.x),mix(ground_hash(i+vec2(0,1)),ground_hash(i+vec2(1)),f.x),f.y);}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 float terrace=sin(world_position.y*.60+sin(world_position.x*.045)*.55)*.5+.5;
 vec3 strata=mix(rock_color.rgb*.76,rock_color.rgb*1.16,smoothstep(.23,.70,terrace));
 float upward=smoothstep(.50,.88,normalize(world_normal).y);
 ALBEDO=mix(strata,dust_color.rgb,upward*.87);
 // Broad sediment patches retain readable colour planes at walking distance.
 float patches=ground_noise(world_position.xz*.16);
 ALBEDO*=mix(.89,1.06,smoothstep(.2,.8,patches)*upward);
 vec2 gp=world_position.xz;
 float wave=sin(gp.x*2.6+ground_noise(gp*.23)*5.+gp.y*.25);
 float near_detail=1.-smoothstep(18.,45.,distance(CAMERA_POSITION_WORLD,world_position));
 if(surface_pattern==1 || surface_pattern==2){
  float aa=max(fwidth(wave),.06);
  float line=1.-smoothstep(.04,.04+aa,abs(wave));
  ALBEDO*=1.-line*.10*upward*near_detail;
 }
 if(surface_pattern==3){
  vec2 cell=gp*.7;vec2 grid=floor(cell);float first=10.;float second=10.;
  for(int x=-1;x<=1;x++){for(int z=-1;z<=1;z++){
   vec2 offset=vec2(float(x),float(z));vec2 q=grid+offset;
   vec2 delta=offset+vec2(ground_hash(q),ground_hash(q+71.))-fract(cell);
   float d=dot(delta,delta);if(d<first){second=first;first=d;}else{second=min(second,d);}
  }}
  float edge=second-first;float aa=max(fwidth(edge),.025);
  float crack=1.-smoothstep(.035,.035+aa,edge);
  ALBEDO*=1.-crack*.20*upward*near_detail;
 }
 float managed=1.0-smoothstep(restoration_radius*.7,restoration_radius,distance(world_position.xz,restoration_center.xz));
 ALBEDO=mix(ALBEDO,vec3(.22,.35,.22),restoration*managed*upward*.72);ROUGHNESS=.96;
 if(molten){float heat=mix(1.,local_heat,managed);float fissure=1.-smoothstep(.025,.1,abs(sin(world_position.x*.17+sin(world_position.z*.13)*2.)));
 float pulse=.85+.15*sin(TIME*1.3+world_position.z*.2);ALBEDO=mix(ALBEDO,vec3(.65,.07,.005),fissure*heat);EMISSION=vec3(1.,.12,.005)*fissure*heat*pulse*1.6;}

}
