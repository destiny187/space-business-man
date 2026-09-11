shader_type spatial;
#define INK_SURFACE_ROUGHNESS
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 rock_color:source_color=vec4(.43,.32,.25,1);
uniform vec4 dust_color:source_color=vec4(.67,.53,.39,1);
uniform float salt_crust=0.;
uniform float soil_recovery=0.;
uniform float restoration=0.;
uniform bool free_enabled=false;
uniform sampler2D free_values : filter_linear, repeat_disable;
uniform sampler2D free_extras : filter_linear, repeat_disable;
uniform sampler2D free_mask : filter_linear, repeat_disable;
uniform vec2 free_origin=vec2(-8208.);
uniform vec2 free_size=vec2(16416.);
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
uniform bool regional_enabled=false;
uniform ivec3 regional_layers=ivec3(0);
uniform vec3 regional_meters=vec3(5.);
uniform vec4 regional_edges=vec4(-8.,0.,18.,26.);
uniform float regional_frequency=.008;
uniform float regional_relief=14.;
uniform float regional_phase=0.;
uniform vec3 regional_deposit=vec3(1.,.55,.15);
uniform vec3 regional_low_tint=vec3(.87,.95,1.04);
uniform vec3 regional_high_tint=vec3(1.16,1.08,.94);
uniform vec3 regional_lava=vec3(0.);
uniform bool recovery_surface_enabled=false;
uniform sampler2DArray recovery_textures:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec2 recovery_meters=vec2(2.8,2.6);
uniform vec4 original_surface_state=vec4(1.,0.,0.,0.);
uniform vec4 recovery_soil_color:source_color=vec4(.46,.38,.29,1.);
uniform vec4 recovery_life_color:source_color=vec4(.41,.51,.30,1.);
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 geological_regions;
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

