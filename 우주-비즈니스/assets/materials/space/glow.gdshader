shader_type spatial;
render_mode unshaded,blend_add,cull_disabled,depth_draw_never;
uniform vec4 tint:source_color=vec4(1.,.55,.12,1.);
uniform float strength=1.;
uniform int mode=0;
uniform float seed_offset=0.;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){
 vec2 p=UV*2.-1.;float r=length(p);float a=atan(p.y,p.x);
 // Stellar limb is r=.4. Keep additive light off the surface so markings remain readable.
 float outside=smoothstep(.385,.415,r);
 float width=mode==2?12.:7.;
 float halo=exp(-max(0.,r-.4)*width)*.32;
 float rays=pow(max(0.,sin(a*(mode==2?13.:8.)+seed_offset)),mode==2?14.:5.);
 halo*=.65+rays*.55;
 float loops=0.;
 for(int i=0;i<3;i++){
  float variation=.5+.5*sin(seed_offset+float(i)*4.73);
  float center=seed_offset+float(i)*2.1+sin(float(i)*3.4+seed_offset)*.45+TIME*(mode==1?.008:.016);
  float angle=atan(sin(a-center),cos(a-center));
  float span=(mode==3?.38:.27)*(.65+variation*.55);
  float arch=.41+(mode==3?.26:.16)*(.65+variation*.6)*sqrt(max(0.,1.-pow(angle/span,2.)));
  float arc=exp(-pow((r-arch)/.013,2.))*(1.-smoothstep(span*.85,span,abs(angle)));
  loops+=arc;
 }
 float flare=mode==3?pow(max(0.,sin(TIME*.4+seed_offset)),14.):0.;
 float plumes=mode==1||mode==3?loops*(.45+flare*.3):0.;
 ALBEDO=tint.rgb*strength;
 ALPHA=(halo+plumes)*outside*(1.-smoothstep(.85,1.,r));
}
