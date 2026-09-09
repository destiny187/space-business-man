shader_type spatial;
#define INK_SURFACE_ROUGHNESS
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 rock_color:source_color=vec4(.43,.32,.25,1);
uniform vec4 dust_color:source_color=vec4(.67,.53,.39,1);
uniform float salt_crust=0.;
uniform float soil_recovery=0.;
uniform float restoration=0.;
uniform int region_count=0;
uniform vec4 region_points[20];
uniform vec4 region_values[20];
uniform vec4 region_extras[20];
uniform float recovery_water=-1.;
uniform float recovery_pressure=0.;
uniform float recovery_life=-1.;
uniform bool molten=false;
uniform float local_heat=1.;
uniform int surface_pattern=0;
uniform int biome_style=-1;
uniform float geology_phase=0.;
uniform vec3 restoration_center=vec3(0.);
uniform float restoration_radius=65.;
uniform bool textured_surface=false;
uniform sampler2DArray surface_textures:filter_linear_mipmap_anisotropic,repeat_enable;
uniform int rock_layer=0;
uniform int deposit_layer=1;
uniform int snow_layer=4;
uniform int ice_layer=5;
uniform float rock_meters=5.;
uniform float deposit_meters=3.5;
uniform float snow_meters=4.5;
uniform float ice_meters=5.5;
uniform float normal_strength=.42;
uniform float detail_near=25.;
uniform float detail_far=95.;
uniform float native_temperature=20.;
uniform float local_temperature=20.;
uniform float volatile_supply=0.;
uniform bool liquid_allowed=false;
uniform float freeze_start=-3.;
uniform float freeze_end=3.;
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

