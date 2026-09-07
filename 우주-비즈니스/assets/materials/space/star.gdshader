shader_type spatial;
render_mode unshaded;
uniform vec4 tint:source_color=vec4(1.,.65,.22,1.);
uniform int mode=0;
uniform float seed_offset=0.;
uniform float surface_speed=.025;
uniform float cell_scale=18.;
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
 float bands=.58+.26*smoothstep(.34,.38,cells)+.24*smoothstep(.60,.64,cells);
 float limb=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.),.5);
 vec3 color=tint.rgb*bands*(.9+limb*.5);
 if(mode==1){color*=.75+.25*smoothstep(.28,.5,broad);}
 if(mode==2){float stream=sin(p.y*42.+broad*5.+t*5.);color=mix(color,tint.rgb*1.5,smoothstep(.8,1.,stream)*.18);}
 if(mode==3){float spots=smoothstep(.64,.75,noise3(p*5.7+seed_offset));color*=1.-spots*.83;float flare=pow(max(0.,sin(TIME*.4+seed_offset)),14.);color+=tint.rgb*flare*smoothstep(.69,.79,broad)*.28;}
 ALBEDO=color;
}
