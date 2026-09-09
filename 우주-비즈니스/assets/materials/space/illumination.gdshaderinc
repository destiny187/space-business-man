// Opt-in: other scenes retain their existing INK lighting.
uniform bool space_lighting = false;
uniform vec3 space_sun = vec3(0.0);
uniform float space_sun_radius = 1500.0;
uniform vec4 space_occluders[8];
uniform int space_occluder_count = 0;
uniform vec3 space_ring_center = vec3(0.0);
uniform vec3 space_ring_normal = vec3(0.0,1.0,0.0);
uniform vec2 space_ring_radii = vec2(0.0);
varying vec3 space_world_position;
float ring_density(float r){
 float bands=.5+.5*sin(r*155.0)+.12*sin(r*440.0);
 float gaps=max(1.0-smoothstep(.008,.022,abs(r-.23)),1.0-smoothstep(.012,.035,abs(r-.65)));
 return clamp(.55+bands*.22,0.0,.9)*(1.0-gaps*.95);
}
float space_visibility(vec3 point){
 if(!space_lighting){return 1.0;}
 vec3 ray=space_sun-point;float distance_to_sun=max(length(ray),1.0);ray/=distance_to_sun;
 float visibility=1.0;
 for(int i=0;i<8;i++){
  if(i>=space_occluder_count){break;}
  vec3 offset=space_occluders[i].xyz-point;float along=dot(offset,ray);
  if(along>.1 && along<distance_to_sun){
   float miss=length(offset-ray*along)-space_occluders[i].w;
   float penumbra=max(1.0,space_sun_radius*along/distance_to_sun);
   visibility*=smoothstep(-penumbra,penumbra,miss);
  }
 }
 float denom=dot(ray,space_ring_normal);
 if(space_ring_radii.y>0.0 && abs(denom)>.0001){
  float t=dot(space_ring_center-point,space_ring_normal)/denom;
  if(t>1.0 && t<distance_to_sun){
   float r=(length(point+ray*t-space_ring_center)-space_ring_radii.x)/max(1.0,space_ring_radii.y-space_ring_radii.x);
   float edge=smoothstep(0.0,.018,r)*(1.0-smoothstep(.982,1.0,r));
   visibility*=1.0-edge*ring_density(r)*.83;
  }
 }
 return visibility;
}
