shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint:source_color=vec4(.44,.86,.79,1.);
uniform float level=0.;
uniform float opacity=1.;
varying vec3 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 if(world_point.y<level)discard;
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),2.);
 float stripe=1.-smoothstep(.02,.055,abs(fract(world_point.y*5.)-.5));
 ALBEDO=tint.rgb;EMISSION=tint.rgb*.22;
 ALPHA=(.035+rim*.24+stripe*.16)*opacity;
}
