shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float layer = 0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=(UV-.5)*2.0;float r=length(p);float a=atan(p.y,p.x);
 float n=noise(p*19.0+layer)*.55+noise(p*48.0)*.3+noise(p*113.0)*.15;
 float spiral=pow(.5+.5*cos(a*4.0-r*16.0+n*3.0),5.0);
 float core=exp(-r*r*55.0);float disk=exp(-r*2.8)*smoothstep(1.0,.65,r);
 float dust=smoothstep(.24,.65,n);
 vec3 arms=mix(vec3(.12,.23,.52),vec3(.36,.58,.88),n);
 ALBEDO=mix(arms,vec3(1.0,.72,.42),core);EMISSION=(arms*spiral*disk*dust*1.7+vec3(1.0,.68,.35)*core*1.5+vec3(.22,.18,.36)*disk*.09);
 ALPHA=clamp((spiral*disk*dust*.65+core*.65)*.38,0.0,.65);
}
