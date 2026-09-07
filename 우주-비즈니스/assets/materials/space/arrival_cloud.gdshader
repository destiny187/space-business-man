shader_type canvas_item;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.65, 0.69, 0.72, 1.0);
#include "res://assets/materials/space/arrival_smoke.gdshaderinc"
void fragment() {
 vec2 p=(UV-0.5)*vec2(6.0,4.0)+vec2(TIME*0.12,TIME*0.45);
 float n=smoke_density(p,TIME);
 float a=smoothstep(0.0,0.8,cover*2.0-0.7+n*0.35);
 COLOR=vec4(tint.rgb*(0.82+n*0.18),a);
}
