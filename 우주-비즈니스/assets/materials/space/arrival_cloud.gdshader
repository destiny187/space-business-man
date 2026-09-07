shader_type canvas_item;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.65, 0.69, 0.72, 1.0);
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 vec4 n=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(n.x,n.y,f.x),mix(n.z,n.w,f.x),f.y);
}
void fragment() {
 vec2 p=(UV-0.5)*vec2(6.0,4.0)+vec2(TIME*0.12,TIME*0.45);
 float n=noise(p)+0.35*noise(p*2.7);
 float a=smoothstep(0.0,0.8,cover*2.0-0.7+n*0.35);
 COLOR=vec4(tint.rgb*(0.82+n*0.18),a);
}
