float star_hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
// Include adjacent cells so a star's round halo is never cut at a grid face.
float stars(vec3 d, float density, float threshold) {
 vec3 q=d*density;
 vec3 cell=floor(q);
 float pixel_width=max(length(fwidth(q))*.5,.035);
 float radius=.075;
 float width=sqrt(radius*radius+pixel_width*pixel_width);
 float light=0.0;
 for(int z=-1;z<=1;z++) {
  for(int y=-1;y<=1;y++) {
   for(int x=-1;x<=1;x++) {
    vec3 neighbor=cell+vec3(float(x),float(y),float(z));
    float seed=star_hash(neighbor);
    if(seed>threshold) {
     vec3 center=neighbor+vec3(star_hash(neighbor+3.),star_hash(neighbor+7.),star_hash(neighbor+11.));
     float distance_to_star=length(q-center);
     // Compact support reaches zero before the neighborhood can change.
     float profile=exp(-distance_to_star*distance_to_star/(width*width));
     profile*=1.0-smoothstep(.65,.95,distance_to_star);
     light+=profile*(radius*radius/(width*width))*mix(.7,1.4,star_hash(neighbor+19.));
    }
   }
  }
 }
 return light;
}