// One packed fetch per contributing axis; linear data, no lighting baked into tone.
vec4 layer(int id,float meters,vec3 p,vec3 n,vec3 weights,out vec3 bump){
 vec3 q=p/meters;vec3 s=sign(n);vec4 value=vec4(0.);bump=vec3(0.);
 if(weights.x>.001){vec4 t=texture(surface_textures,vec3(q.zy*vec2(s.x,1.),float(id)));value+=t*weights.x;bump+=vec3(0.,t.g*2.-1.,(t.r*2.-1.)*s.x)*weights.x;}
 if(weights.y>.001){vec4 t=texture(surface_textures,vec3(q.xz*vec2(1.,-s.y),float(id)));value+=t*weights.y;bump+=vec3(t.r*2.-1.,0.,-(t.g*2.-1.)*s.y)*weights.y;}
 if(weights.z>.001){vec4 t=texture(surface_textures,vec3(q.xy*vec2(-s.z,1.),float(id)));value+=t*weights.z;bump+=vec3(-(t.r*2.-1.)*s.z,t.g*2.-1.,0.)*weights.z;}
 return value;
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 n=normalize(world_normal);float exposure=clamp(COLOR.r,0.,1.);
 float upward=smoothstep(.42,.90,n.y);float skin=upward*exposure;
 vec3 geo=geology(world_position.xz);
 float managed=1.-smoothstep(restoration_radius*.7,restoration_radius,distance(world_position.xz,restoration_center.xz));
 float pollution_value=0.;float local_temp_value=local_temperature;float local_water_value=recovery_water;float local_pressure_value=recovery_pressure;
 float local_life_value=recovery_life;float local_salt_value=salt_crust;float local_soil_value=soil_recovery;float local_restore_value=restoration;
 if(region_count>0){
  managed=0.;
  for(int i=0;i<20;i++){
   if(i>=region_count){break;}
   float w=1.-smoothstep(region_points[i].w*.65,region_points[i].w,distance(world_position.xz,region_points[i].xz));
   if(w>managed){managed=w;local_temp_value=region_values[i].x;local_life_value=region_values[i].y;local_water_value=region_values[i].z;local_pressure_value=region_values[i].w;local_salt_value=region_extras[i].x;local_soil_value=region_extras[i].y;local_restore_value=region_extras[i].z;pollution_value=region_extras[i].w;}
  }
 }
 local_life_value*=1.-pollution_value;local_restore_value*=1.-pollution_value;
 float near_detail=1.-smoothstep(detail_near,detail_far,distance(CAMERA_POSITION_WORLD,world_position));
 float terrace=sin(world_position.y*.65+sin(world_position.x*.043)*.6)*.5+.5;
 vec3 strata=mix(rock_color.rgb*.82,rock_color.rgb*1.09,smoothstep(.2,.8,terrace));
 float deposit=skin*smoothstep(.18,.88,geo.z+geo.y*.75);
 float temp=mix(native_temperature,local_temp_value,managed)+(geo.x-.5)*14.-max(0.,world_position.y-2.)*.012;
 float freeze=1.-smoothstep(freeze_start,freeze_end,temp);
 float supply=mix(volatile_supply,max(0.,local_water_value),managed*step(0.,local_water_value));
 float moisture=supply*(.60+.40*(1.-geo.x));
 float ice=freeze*moisture*(.28+.72*geo.y)*skin;
 float snow=freeze*moisture*smoothstep(.12,.76,geo.z+geo.y*.15)*skin;
 float wet=(1.-freeze)*moisture*(.15+.85*geo.y)*skin*max(float(liquid_allowed),managed*smoothstep(.05,.2,local_pressure_value));
 vec3 bump=vec3(0.);float roughness=.94;
 vec4 rock=vec4(.5,.5,.5,.94);vec4 dirt=rock;
 vec3 br=vec3(0.);vec3 bd=vec3(0.);
 if(textured_surface && near_detail>.001){
  vec3 weights=pow(abs(n),vec3(5.));weights/=max(.001,weights.x+weights.y+weights.z);
  rock=layer(rock_layer,rock_meters,world_position,n,weights,br);
  dirt=layer(deposit_layer,deposit_meters,world_position,n,weights,bd);
  // Raised bedrock breaks through soil; only the local boundary receives height contrast.
  float height_bias=(dirt.b-rock.b)*.65*near_detail;
  deposit=clamp(deposit+height_bias*4.*deposit*(1.-deposit),0.,1.);
 }
 ALBEDO=mix(strata,dust_color.rgb,deposit);
 float tone=mix(rock.b,dirt.b,deposit);
 ALBEDO*=mix(1.,.69+tone*.65,near_detail);
 roughness=mix(rock.a,dirt.a,deposit);bump=mix(br,bd,deposit);
 if(textured_surface && near_detail>.001 && max(ice,snow)>.01){
  vec3 weights=pow(abs(n),vec3(5.));weights/=max(.001,weights.x+weights.y+weights.z);
  vec3 bi;vec3 bs;vec4 ti=layer(ice_layer,ice_meters,world_position,n,weights,bi);vec4 ts=layer(snow_layer,snow_meters,world_position,n,weights,bs);
  ice=clamp(ice+(ti.b-tone)*ice*(1.-ice)*near_detail,0.,1.);
  ALBEDO=mix(ALBEDO,vec3(.33,.57,.66)*(.68+ti.b*.64),ice*.9);
  ALBEDO=mix(ALBEDO,vec3(.52,.62,.66)*(.70+ts.b*.55),snow);
  bump=mix(mix(bump,bi,ice),bs,snow);roughness=mix(mix(roughness,ti.a,ice),ts.a,snow);
 }else{
  ALBEDO=mix(ALBEDO,vec3(.34,.58,.66),ice*.9);ALBEDO=mix(ALBEDO,vec3(.52,.62,.66),snow);
  roughness=mix(mix(roughness,.27,ice),.82,snow);
 }
 ALBEDO=mix(ALBEDO,vec3(.39,.30,.20),pollution_value*managed*skin*.35);
 ALBEDO*=1.-wet*.18;roughness=mix(roughness,.42,wet);
 float salt=local_salt_value*managed*skin*smoothstep(.25,.7,geo.z);
 ALBEDO=mix(ALBEDO,vec3(.72,.70,.58),salt*.6);
 ALBEDO=mix(ALBEDO,vec3(.23,.18,.12),local_soil_value*managed*skin*.30);
 ALBEDO=mix(ALBEDO,vec3(.22,.35,.22),(local_life_value<0.?local_restore_value:local_life_value)*managed*skin*(1.-freeze)*(.2+.8*moisture)*.72);
 vec3 perturbed=normalize(n+(bump-n*dot(n,bump))*normal_strength*near_detail);
 NORMAL=normalize((VIEW_MATRIX*vec4(perturbed,0.)).xyz);ROUGHNESS=roughness;
 if(molten){float heat=mix(1.,region_count>0?clamp((local_temp_value-80.)/max(1.,native_temperature-80.),0.,1.):local_heat,managed);float fissure=1.-smoothstep(.025,.1,abs(sin(world_position.x*.17+sin(world_position.z*.13)*2.)));
 float pulse=.85+.15*sin(TIME*1.3+world_position.z*.2);ALBEDO=mix(ALBEDO,vec3(.65,.07,.005),fissure*heat);EMISSION=vec3(1.,.12,.005)*fissure*heat*pulse*1.6;}
}
