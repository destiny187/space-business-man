shader_type spatial;
render_mode cull_disabled;
#define INK_SPACE_LIGHTING
#include "res://assets/materials/space/illumination.gdshaderinc"
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 base_color:source_color=vec4(.6,.5,.35,1.0);
varying vec3 ring_point;
void vertex(){ring_point=VERTEX;space_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float r=(length(ring_point.xz)-1.3)/.95;ALBEDO=base_color.rgb*mix(.48,1.2,ring_density(r));ROUGHNESS=.94;}
