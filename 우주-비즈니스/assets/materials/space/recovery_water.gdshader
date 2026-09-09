shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform float amount=0.0;
uniform float flow_time=0.0;
uniform float gust=0.0;
void fragment(){
 vec2 p=(UV-.5)*2.;
 float edge=length(p)+sin(p.x*7.+p.y*3.)*.10+sin(p.y*9.)*.08;
 float rim=1.-smoothstep(amount*.68,amount*.98,edge);
 float wave=sin(length(p)*45.-flow_time*1.6)*.5+.5;
 ALBEDO=mix(vec3(.10,.22,.23),vec3(.27,.43,.40),step(.83,wave)*.2);
 ROUGHNESS=.27;ALPHA=rim*.64;
 NORMAL=normalize(NORMAL+vec3(cos(p.x*25.+flow_time)*.035,cos(p.y*25.-flow_time)*.035,0.)*(.2+gust));
}
