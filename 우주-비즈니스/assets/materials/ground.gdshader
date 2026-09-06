shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 soil : source_color = vec4(0.32,0.24,0.21,1.0);
uniform float growth : hint_range(0,1) = 0.0;
varying vec3 world_pos;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y); }
float height_at(vec2 p){ return noise(p*2.8)*0.065+noise(p*9.0)*0.018+sin(p.x*2.1+p.y*.65+noise(p*.2)*8.0)*.024; }
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment(){
 vec2 p=world_pos.xz;
 float broad=noise(p*.055);
 float patches=noise(p*.32);
 float grit=noise(p*9.0);
 float greenery=smoothstep(.34,.7,broad+patches*.12)*growth;
 float close_detail=1.0-smoothstep(12.0,42.0,length(VERTEX));
 vec3 dry=soil.rgb*(.68+broad*.38+patches*.15+(grit-.5)*.16*close_detail);
 ALBEDO=mix(dry,vec3(.105,.19,.075)*(0.8+patches*.4),greenery*.82);
 // World-space bump detail avoids a high-density mesh or a giant terrain texture.
 float h=height_at(p);
 vec2 slope=vec2(height_at(p+vec2(.035,0))-h,height_at(p+vec2(0,.035))-h)/.035;
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz+vec3(-slope.x,0,-slope.y)*close_detail*.65);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 ROUGHNESS=mix(.94,.78,greenery);
 SPECULAR=.22;
 AO=.92+.08*patches;
}
