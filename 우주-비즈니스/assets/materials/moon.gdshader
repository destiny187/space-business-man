shader_type spatial;
render_mode diffuse_burley, specular_disabled;
varying vec3 local_pos;
float hash(vec3 p){ return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p){ vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1)),f.x),f.y),f.z); }
void vertex(){ local_pos=VERTEX; }
void fragment(){
 vec3 p=normalize(local_pos);
 float maria=noise(p*6.0)*.7+noise(p*18.0)*.3;
 float craters=smoothstep(.68,.77,noise(p*25.0))*.08;
 ALBEDO=mix(vec3(.21,.16,.17),vec3(.64,.48,.35),smoothstep(.29,.65,maria))-craters;
 ROUGHNESS=1.0;
}
