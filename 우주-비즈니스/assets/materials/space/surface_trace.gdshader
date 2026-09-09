shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
uniform float fade=1.0;
uniform float kind=0.0;
uniform vec4 trace_color:source_color=vec4(.12,.10,.08,1.);
void fragment(){
 vec2 p=(UV-.5)*2.;
 float sole=(1.-smoothstep(.64,.9,abs(p.x)))*(1.-smoothstep(.72,.98,abs(p.y)));
 float tread=mix(.4,1.,step(.45,fract(UV.y*7.)));
 float dust=(1.-smoothstep(.3,1.,length(p)))*(.6+.4*sin(p.x*17.)*sin(p.y*21.));
 float wash=(1.-smoothstep(.55,1.,length(p)))*(.55+.25*sin(atan(p.y,p.x)*17.));
 ALBEDO=trace_color.rgb;ALPHA=(kind>2.5?wash:((kind<.5 || kind>1.5)?sole*tread:dust))*fade*.42;
}
