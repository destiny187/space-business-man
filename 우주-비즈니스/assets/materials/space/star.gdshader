shader_type spatial;
render_mode unshaded;
uniform vec4 tint:source_color=vec4(1.,.65,.22,1.);
uniform int mode=0;
uniform float seed_offset=0.;
uniform float surface_speed=.025;
uniform float cell_scale=18.;
uniform float radiance=1.65;
uniform float limb_darkening=.55;
varying vec3 surface_point;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7))+seed_offset)*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1)),f.x),f.y),f.z);}
void vertex(){surface_point=normalize(VERTEX);}
void fragment(){
 vec3 p=normalize(surface_point);float t=TIME*surface_speed;
 p=vec3(p.x*cos(t)-p.z*sin(t),p.y,p.x*sin(t)+p.z*cos(t));
 float broad=noise3(p*cell_scale+seed_offset);
 float fine=noise3(p*cell_scale*2.7+vec3(0,t,0));
 float cells=broad*.8+fine*.2;
 // Continuous, low-contrast granulation: the star reads as a luminous body.
 float mu=max(dot(normalize(NORMAL),normalize(VIEW)),0.);
 float limb=1.-limb_darkening*(1.-mu);
 float granulation=1.+(cells-.5)*.22;
 vec3 hot=mix(tint.rgb,vec3(1.),.45);
 vec3 color=mix(tint.rgb,hot,sqrt(mu)) * granulation * limb;
 if(mode==1){color*=.94+.06*broad;}
 if(mode==2){color=mix(color,hot*limb,.35);}
 if(mode==3){
  float spots=smoothstep(.69,.82,noise3(p*5.7+seed_offset));
  color*=1.-spots*.46;
 }
 ALBEDO=color*radiance;
}
