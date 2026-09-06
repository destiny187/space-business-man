shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
uniform bool rock = false;
uniform bool distant = false;
float hash(vec3 p){p=fract(p*.3183099+vec3(.1,.3,.7));p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){if(distant){float d=length(VERTEX.xz); VERTEX.y+=smoothstep(40.,150.,d)*(sin(VERTEX.x*.034)*cos(VERTEX.z*.031)*3.+sin(VERTEX.x*.075+VERTEX.z*.039)*1.8);} world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float n=noise(world_pos*.7)*.65+noise(world_pos*3.7)*.25+noise(world_pos*17.)*.1;
 float strata=sin(world_pos.y*7.+noise(world_pos*1.2)*2.)*.5+.5;
 vec3 sand=mix(vec3(.23,.105,.055),vec3(.56,.32,.18),smoothstep(.15,.85,n));
 if(rock) sand=mix(vec3(.25,.12,.072),vec3(.62,.38,.23),n*.7+strata*.3);
 float moss=smoothstep(.63,.76,noise(world_pos*.23+vec3(3.)))*(1.-float(rock));
 ALBEDO=pow(mix(sand,vec3(.075,.18,.105),moss*.8),vec3(1.65));
 float wet=(1.-smoothstep(-.33,-.10,world_pos.y))*(1.-float(rock));
 ALBEDO*=1.-wet*.25;
 ROUGHNESS=.88-wet*.30;
 // Stable, low-amplitude screen derivatives retain broad hand-shaped surfaces.
 NORMAL=normalize(NORMAL+vec3(dFdx(n),dFdy(n),0.)*.15);
}
