shader_type spatial;
#define INK_SPACE_LIGHTING
#include "res://assets/materials/space/illumination.gdshaderinc"
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 base_color:source_color=vec4(.6,.65,.7,1);
uniform float fade_near=1600.0;
uniform float fade_far=2400.0;
void vertex(){
 vec3 center=(MODEL_MATRIX*vec4(0,0,0,1)).xyz;
 float visible=1.0-smoothstep(fade_near,fade_far,distance(CAMERA_POSITION_WORLD,center));
 VERTEX*=visible;space_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){ALBEDO=base_color.rgb;ROUGHNESS=rough;}
