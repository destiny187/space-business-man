uniform float cloud_coverage=.45;
uniform float cloud_seed=0.0;
uniform float cloud_time=0.0;
uniform float cloud_wind=.0008;
uniform float storm_strength=0.0;
float cloud_hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7))+cloud_seed)*43758.5453);}
float cloud_noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(cloud_hash(i),cloud_hash(i+vec3(1,0,0)),f.x),mix(cloud_hash(i+vec3(0,1,0)),cloud_hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(cloud_hash(i+vec3(0,0,1)),cloud_hash(i+vec3(1,0,1)),f.x),mix(cloud_hash(i+vec3(0,1,1)),cloud_hash(i+vec3(1)),f.x),f.y),f.z);}
float cloud_field(vec3 point){
 float angle=cloud_time*cloud_wind;
 vec3 p=vec3(cos(angle)*point.x-sin(angle)*point.z,point.y,sin(angle)*point.x+cos(angle)*point.z);
 p.x+=sin(p.y*8.0+cloud_seed)*.09;p*=6.0;
 float n=cloud_noise(p)*.60+cloud_noise(p*2.07)*.27+cloud_noise(p*4.13)*.13;
 return smoothstep(.72-cloud_coverage*.33,.82-cloud_coverage*.33,n)*smoothstep(0.0,.12,cloud_coverage);
}
