shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 land_color : source_color = vec4(.32,.24,.20,1);
uniform vec4 sea_color : source_color = vec4(.06,.18,.23,1);
uniform vec4 cloud_color : source_color = vec4(.75,.78,.71,1);
uniform bool gas_bands = false;
uniform bool authored_relief = false;
uniform bool molten = false;
uniform float cloud_amount = .5;
uniform vec4 rock_color:source_color=vec4(.2,.15,.13,1);
uniform float seed_offset = 0.;
uniform float sea_level = .43;
varying vec3 local_position;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7))+seed_offset)*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1)),f.x),f.y),f.z);}
float fbm(vec3 p){return .57*noise3(p)+.28*noise3(p*2.07)+.15*noise3(p*4.13);}
void vertex(){local_position=VERTEX;}
void fragment(){
 vec3 p=normalize(local_position);float h=mix(fbm(p*4.3),COLOR.r,.45*float(authored_relief));
 vec3 land=mix(rock_color.rgb,land_color.rgb,smoothstep(.28,.65,h));
 land*=mix(.78,1.08,COLOR.g);
 float coast=smoothstep(sea_level-.012,sea_level+.012,h);
 vec3 surface=mix(sea_color.rgb,land,coast);
 float strata=smoothstep(.49,.51,noise3(p*22.));surface*=mix(.92,1.03,strata);
 vec3 wind=p;wind.x+=sin(p.y*9.)*.10;wind.z+=TIME*.001;
 float cloud=smoothstep(.72-cloud_amount*.18,.82-cloud_amount*.18,fbm(wind*6.))*cloud_amount;
 if(gas_bands){
  float latitude=p.y;
  float longitude=atan(p.z,p.x)+TIME*.012*(1.+sin(latitude*14.)*.3);
  vec3 flow=vec3(cos(longitude)*sqrt(max(0.,1.-latitude*latitude)),latitude,sin(longitude)*sqrt(max(0.,1.-latitude*latitude)));
  float dx=atan(sin(longitude-seed_offset),cos(longitude-seed_offset));
  float dy=latitude+.22;
  float storm=exp(-pow(dx/.38,2.)-pow(dy/.16,2.));
  float spiral=sin(atan(dy/.16,dx/.38)*2.+length(vec2(dx/.38,dy/.16))*14.-TIME*.25);
  float band=sin(latitude*(25.+mod(seed_offset,20.))+fbm(flow*6.)*4.+storm*spiral*2.);
  surface=mix(sea_color.rgb,land_color.rgb,smoothstep(-.2,.2,band));
  surface=mix(surface,rock_color.rgb,storm*(.5+.18*spiral));
  cloud=smoothstep(.60,.76,fbm(flow*9.))*.3;
  float flash=pow(max(0.,sin(TIME*1.7+seed_offset)),45.)*storm;
  EMISSION=vec3(.4,.65,1.)*flash*.45;
 }
 if(molten){float fissure=1.-smoothstep(.02,.065,abs(fbm(p*12.)-.5));surface=mix(surface,vec3(.85,.14,.015),fissure*.8);EMISSION=vec3(1.,.15,.008)*fissure*1.4;}
 ALBEDO=mix(surface,cloud_color.rgb,cloud*.84);ROUGHNESS=.92;
}