// A restored deposit replaces the native deposit fetch; it never adds a layer blend.
vec4 packed_surface(bool recovering,vec3 at){
 if(recovering){return texture(recovery_textures,at);}
 return texture(surface_textures,at);
}
// One packed fetch per contributing axis; linear data, no lighting baked into tone.
vec4 layer(bool recovering,int id,float meters,vec3 p,vec3 n,vec3 weights,out vec3 bump){
 vec3 q=p/meters;vec3 s=sign(n);vec4 value=vec4(0.);bump=vec3(0.);
 if(weights.x>.001){vec4 t=packed_surface(recovering,vec3(q.zy*vec2(s.x,1.),float(id)));value+=t*weights.x;bump+=vec3(0.,t.g*2.-1.,(t.r*2.-1.)*s.x)*weights.x;}
 if(weights.y>.001){vec4 t=packed_surface(recovering,vec3(q.xz*vec2(1.,-s.y),float(id)));value+=t*weights.y;bump+=vec3(t.r*2.-1.,0.,-(t.g*2.-1.)*s.y)*weights.y;}
 if(weights.z>.001){vec4 t=packed_surface(recovering,vec3(q.xy*vec2(-s.z,1.),float(id)));value+=t*weights.z;bump+=vec3(-(t.r*2.-1.)*s.z,t.g*2.-1.,0.)*weights.z;}
 return value;
}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
 geological_regions=vec3(0.,1.,0.);
 if(regional_enabled){
  // Broad geological bands are evaluated per vertex, never as per-pixel noise.
  // Same metre-space definition as surface_regions.gd for cosmetic scatter.
  vec2 q=world_position.xz*regional_frequency;
  float band=.55*sin(q.x+sin(q.y*.73+regional_phase)*1.6+regional_phase)+.45*sin(q.y*.83+regional_phase*1.3);
  float level=world_position.y+band*regional_relief;
  float low=1.-smoothstep(regional_edges.x,regional_edges.y,level);
  float high=smoothstep(regional_edges.z,regional_edges.w,level);
  geological_regions=vec3(low,1.-low-high,high);
 }
}
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
 if(free_enabled){
  vec2 uv=(world_position.xz-free_origin)/free_size;
  managed=0.;
  // Unmanaged pixels use native conditions: avoid three irrelevant texture reads.
  if(all(greaterThanEqual(uv,vec2(0.)))&&all(lessThan(uv,vec2(1.)))){
   managed=texture(free_mask,uv).r;
   if(managed>.001){
    // Normalize filtered occupied cells so empty atlas pixels cannot invent cold/wet edges.
    vec4 fv=texture(free_values,uv)/managed;vec4 fe=texture(free_extras,uv)/managed;
    local_temp_value=fv.x;local_life_value=fv.y;local_water_value=fv.z;local_pressure_value=fv.w;local_salt_value=fe.x;local_soil_value=fe.y;local_restore_value=fe.z;pollution_value=fe.w;
   }
  }
 }
 local_life_value*=1.-pollution_value;local_restore_value*=1.-pollution_value;
 float surface_distance=distance(CAMERA_POSITION_WORLD,world_position);
 float near_detail=1.-smoothstep(detail_near,detail_far,surface_distance);
 float lava_coverage=regional_enabled?dot(geological_regions,regional_lava):1.;
 float lava_detail=(molten&&lava_coverage>.001)?1.-smoothstep(70.,140.,surface_distance):0.;
 float terrace=sin(world_position.y*.65+sin(world_position.x*.043)*.6)*.5+.5;
 vec3 strata=mix(rock_color.rgb*.82,rock_color.rgb*1.09,smoothstep(.2,.8,terrace));
 float deposit=skin*smoothstep(.18,.88,geo.z+geo.y*.75);
 if(regional_enabled){
  strata*=regional_low_tint*geological_regions.x+vec3(geological_regions.y)+regional_high_tint*geological_regions.z;
  deposit*=dot(geological_regions,regional_deposit);
 }
 // Basalt plates remain legible under the thin volcanic ash deposits.
 if(molten){deposit*=.35;}
 float temp=mix(native_temperature,local_temp_value,managed)+(geo.x-.5)*14.-max(0.,world_position.y-2.)*.012;
 float freeze=1.-smoothstep(freeze_start,freeze_end,temp);
 float supply=mix(volatile_supply,max(0.,local_water_value),managed*step(0.,local_water_value));
 float moisture=supply*(.60+.40*(1.-geo.x));
 float ice=freeze*moisture*(.28+.72*geo.y)*skin;
 float snow=freeze*moisture*smoothstep(.12,.76,geo.z+geo.y*.15)*skin;
 float wet=(1.-freeze)*moisture*(.15+.85*geo.y)*skin*max(float(liquid_allowed),managed*smoothstep(.05,.2,local_pressure_value));
 float soil_patch=0.;float pioneer_patch=0.;
 if(recovery_surface_enabled && managed>.001){
  float soil_gain=clamp((local_soil_value-original_surface_state.x)/max(.2,1.-original_surface_state.x),0.,1.);
  float water_gain=clamp((local_water_value-original_surface_state.y)/max(.2,1.-original_surface_state.y),0.,1.);
  float salt_gain=max(0.,original_surface_state.z-local_salt_value);
  float life=max(0.,local_life_value<0.?local_restore_value:local_life_value);
  float life_gain=clamp((life-original_surface_state.w)/max(.2,1.-original_surface_state.w),0.,1.)*(1.-freeze)*smoothstep(.08,.35,supply);
  float progress=max(max(soil_gain,water_gain*.8),max(salt_gain*.7,life_gain));
  soil_patch=smoothstep(.10,.65,progress-geo.x*.22+geo.y*.08)*managed;
  pioneer_patch=smoothstep(.12,.72,life_gain-geo.x*.18+geo.z*.08)*managed;
  deposit=max(deposit,soil_patch*skin*(.72+.20*geo.z));
 }
 vec3 bump=vec3(0.);float roughness=.94;
 vec4 rock=vec4(.5,.5,.5,.94);vec4 dirt=rock;
 vec3 br=vec3(0.);vec3 bd=vec3(0.);
 if(textured_surface && max(near_detail,lava_detail)>.001){
  vec3 weights=pow(abs(n),vec3(5.));weights/=max(.001,weights.x+weights.y+weights.z);
  int selected_rock=rock_layer;float selected_meters=rock_meters;
  if(regional_enabled){
   // A geological contact chooses one microtexture, even at region boundaries.
   // Existing outcrop masks break up its edge; broad tint/deposit still blend.
   float contact=.35+.30*geo.x;
   int zone=geological_regions.x>contact?0:(geological_regions.z>contact?2:1);
   selected_rock=regional_layers[zone];selected_meters=regional_meters[zone];
  }
  rock=layer(false,selected_rock,selected_meters,world_position,n,weights,br);
  if(near_detail>.001){
   bool recovering=recovery_surface_enabled && soil_patch>(.32+.30*geo.z);
   int deposit_id=deposit_layer;float meters=deposit_meters;
   if(recovering){deposit_id=pioneer_patch>(.38+.22*geo.x)?1:0;meters=recovery_meters[deposit_id];}
   // Reuse broad geology to bend repeated soil motifs without another noise/map read.
   vec3 deposit_position=world_position;
   if(recovering){deposit_position+=vec3(geo.z-geo.x,0.,geo.y-.5)*meters*1.8;}
   dirt=layer(recovering,deposit_id,meters,deposit_position,n,weights,bd);
  }
  // Raised bedrock breaks through soil; only the local boundary receives height contrast.
  float height_bias=(dirt.b-rock.b)*.65*near_detail;
  deposit=clamp(deposit+height_bias*4.*deposit*(1.-deposit),0.,1.);
 }
 vec3 deposit_color=mix(dust_color.rgb,recovery_soil_color.rgb,soil_patch);
 deposit_color=mix(deposit_color,recovery_life_color.rgb,pioneer_patch);
 ALBEDO=mix(strata,deposit_color,deposit);
 float tone=mix(rock.b,dirt.b,deposit);
 ALBEDO*=mix(1.,.69+tone*.65,near_detail);
 roughness=mix(rock.a,dirt.a,deposit);bump=mix(br,bd,deposit);
 if(textured_surface && near_detail>.001 && max(ice,snow)>.01){
  vec3 weights=pow(abs(n),vec3(5.));weights/=max(.001,weights.x+weights.y+weights.z);
  vec3 bi;vec3 bs;vec4 ti=layer(false,ice_layer,ice_meters,world_position,n,weights,bi);vec4 ts=layer(false,snow_layer,snow_meters,world_position,n,weights,bs);
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
 if(!recovery_surface_enabled){
  ALBEDO=mix(ALBEDO,vec3(.23,.18,.12),local_soil_value*managed*skin*.30);
  ALBEDO=mix(ALBEDO,vec3(.22,.35,.22),(local_life_value<0.?local_restore_value:local_life_value)*managed*skin*(1.-freeze)*(.2+.8*moisture)*.72);
 }
 vec3 perturbed=normalize(n+(bump-n*dot(n,bump))*normal_strength*near_detail);
 NORMAL=normalize((VIEW_MATRIX*vec4(perturbed,0.)).xyz);ROUGHNESS=roughness;
 if(molten){
  float heat=mix(1.,(region_count>0||free_enabled)?clamp((local_temp_value-80.)/max(1.,native_temperature-80.),0.,1.):local_heat,managed);
  // The packed roughness shares the height field's fissures: no extra heat map.
  // Mip filtering and a distant fade prevent bright subpixel seams from crawling.
  float edge_width=min(.12,fwidth(rock.a));
  float fissure=(1.-smoothstep(.40-edge_width,.72+edge_width,rock.a))*lava_detail;
  fissure*=lava_coverage;
  float core=1.-smoothstep(.25-edge_width,.43+edge_width,rock.a);
  vec3 ember=mix(vec3(.30,.017,.004),vec3(1.,.13,.005),smoothstep(.2,.85,fissure));
  ember=mix(ember,vec3(1.,.42,.035),core*core*.55);
  float pulse=.94+.06*sin(TIME*.65+world_position.x*.37+world_position.z*.29+rock.b*5.);
  float activity=.22+.78*smoothstep(.12,.72,geo.x+geo.y*.3);
  ALBEDO*=mix(1.,.70+smoothstep(.30,.60,rock.b)*.55,near_detail);
  ALBEDO*=1.-fissure*.42;
  ALBEDO=mix(ALBEDO,ember*.26,fissure*heat*activity);
  EMISSION=ember*fissure*heat*pulse*activity*.85;
  ROUGHNESS=mix(max(.84,roughness),roughness,fissure*heat);
 }
}
