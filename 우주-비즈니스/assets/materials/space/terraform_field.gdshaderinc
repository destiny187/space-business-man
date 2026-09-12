// Shared by the surface, cloud shell and atmosphere. Directions remain planet-local.
uniform int terraform_count=0;
uniform vec4 terraform_points[16];
uniform vec4 terraform_values[16]; // vegetation, liquid suitability, temperature, clean air
uniform vec4 terraform_land:source_color=vec4(.31,.53,.31,1.);
uniform vec4 terraform_highland:source_color=vec4(.53,.56,.42,1.);
uniform vec4 terraform_sea:source_color=vec4(.07,.43,.61,1.);
uniform vec4 terraform_air:source_color=vec4(.39,.72,.93,1.);
uniform float terraform_sea_level=.48;
uniform float terraform_cloud_coverage=.65;
uniform bool terraform_airmap_enabled=false;
uniform sampler2D terraform_airmap:filter_linear,repeat_enable;
float terraform_weight(vec3 point,vec4 region){
 float distance=acos(clamp(dot(normalize(point),normalize(region.xyz)),-1.,1.));
 // A broad terrain-aligned edge keeps the restored region from looking like a painted disc.
 float edge=1.+.14*sin(point.x*47.+point.z*29.)*sin(point.y*39.-point.x*23.);
 return 1.-smoothstep(region.w*.5,region.w,distance*edge);
}
vec4 terraform_field(vec3 point){
 vec4 result=vec4(0.);float strongest=0.;
 for(int i=0;i<terraform_count;i++){
  float weight=terraform_weight(point,terraform_points[i]);
  result.x=max(result.x,terraform_values[i].x*weight);
  result.y=max(result.y,terraform_values[i].y*weight);
  result.w=max(result.w,terraform_values[i].w*weight);
  if(weight>strongest){strongest=weight;result.z=terraform_values[i].z;}
 }
 if(terraform_airmap_enabled){
  vec3 p=normalize(point);float inset=.5/float(textureSize(terraform_airmap,0).y);
  vec2 uv=vec2((atan(p.x,p.z)+3.14159265)/6.2831853,clamp((p.y+1.)*.5,inset,1.-inset));
  vec2 air=texture(terraform_airmap,uv).rg;result.w=max(result.w,air.x*air.y);
 }
 return result;
}
float terraform_footprint(vec3 point){
 float result=0.;
 for(int i=0;i<terraform_count;i++){
  result=max(result,terraform_weight(point,terraform_points[i]));
 }
 return result;
}
