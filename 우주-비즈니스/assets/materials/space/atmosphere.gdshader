shader_type spatial;
render_mode unshaded,cull_front,blend_add,depth_draw_never,shadows_disabled;
uniform vec4 tint:source_color=vec4(.18,.48,.60,1);
uniform float density=.8;
uniform vec3 body_center=vec3(0.0);
#include "res://assets/materials/space/illumination.gdshaderinc"
#include "res://assets/materials/space/terraform_field.gdshaderinc"
varying vec3 terraform_direction;
void vertex(){terraform_direction=normalize(VERTEX);space_world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 radial=normalize(space_world_position-body_center);vec3 sun=normalize(space_sun-space_world_position);
 float daylight=dot(radial,sun);
 vec4 recovery=terraform_field(terraform_direction);float local_density=mix(density,1.0,recovery.w);
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),mix(5.0,2.8,clamp(local_density,0.0,1.0)));
 float lit=smoothstep(-.22,.25,daylight);float sunset=exp(-abs(daylight+.025)*16.0);
 vec3 color=mix(mix(tint.rgb,terraform_air.rgb,recovery.w),vec3(.78,.27,.065),sunset*.62);
 ALBEDO=color*(.06+lit*.94)*space_visibility(space_world_position);ALPHA=clamp(rim*local_density*.52,0.0,.75);
}
