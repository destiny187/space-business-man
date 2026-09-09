shader_type canvas_item;
uniform float atmosphere=1.0;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.65, 0.69, 0.72, 1.0);
#include "res://assets/materials/space/arrival_smoke.gdshaderinc"
uniform float flow_time=-1.0;
void fragment() {
 float clock=flow_time<0.0?TIME:flow_time;
 vec2 p=(UV-0.5)*vec2(6.0,4.0)+vec2(clock*0.12,clock*0.45);
 float n=smoke_density(p,clock);
 float a=smoothstep(0.0,0.8,cover*2.0-0.7+n*0.35);
 vec3 vacuum=tint.rgb*.10+vec3(.012,.018,.025)*(1.0-UV.y);
 COLOR=vec4(mix(vacuum,tint.rgb*(0.82+n*0.18),atmosphere),a);
}
