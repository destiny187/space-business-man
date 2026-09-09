shader_type spatial;
render_mode cull_disabled,blend_mix,depth_draw_never;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
#include "res://assets/materials/space/water_surface.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1.);
uniform float flow_time=0.;
instance uniform float water_amount=1.;
varying vec3 water_point;
void vertex(){VERTEX.y-=.10*(1.-water_amount);water_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float bank=sin(UV.y*.83)*.045+sin(UV.y*2.1)*.018;
 float edge=smoothstep(0.,.18+bank,UV.x)*(1.-smoothstep(.82+bank,1.,UV.x));
 float distance_to_eye=length(VERTEX);
 vec3 wave=water_wave(water_point.xz,flow_time*1.25,1.-smoothstep(18.,70.,distance_to_eye));
 NORMAL=normalize((VIEW_MATRIX*vec4(-wave.y*.23,1.,-wave.z*.23,0.)).xyz);
 float fresnel=pow(1.-max(dot(NORMAL,VIEW),0.),4.);
 ALBEDO=water_tint(water_color.rgb*.8,wave,water_point.xz,flow_time*1.25,distance_to_eye,fresnel);
 if(water_quality>0) {
  float streak=sin(UV.y*1.25-flow_time*1.8+.7*sin(UV.x*4.));
  float breakup=smoothstep(.2,.7,sin(UV.y*.27+UV.x*7.));
  float foam=smoothstep(.91,.99,streak)*breakup*(water_quality==2 ? .18 : .07);
  ALBEDO=mix(ALBEDO,vec3(.34,.51,.52),foam);
 }
 ROUGHNESS=water_quality==0 ? .65 : .38;
 ALPHA=mix(.84,edge*.9,COLOR.r)*water_amount;
}
