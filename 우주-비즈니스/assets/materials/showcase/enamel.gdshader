shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float metal = 0.0;
uniform float rough = 0.4;
uniform vec4 light_color : source_color = vec4(0.0);
uniform float light_energy = 0.0;
varying vec3 local_pos;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex(){ local_pos=VERTEX; }
void fragment(){
 float grain=hash(floor(local_pos*420.0));
 ALBEDO=base_color.rgb*(0.975+grain*.045);
 METALLIC=metal;
 ROUGHNESS=clamp(rough+(grain-.5)*.055,.09,.98);
 SPECULAR=.5;
 EMISSION=light_color.rgb*light_energy;
}
