shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
varying vec3 world_pos;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment(){
 float seam=sin(world_pos.y*2.3+sin(world_pos.x*.12)*1.6+sin(world_pos.z*.18));
 float band=smoothstep(.56,.85,seam);
 float sediment=.5+.5*sin(world_pos.y*.51+world_pos.x*.019);
 vec3 mineral=mix(vec3(.19,.135,.12),vec3(.36,.235,.15),floor(sediment*3.)/3.);
 vec3 world_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0)).xyz);
 float cap=smoothstep(.35,.9,world_normal.y);
 ALBEDO=mix(mineral*(1.0-band*.16),vec3(.43,.31,.20),cap*.4);
 ROUGHNESS=.96;
}
