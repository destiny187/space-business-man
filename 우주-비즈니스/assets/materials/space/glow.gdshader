shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec4 tint:source_color=vec4(1.,.55,.12,1.);
uniform float strength=1.;
uniform int mode=0;
uniform float seed_offset=0.;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){
 vec2 p=UV*2.-1.;float r=length(p);float a=atan(p.y,p.x);
 // Disc radius is .4. Smooth irregular streamers, without repeated spokes or wire loops.
 float h=max(0.,r-.4);
 float drift=TIME*.006;
 float structure=.5+.22*sin(a*3.+seed_offset+drift)
  +.17*sin(a*7.-seed_offset*1.7+h*5.)+.09*sin(a*11.+seed_offset*.6-h*9.);
 float width=mix(.055,.12,clamp(structure,0.,1.));
 float corona=exp(-h/width)*(.16+.12*structure);
 float aureole=exp(-h*7.)*.035;
 float limb_glow=exp(-h*65.)*.24;
 float outside=smoothstep(.393,.407,r);
 // Use a filled diffuse plume for active stars, not an outlined animated arch.
 float active=(mode==1||mode==3)?pow(max(0.,sin(a*2.+seed_offset)),12.)*.05*exp(-h*12.):0.;
 ALBEDO=mix(tint.rgb,vec3(1.),.45)*strength;
 ALPHA=(corona+aureole+limb_glow+active)*outside*(1.-smoothstep(.8,1.,r));
}
