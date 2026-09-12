shader_type spatial;
#include "res://assets/materials/space/surface_detail.gdshaderinc"
uniform bool orbital_gaseous=false;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.);
uniform bool use_vertex_color = false;
#define INK_SPACE_LIGHTING
#define INK_ORBITAL_SURFACE
#include "res://assets/materials/space/illumination.gdshaderinc"
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 emission_color : source_color = vec4(0.);
uniform float emission_strength = 0.;
#include "res://assets/materials/space/cloud_field.gdshaderinc"
uniform bool separate_clouds=false;
uniform float cloud_shadow_strength=.36;
uniform float city_strength=0.0;
uniform vec3 local_sun_direction=vec3(0,1,0);
uniform bool presence_foliage=false;
uniform float presence_time=0.;
uniform vec2 presence_wind=vec2(0.);
uniform bool presence_grounded=false;
uniform vec4 contact_color:source_color=vec4(.4,.32,.24,1.);
uniform float contact_frost=0.;
uniform float contact_wet=0.;
varying float presence_height;
varying vec3 orbital_point;
void vertex(){
 presence_height=VERTEX.y;
 if(presence_foliage){vec3 at=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;VERTEX.xz+=presence_wind*sin(presence_time*1.8+at.x*.16+at.z*.12)*pow(clamp(VERTEX.y,0.,2.5),1.3)*.055;}
 orbital_point=normalize(VERTEX);space_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 p=normalize(orbital_point);
 vec3 paint=orbital_maps_enabled?orbital_map(orbital_color,p):COLOR.rgb;
 ALBEDO=base_color.rgb*(use_vertex_color?paint:vec3(1.));
 float solid=1.-smoothstep(.0,.10,paint.b-max(paint.r,paint.g));
 vec2 detail=orbital_detail_field(p,solid,orbital_gaseous);
 ALBEDO*=1.+detail.x;
 if(orbital_surface_quality>1 && !orbital_gaseous)NORMAL=orbital_detail_normal(NORMAL,VERTEX,detail.y*length(MODEL_MATRIX[0].xyz));
 if(space_lighting && separate_clouds){
  vec3 shadow_point=normalize(orbital_point+normalize(local_sun_direction)*.018);
  ALBEDO*=1.0-cloud_field(shadow_point)*cloud_shadow_strength;
 }
 if(presence_grounded){float foot=1.-smoothstep(.02,.32,presence_height);ALBEDO=mix(ALBEDO,mix(contact_color.rgb*(.68-contact_wet*.18),vec3(.60,.72,.75),contact_frost),foot*.48);}
 ROUGHNESS=rough;
 METALLIC=0.;
 SPECULAR=0.;
 EMISSION=emission_color.rgb*min(emission_strength,.4);
 if(space_lighting && city_strength>0.0){
  float night=1.0-smoothstep(-.12,.08,dot(orbital_point,normalize(local_sun_direction)));
  float land=orbital_edge(-.01,.01,paint.g-paint.b*.9)*orbital_edge(-.01,.01,paint.g-paint.r*.75);
  float cluster=smoothstep(.53,.66,cloud_noise(orbital_point*18.0));
  float points=pow(max(0.0,sin(orbital_point.x*840.0)*sin(orbital_point.z*740.0)),14.0);
  float pixel=max(length(dFdx(p)),length(dFdy(p)));
  float city_fade=1.-smoothstep(.0005,.0025,pixel);
  EMISSION+=vec3(1.0,.55,.16)*night*land*cluster*points*city_strength*city_fade;
 }
}
