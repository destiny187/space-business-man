shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.);
uniform bool use_vertex_color = false;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 emission_color : source_color = vec4(0.);
uniform float emission_strength = 0.;
void fragment(){
 ALBEDO=base_color.rgb*(use_vertex_color ? COLOR.rgb : vec3(1.));
 ROUGHNESS=rough;
 METALLIC=0.;
 SPECULAR=0.;
 EMISSION=emission_color.rgb*min(emission_strength,.4);
}
