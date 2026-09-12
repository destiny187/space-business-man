// Shared by generated and Solar System bodies, including navigation previews.
global uniform int orbital_surface_quality;
uniform bool orbital_maps_enabled=false;
uniform sampler2D orbital_relief : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orbital_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orbital_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float orbital_medium_scale=36.;
uniform float orbital_fine_scale=170.;
uniform float orbital_detail_strength=.38;
uniform float orbital_bump_strength=.00016;

vec3 orbital_map(sampler2D map,vec3 p){
 // Analytic UV derivatives avoid an artificial coarse mip at the longitude seam.
 vec3 dx=dFdx(p),dy=dFdy(p);
 float equator=max(dot(p.xz,p.xz),.00001);
 vec3 du=vec3(-p.z,0.,p.x)/(6.2831853*equator);
 vec3 dv=vec3(0.,-1./(3.14159265*sqrt(equator)),0.);
 vec2 gx=vec2(dot(du,dx),dot(dv,dx)),gy=vec2(dot(du,dy),dot(dv,dy));
 vec2 size=vec2(textureSize(map,0));
 float footprint=max(length(gx*size),length(gy*size));
 float half_texel=min(.5,.5*exp2(ceil(log2(max(1.,footprint))))/size.y);
 vec2 uv=vec2(atan(p.z,p.x)/6.2831853+.5,clamp(acos(clamp(p.y,-1.,1.))/3.14159265,half_texel,1.-half_texel));
 return textureGrad(map,uv,gx,gy).rgb;
}
float orbital_edge(float low,float high,float field){
 float pixel=fwidth(field)*.75;
 return smoothstep(low-pixel,high+pixel,field);
}
float orbital_grain(vec3 p,vec3 weights,float scale){
 vec3 q=p*scale;
 return dot(vec3(texture(orbital_detail,q.yz).b,texture(orbital_detail,q.zx).b,texture(orbital_detail,q.xy).b),weights)-.5;
}
vec2 orbital_detail_field(vec3 p,float solid,bool gaseous){
 float pixel=max(length(dFdx(p)),length(dFdy(p)));
 float medium=1.-smoothstep(.003,.012,pixel);
 float fine=1.-smoothstep(.0008,.0035,pixel);
 float tone=0.;float height=0.;
 // Uniform quality branches skip texture reads; tiny/distant bodies skip both layers.
 if(orbital_maps_enabled && orbital_surface_quality>0 && medium>.001){
  vec3 weights=pow(abs(p),vec3(4.));weights/=max(dot(weights,vec3(1.)),.0001);
  vec3 q=gaseous?p*vec3(.3,2.7,.3):p;
  float meso=orbital_grain(q,weights,orbital_medium_scale)*medium;
  tone=meso*orbital_detail_strength*(gaseous?.38:mix(.12,1.,solid));
  if(orbital_surface_quality>1 && fine>.001){
   float micro=orbital_grain(q+vec3(.173,.419,.731),weights,orbital_fine_scale)*fine;
   tone+=micro*orbital_detail_strength*.65*(gaseous?.3:mix(.05,1.,solid));
   if(!gaseous)height=(meso*.65+micro*.24)*solid*orbital_bump_strength;
  }
 }
 return vec2(tone,height);
}
vec3 orbital_detail_normal(vec3 n,vec3 view_position,float height){
 vec3 dx=dFdx(view_position),dy=dFdy(view_position);
 vec3 rx=cross(dy,n),ry=cross(n,dx);
 float determinant=dot(dx,rx);
 vec3 gradient=(dFdx(height)*rx+dFdy(height)*ry)*sign(determinant)/max(abs(determinant),.0000001);
 return normalize(n-clamp(gradient,vec3(-.22),vec3(.22)));
}
