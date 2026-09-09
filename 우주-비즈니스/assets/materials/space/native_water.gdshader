shader_type spatial;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
#include "res://assets/materials/space/water_surface.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1);
uniform float flow_time=0.;
uniform sampler2D terrain_mask:filter_linear,repeat_disable;
uniform vec2 mask_origin=vec2(0.);
uniform bool mask_ready=false;
uniform bool viewer_under_land=false;
varying vec3 world_pos;
void vertex(){
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 if(water_quality>0) {
  float fade=1.-smoothstep(65.,180.,length(world_pos.xz-CAMERA_POSITION_WORLD.xz));
  vec2 uv=(world_pos.xz-mask_origin)/512.;
  float depth=mask_ready ? max(0.,-textureLod(terrain_mask,uv,0.).r) : 0.;
  float bank=smoothstep(.2,2.,depth);
  VERTEX.y+=water_wave(world_pos.xz,flow_time,0.).x*(water_quality==2 ? .10 : .045)*fade*bank;
 }
}
void fragment(){
 vec2 mask_uv=(world_pos.xz-mask_origin)/512.;
 bool inside=all(greaterThanEqual(mask_uv,vec2(0.))) && all(lessThan(mask_uv,vec2(1.)));
 float ground_delta=mask_ready && inside ? texture(terrain_mask,mask_uv).r : -10.;
 if(mask_ready && inside && ground_delta>0.) discard;
 if(viewer_under_land && (!mask_ready || !inside)) discard;
 float distance_to_eye=length(VERTEX);
 vec3 wave=water_wave(world_pos.xz,flow_time,1.-smoothstep(25.,110.,distance_to_eye));
 NORMAL=normalize((VIEW_MATRIX*vec4(-wave.y*.40,1.,-wave.z*.40,0.)).xyz);
 float fresnel=pow(1.-max(dot(NORMAL,VIEW),0.),4.);
 ALBEDO=water_tint(water_color.rgb,wave,world_pos.xz,flow_time,distance_to_eye,fresnel);
 if(water_quality==2 && inside && mask_ready) {
  float shore=(1.-smoothstep(.05,.6,-ground_delta))*smoothstep(-.15,.45,wave.x);
  ALBEDO=mix(ALBEDO,vec3(.37,.55,.57),shore*.25);
 }
 ROUGHNESS=water_quality==0 ? .65 : .30;
}
