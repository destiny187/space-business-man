shader_type sky;
uniform float local_haze=0.;
uniform vec3 core_direction=vec3(1,0,0);
uniform float star_density=1.0;
uniform float nebula_strength=1.0;
uniform float sector_hue=0.0;
uniform vec4 haze_color:source_color=vec4(.3,.4,.5,1);
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*f*(f*(f*6.-15.)+10.);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float cloud(vec3 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=noise3(p)*a;p=mat3(vec3(.0,.8,.6),vec3(-.8,.36,-.48),vec3(-.6,-.48,.64))*p*2.03+7.3;a*=.5;}return v;}
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
    float seed=hash(neighbor);
    if(seed>threshold) {
     vec3 center=neighbor+vec3(hash(neighbor+3.),hash(neighbor+7.),hash(neighbor+11.));
     float distance_to_star=length(q-center);
     // Compact support reaches zero before the neighborhood can change.
     float profile=exp(-distance_to_star*distance_to_star/(width*width));
     profile*=1.0-smoothstep(.65,.95,distance_to_star);
     light+=profile*(radius*radius/(width*width))*mix(.7,1.4,hash(neighbor+19.));
    }
   }
  }
 }
 return light;
}
vec3 nebula(vec3 d){
 float latitude=dot(d,normalize(vec3(.28,1.,.38)));
 float core=pow(max(0.0,dot(d,core_direction)),5.0);
 float belt=exp(-abs(latitude)*14.)*(.65+core*.8);
 float wisps=cloud(d*12.+vec3(17,4,9));
 float dust=cloud(d*28.+vec3(3,18,7));
 float nebula=pow(max(0.,wisps-.27),2.)*belt;
 vec3 deep=vec3(.0015,.003,.009);
 vec3 palette=mix(vec3(.09,.06,.21),vec3(.03,.18,.22),cloud(d*4.+21.));
 palette=mix(palette,vec3(.19,.08,.11),sector_hue*.22);
 vec3 glow=palette*nebula*2.0*nebula_strength+vec3(.13,.16,.20)*belt*.14;
 glow*=mix(.18,1.,smoothstep(.28,.62,dust));
 return deep+glow+haze_color.rgb*local_haze*pow(max(0.,cloud(d*6.+31.)-.25),2.);
}

// Cache the static low-frequency background when entering a system. Stars stay
// at screen resolution so small points and their antialiasing remain sharp.
void sky(){
 vec3 d=normalize(EYEDIR);
 if(AT_CUBEMAP_PASS){COLOR=nebula(d);}
 else{
  float fine=stars(d,320.,1.0-.015*star_density);float bright=stars(d,110.,.997);
  COLOR=textureLod(RADIANCE,d,0.).rgb+fine*vec3(.70,.83,1.)*2.5+bright*vec3(1.,.82,.60)*3.5;
 }
}
