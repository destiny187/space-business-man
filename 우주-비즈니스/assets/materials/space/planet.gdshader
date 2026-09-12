shader_type spatial;
#define INK_SPACE_LIGHTING
#define INK_ORBITAL_SURFACE
#include "res://assets/materials/space/illumination.gdshaderinc"
#include "res://assets/materials/space/cloud_field.gdshaderinc"
#include "res://assets/materials/space/terraform_field.gdshaderinc"
#include "res://assets/materials/space/surface_detail.gdshaderinc"
uniform bool separate_clouds=false;
uniform float cloud_shadow_strength=.36;
uniform vec3 local_sun_direction=vec3(0,1,0);
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 land_color : source_color = vec4(.32,.24,.20,1);
uniform vec4 sea_color : source_color = vec4(.06,.18,.23,1);
uniform vec4 cloud_color : source_color = vec4(.75,.78,.71,1);
uniform float surface_temperature=20.;
uniform float surface_water=0.;
uniform int geology_style=0;
uniform bool gas_bands = false;
uniform bool authored_relief = false;
uniform bool molten = false;
uniform float cloud_amount = .5;
uniform vec4 rock_color:source_color=vec4(.2,.15,.13,1);
uniform float seed_offset = 0.;
uniform float sea_level = .43;
uniform float visual_time = -1.0;
varying vec3 local_position;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7))+seed_offset)*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1)),f.x),f.y),f.z);}
float fbm(vec3 p){float pixel=max(length(dFdx(p)),length(dFdy(p)));return .57*noise3(p)+.28*mix(noise3(p*2.07),.5,smoothstep(.15,.5,pixel*2.07))+.15*mix(noise3(p*4.13),.5,smoothstep(.15,.5,pixel*4.13));}
void vertex(){local_position=VERTEX;space_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float cycle_time=visual_time<0.0?TIME:visual_time;
 vec3 p=normalize(local_position);
 vec3 masks=orbital_maps_enabled?orbital_map(orbital_relief,p):COLOR.rgb;
 float h=mix(fbm(p*4.3),masks.r,.45*float(authored_relief));
 vec3 detail_point=p;
 vec4 recovery=terraform_field(p);float footprint=terraform_footprint(p);
 float local_sea_level=mix(sea_level,max(sea_level,terraform_sea_level),recovery.y);
 vec3 land=mix(rock_color.rgb,land_color.rgb,orbital_edge(.28,.65,h));
 land*=mix(.78,1.08,masks.g);
 land=mix(land,mix(terraform_land.rgb,terraform_highland.rgb,orbital_edge(.53,.7,h)),sqrt(recovery.x));
 float coast=orbital_edge(local_sea_level-.012,local_sea_level+.012,h);
 // Broad shelf / highland regions, with detail carried by authored relief masks.
 float shelf=orbital_edge(local_sea_level-.08,local_sea_level-.015,h)*(1.-coast);
 vec3 sea=mix(sea_color.rgb,terraform_sea.rgb,recovery.y);
 vec3 ocean=mix(sea*.73,sea*1.18,shelf);
 vec3 surface=mix(ocean,land,coast);
 if(!gas_bands){
  float freeze=1.-orbital_edge(-3.,3.,mix(surface_temperature,recovery.z,footprint)+12.-abs(p.y)*36.);
  vec3 ice=mix(vec3(.34,.56,.65),vec3(.79,.86,.86),orbital_edge(.2,.8,masks.b));
  surface=mix(surface,ice,freeze*(1.-coast)*step(.001,surface_water));
  float frost=freeze*surface_water*orbital_edge(.12,.78,abs(p.y))*coast;
  surface=mix(surface,vec3(.76,.82,.82),frost);
  if(geology_style==1){float beds=orbital_edge(.3,.7,masks.b);surface=mix(surface,mix(rock_color.rgb,land_color.rgb*1.16,beds),coast*.52);}
  if(geology_style==2){float outcrop=orbital_edge(.48,.8,masks.b);surface=mix(surface,vec3(.68,.77,.80),outcrop*coast*.45);}
  if(geology_style==3){float vein=orbital_edge(.45,.85,masks.b);surface=mix(surface,land_color.rgb*1.2,vein*coast*.6);}
 }
 float highland=orbital_edge(.57,.76,h)*float(authored_relief);
 surface=mix(surface,mix(rock_color.rgb*1.12,terraform_highland.rgb,recovery.x),highland*.32);
 float shore=(1.-orbital_edge(.01,.025,abs(h-local_sea_level)))*step(.05,local_sea_level);
 surface=mix(surface,mix(land_color.rgb,cloud_color.rgb,.24),shore*.23);
 float relief_detail=mix(.95,1.04,masks.b);
 surface*=mix(1.,relief_detail,float(authored_relief));
 float strata=orbital_edge(.28,.72,noise3(p*22.));surface*=mix(.965,1.025,strata);
 vec3 wind=p;wind.x+=sin(p.y*9.)*.10;wind.z+=cycle_time*.001;
 float local_cloud=mix(cloud_amount,max(cloud_amount,terraform_cloud_coverage),recovery.y*recovery.w);
 float cloud=orbital_edge(.72-local_cloud*.18,.82-local_cloud*.18,fbm(wind*6.))*local_cloud;
 if(gas_bands){
  float latitude=p.y;
  float longitude=atan(p.z,p.x)+cycle_time*.012*(1.+sin(latitude*14.)*.3);
  vec3 flow=vec3(cos(longitude)*sqrt(max(0.,1.-latitude*latitude)),latitude,sin(longitude)*sqrt(max(0.,1.-latitude*latitude)));
  detail_point=flow;
  float dx=atan(sin(longitude-seed_offset),cos(longitude-seed_offset));
  float dy=latitude+.22;
  float storm=exp(-pow(dx/.38,2.)-pow(dy/.16,2.));
  float spiral=sin(atan(dy/.16,dx/.38)*2.+length(vec2(dx/.38,dy/.16))*14.-cycle_time*.25);
  float band=sin(latitude*(25.+mod(seed_offset,20.))+fbm(flow*6.)*4.+storm*spiral*2.);
  float belt=orbital_edge(-.45,.4,band);
  surface=mix(sea_color.rgb,land_color.rgb,belt);
  float filament=sin(latitude*73.+fbm(flow*13.)*2.+storm*spiral);
  surface=mix(surface,cloud_color.rgb,orbital_edge(.45,.85,filament)*.075);
  surface=mix(surface,rock_color.rgb,storm*(.5+.18*spiral));
  cloud=orbital_edge(.60,.76,fbm(flow*9.))*.3;
  float flash=pow(max(0.,sin(cycle_time*1.7+seed_offset)),45.)*storm;
  EMISSION=vec3(.4,.65,1.)*flash*.45;
 }
 if(molten){float fissure=(1.-orbital_edge(.02,.065,abs(fbm(p*12.)-.5)))*(1.-footprint*(1.-orbital_edge(40.,100.,recovery.z)));surface=mix(surface,vec3(.85,.14,.015),fissure*.8);EMISSION=vec3(1.,.15,.008)*fissure*1.4;}
 if(separate_clouds){
  float shade=cloud_field_amount(normalize(p+normalize(local_sun_direction)*.018),mix(cloud_coverage,max(cloud_coverage,terraform_cloud_coverage),recovery.y*recovery.w));
  surface*=1.0-shade*cloud_shadow_strength;
  float distance_fade=orbital_edge(22.0,30.0,length(VERTEX)/max(length(MODEL_MATRIX[0].xyz),.01));
  cloud*=distance_fade;
 }
 vec2 detail=orbital_detail_field(detail_point,coast,gas_bands);
 surface*=1.+detail.x;
 if(orbital_surface_quality>1 && !gas_bands)NORMAL=orbital_detail_normal(NORMAL,VERTEX,detail.y*length(MODEL_MATRIX[0].xyz));
 ALBEDO=mix(surface,cloud_color.rgb,cloud*.84);ROUGHNESS=gas_bands?.92:mix(.42,.94,coast);
}
