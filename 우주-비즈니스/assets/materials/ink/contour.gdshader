shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, repeat_disable, filter_nearest;
uniform bool transparent_background = false;
uniform float outer_width = 3.0;
uniform float inner_width = 0.8;
uniform float strength = 1.0;
uniform float crease_depth_floor = 0.007;
uniform float reference_height = 1200.;
uniform vec2 crease_fade = vec2(15.,55.);
uniform vec2 outline_fade = vec2(28.,110.);
uniform float distant_ink_strength = .24;
uniform float small_feature_strength = .45;
uniform vec4 ink : source_color = vec4(.012,.016,.02,1.);
float view_depth(vec2 uv,mat4 inv_projection){
 float d=texture(depth_tex,uv).r;
 vec4 v=inv_projection*vec4(uv*2.-1.,d,1.);
 return -v.z/v.w;
}
void vertex(){POSITION=vec4(VERTEX.xy,1.,1.);}
void fragment(){
 if(transparent_background && textureLod(depth_tex,SCREEN_UV,0.).r<=0.000001){discard;}
 vec2 pixel=(1./VIEWPORT_SIZE)*(VIEWPORT_SIZE.y/reference_height);
 float center=view_depth(SCREEN_UV,INV_PROJECTION_MATRIX);
 vec3 norm=texture(normal_tex,SCREEN_UV).xyz*2.-1.;
 float outline=0.;float crease=0.;float surface_support=0.;
 for(int i=0;i<8;i++){
  float angle=float(i)*.7853981634;
  vec2 dir=vec2(cos(angle),sin(angle));
  float d=view_depth(SCREEN_UV+pixel*dir*outer_width,INV_PROJECTION_MATRIX);
  float opposite=view_depth(SCREEN_UV-pixel*dir*outer_width,INV_PROJECTION_MATRIX);
  surface_support += 1.-smoothstep(.015,.04,abs(d-center)/max(center,.5));
  // Reciprocal depth is affine on a perspective-projected plane. Cancel its slope
  // so a continuous ground plane never becomes a black band near the horizon.
  float jump;
  if(PROJECTION_MATRIX[3][3]>.5){
   jump=abs(d+opposite-2.*center)/max(min(center,min(d,opposite)),.5);
  }else{
   jump=abs(1./d+1./opposite-2./center)*min(center,min(d,opposite));
  }
  outline=max(outline,smoothstep(.018,.032,jump));
  vec3 nn=texture(normal_tex,SCREEN_UV+pixel*dir*inner_width).xyz*2.-1.;
  float nd=view_depth(SCREEN_UV+pixel*dir*inner_width,INV_PROJECTION_MATRIX);
  float normal_edge=length(norm-nn);
  crease=max(crease,smoothstep(.45,.68,normal_edge)*step(abs(nd-center)/max(center,.5),.03)*step(crease_depth_floor,abs(nd-center)));
 }
 crease *= 1.-smoothstep(crease_fade.x,crease_fade.y,center);
 float distance_ink=mix(1.,distant_ink_strength,smoothstep(outline_fade.x,outline_fade.y,center));
 // Subpixel twigs, pebbles and narrow gaps retain ink without becoming solid black.
 float small_ink=mix(small_feature_strength,1.,smoothstep(.16,.55,surface_support/8.));
 float edge=max(outline,crease*.92)*strength*distance_ink*small_ink;
 ALBEDO=mix(textureLod(screen_tex,SCREEN_UV,0.).rgb,ink.rgb,edge);
}
