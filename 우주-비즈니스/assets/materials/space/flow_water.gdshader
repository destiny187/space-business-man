shader_type spatial;
render_mode cull_disabled,blend_mix,depth_draw_never;
#include "res://assets/materials/ink/cel_light.gdshaderinc"
uniform vec4 water_color:source_color=vec4(.04,.18,.25,1.);
uniform float flow_time=0.;
instance uniform float water_amount=1.;
varying vec3 water_point;
void vertex(){VERTEX.y-=.10*(1.-water_amount);water_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float bank=sin(UV.y*.83)*.045+sin(UV.y*2.1)*.018;
 float edge=smoothstep(0.,.18+bank,UV.x)*(1.-smoothstep(.82+bank,1.,UV.x));
 float ripple=sin(UV.y*1.7-flow_time*2.+sin(UV.x*7.)*.3);
 float breakup=smoothstep(.25,.8,sin(UV.y*.37+UV.x*19.)*sin(UV.y*.79-UV.x*11.));
 float foam=smoothstep(.88,1.,ripple)*breakup*.13;
 ALBEDO=mix(water_color.rgb*.66,vec3(.37,.53,.53),foam);
 ROUGHNESS=.38;
 NORMAL=normalize(NORMAL+vec3(cos(water_point.x*.7-flow_time)*.025,0.,sin(water_point.z*.9-flow_time)*.025));
 ALPHA=mix(.84,edge*.9,COLOR.r)*water_amount;
}
