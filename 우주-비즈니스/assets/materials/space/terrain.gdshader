shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 rock_color : source_color = vec4(.43,.32,.25,1);
uniform vec4 dust_color : source_color = vec4(.67,.53,.39,1);
uniform float salt_crust = 0.0;
uniform float soil_recovery = 0.0;
uniform float restoration = 0.0;
uniform bool molten=false;
uniform float local_heat=1.;
uniform int surface_pattern=0;
uniform float geology_phase=0.;
uniform int biome_style=-1;
uniform vec3 restoration_center = vec3(0.0);
uniform float restoration_radius = 65.0;
varying vec3 world_position;
varying vec3 world_normal;
float ground_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float ground_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(ground_hash(i),ground_hash(i+vec2(1,0)),f.x),mix(ground_hash(i+vec2(0,1)),ground_hash(i+vec2(1)),f.x),f.y);}
// Kept in metre coordinates with FrontierSurfaceGeology.sample (CPU placement).
vec3 geology(vec2 p){
 vec2 q=p+vec2(geology_phase*13.,geology_phase*7.);
 float exposure=sin(q.x*.045+sin(q.y*.023)*1.8)*.6+sin(q.y*.073+q.x*.019)*.35+sin(q.x*.14-q.y*.09)*.12;
 float rock=smoothstep(-.12,.48,exposure);
 float bend=q.y+sin(q.x*.017+geology_phase)*17.+sin(q.x*.057)*4.;
 float d=abs(sin(bend*.022+geology_phase))/.022;
 float wash=1.-smoothstep(1.8,6.5,d);
 return vec3(rock,wash,(1.-rock)*(1.-wash));
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 float terrace=sin(world_position.y*.60+sin(world_position.x*.045)*.55)*.5+.5;
 vec3 strata=mix(rock_color.rgb*.76,rock_color.rgb*1.16,smoothstep(.23,.70,terrace));
 float upward=smoothstep(.50,.88,normalize(world_normal).y);
 ALBEDO=mix(strata,dust_color.rgb,upward*.87);
 // Broad sediment patches retain readable colour planes at walking distance.
 float patches=ground_noise(world_position.xz*.16);
 ALBEDO*=mix(.89,1.06,smoothstep(.2,.8,patches)*upward);
 vec2 gp=world_position.xz;
 float wave=sin(gp.x*2.6+ground_noise(gp*.23)*5.+gp.y*.25);
 float near_detail=1.-smoothstep(18.,45.,distance(CAMERA_POSITION_WORLD,world_position));
 if(surface_pattern==1){
  vec3 geo=geology(gp);
  // Sand, oxidized subsoil and worn bedrock share the scatter/relief masks.
  vec3 sand=mix(dust_color.rgb*1.5,vec3(.56,.35,.16),.65);
  vec3 bedrock=mix(rock_color.rgb*1.25,dust_color.rgb*.72,.35);
  vec3 soil=mix(dust_color.rgb*.86,bedrock,geo.x*.87);
  vec3 surface=mix(soil,sand,smoothstep(.12,.85,geo.z));
  surface=mix(surface,mix(sand,bedrock,.55),geo.y*.72);
  float sediment=ground_noise(gp*.5+ground_noise(gp*.06)*4.);
  surface*=mix(.92,1.07,sediment);
  ALBEDO=mix(ALBEDO,surface,upward);
  // Short ripples only on sand deposits; no continuous ruled lines across rock.
  float ripple=sin(gp.x*3.7+gp.y*.6+ground_noise(gp*.35)*9.);
  float aa=max(fwidth(ripple),.12);
  float line=(1.-smoothstep(.05,.05+aa,abs(ripple)))*smoothstep(.42,.67,sediment);
  ALBEDO*=1.-line*.07*geo.z*near_detail;
  float chips=ground_noise(gp*2.1+vec2(ground_noise(gp*.27)*3.));
  float worn=smoothstep(.61,.83,chips)*smoothstep(.4,.7,sediment);
  ALBEDO=mix(ALBEDO,ALBEDO*1.19,worn*geo.x*near_detail*upward);
 }
 if(surface_pattern==2){
  float aa=max(fwidth(wave),.06);
  float line=1.-smoothstep(.04,.04+aa,abs(wave));
  ALBEDO*=1.-line*.10*upward*near_detail;
 }
 if(surface_pattern==3){
  vec2 cell=gp*.7;vec2 grid=floor(cell);float first=10.;float second=10.;
  for(int x=-1;x<=1;x++){for(int z=-1;z<=1;z++){
   vec2 offset=vec2(float(x),float(z));vec2 q=grid+offset;
   vec2 delta=offset+vec2(ground_hash(q),ground_hash(q+71.))-fract(cell);
   float d=dot(delta,delta);if(d<first){second=first;first=d;}else{second=min(second,d);}
  }}
  float edge=second-first;float aa=max(fwidth(edge),.025);
  float crack=1.-smoothstep(.035,.035+aa,edge);
  ALBEDO*=1.-crack*.20*upward*near_detail;
 }
 // Distinct broad surface regions; visual only, no height/collision/save changes.
 float region=ground_noise(gp*.025+vec2(geology_phase));
 float grain=ground_noise(gp*.38+region*3.);
 float patch_edge=smoothstep(.38,.62,region);
 if(biome_style==1 || biome_style==4){
  vec3 dry=mix(dust_color.rgb,rock_color.rgb,.30);
  vec3 damp=mix(rock_color.rgb,dust_color.rgb*.66,.30);
  ALBEDO=mix(ALBEDO,mix(dry,damp,patch_edge),upward*.64);
  float fleck=smoothstep(.65,.84,grain)*near_detail;
  ALBEDO=mix(ALBEDO,dust_color.rgb*1.12,fleck*.12*upward);
 }
 if(biome_style==3 || biome_style==5){
  vec3 bare=mix(rock_color.rgb,vec3(.20,.39,.46),.28);
  vec3 drift=mix(dust_color.rgb,vec3(.74,.81,.80),.40);
  ALBEDO=mix(ALBEDO,mix(bare,drift,smoothstep(.29,.70,region)),upward*.66);
 }
 if(biome_style==2 || biome_style==8){
  float beds=smoothstep(.44,.58,ground_noise(gp*.045+region*2.));
  ALBEDO=mix(ALBEDO,mix(rock_color.rgb*.94,dust_color.rgb*1.13,beds),upward*.54);
 }
 if(biome_style==7){
  float crust=smoothstep(.38,.57,region);
  ALBEDO=mix(ALBEDO,mix(rock_color.rgb*.8,dust_color.rgb*1.16,crust),upward*.58);
 }
 if(biome_style==6){
  float ash=smoothstep(.35,.66,region);
  ALBEDO=mix(ALBEDO,mix(rock_color.rgb*.60,dust_color.rgb*.87,ash),upward*.72);
 }
 float managed=1.0-smoothstep(restoration_radius*.7,restoration_radius,distance(world_position.xz,restoration_center.xz));
 float salt_patch=smoothstep(.4,.68,patches)*salt_crust*managed*upward;
 ALBEDO=mix(ALBEDO,vec3(.72,.70,.58),salt_patch*.65);
 ALBEDO=mix(ALBEDO,vec3(.23,.18,.12),soil_recovery*managed*upward*.30);
 ALBEDO=mix(ALBEDO,vec3(.22,.35,.22),restoration*managed*upward*.72);ROUGHNESS=.96;
 if(molten){float heat=mix(1.,local_heat,managed);float fissure=1.-smoothstep(.025,.1,abs(sin(world_position.x*.17+sin(world_position.z*.13)*2.)));
 float pulse=.85+.15*sin(TIME*1.3+world_position.z*.2);ALBEDO=mix(ALBEDO,vec3(.65,.07,.005),fissure*heat);EMISSION=vec3(1.,.12,.005)*fissure*heat*pulse*1.6;}

}
