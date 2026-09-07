shader_type sky;
uniform vec4 zenith : source_color = vec4(.1,.2,.3,1);
uniform vec4 horizon : source_color = vec4(.5,.6,.7,1);
uniform vec4 cloud_color : source_color = vec4(.8,.85,.9,1);
uniform float atmosphere = 1.0;
uniform float cloud_amount = 0.0;
uniform float seed_phase = 0.0;
#include "res://assets/materials/space/arrival_smoke.gdshaderinc"
float star_hash(vec3 p) {return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void sky() {
 vec3 d=normalize(EYEDIR);
 float altitude=max(d.y,0.0);
 vec3 color=mix(horizon.rgb,zenith.rgb,pow(altitude,.42));
 if(d.y>0.01) {
  vec3 q=d*260.0;vec3 cell=floor(q);
  vec3 center=vec3(star_hash(cell+3.),star_hash(cell+7.),star_hash(cell+11.));
  float distance_to_star=length(fract(q)-center);
  float stars=step(.989,star_hash(cell))*exp(-distance_to_star*distance_to_star*180.0);
  color+=stars*(1.0-atmosphere)*smoothstep(0.,.12,altitude)*vec3(.8,.88,1.);
  vec2 p=d.xz/(altitude+.23)*1.8+vec2(seed_phase,seed_phase*.37);
  float n=smoke_density(p,0.0);
  float cloud=smoothstep(.60-cloud_amount*.24,.83-cloud_amount*.15,n);
  cloud*=cloud_amount*smoothstep(.02,.20,altitude);
  float shade=smoothstep(.32,.65,n);
  color=mix(color,cloud_color.rgb*mix(.72,1.,shade),cloud*.86);
 }
 if(LIGHT0_ENABLED) {
  float alignment=max(dot(d,LIGHT0_DIRECTION),0.0);
  color+=LIGHT0_COLOR*pow(alignment,32.0)*.18*atmosphere;
  color+=LIGHT0_COLOR*smoothstep(.99955,.99987,alignment)*2.5;
 }
 if(d.y<0.)color=mix(horizon.rgb,zenith.rgb*.16,pow(-d.y,.32));
 COLOR=color;
}
