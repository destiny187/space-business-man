shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 land_color : source_color = vec4(.32,.24,.20,1);
uniform vec4 sea_color : source_color = vec4(.06,.18,.23,1);
uniform vec4 cloud_color : source_color = vec4(.75,.78,.71,1);
uniform float seed_offset = 0.;
uniform float sea_level = .43;
varying vec3 local_position;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7))+seed_offset)*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1)),f.x),f.y),f.z);}
float fbm(vec3 p){return .57*noise3(p)+.28*noise3(p*2.07)+.15*noise3(p*4.13);}
void vertex(){local_position=VERTEX;}
void fragment(){
 vec3 p=normalize(local_position);float h=fbm(p*4.3);
 vec3 land=land_color.rgb*mix(.68,1.2,smoothstep(.4,.72,h));
 float coast=smoothstep(sea_level-.012,sea_level+.012,h);
 vec3 surface=mix(sea_color.rgb,land,coast);
 float strata=smoothstep(.49,.51,noise3(p*22.));surface*=mix(.92,1.03,strata);
 vec3 wind=p;wind.x+=sin(p.y*9.)*.10;wind.z+=TIME*.001;
 float cloud=smoothstep(.59,.68,fbm(wind*6.));
 ALBEDO=mix(surface,cloud_color.rgb,cloud*.84);ROUGHNESS=.92;
}
