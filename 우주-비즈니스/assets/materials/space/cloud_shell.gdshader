shader_type spatial;
render_mode cull_back,depth_draw_never;
#define INK_SPACE_LIGHTING
#include "res://assets/materials/space/illumination.gdshaderinc"
#include "res://assets/materials/ink/cel_light.gdshaderinc"
#include "res://assets/materials/space/cloud_field.gdshaderinc"
uniform vec4 cloud_tint:source_color=vec4(.81,.85,.86,1.0);
uniform float planet_radius=1.0;
varying vec3 cloud_point;
void vertex(){cloud_point=normalize(VERTEX);space_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float coverage=cloud_field(cloud_point);ALBEDO=cloud_tint.rgb*mix(.72,1.0,smoothstep(.2,.8,coverage));ROUGHNESS=1.0;
 ALPHA=coverage*.9*(1.0-smoothstep(planet_radius*22.0,planet_radius*30.0,length(VERTEX)));
 float period=floor(cloud_time/23.0);
 vec3 storm=normalize(vec3(sin(cloud_seed+period*3.7),.35*sin(period+cloud_seed),cos(cloud_seed+period*3.7)));
 float patch=exp(-length(cloud_point-storm)*55.0);
 float burst=pow(max(0.0,sin(mod(cloud_time,23.0)*9.0)),18.0)*(1.0-smoothstep(.4,1.0,mod(cloud_time,23.0)));
 EMISSION=vec3(.35,.55,1.0)*patch*burst*storm_strength*4.0;
}
