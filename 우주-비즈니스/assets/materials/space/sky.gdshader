shader_type sky;
uniform float local_haze=0.;
uniform vec4 haze_color:source_color=vec4(.3,.4,.5,1);
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float cloud(vec3 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=noise3(p)*a;p=p*2.03+7.3;a*=.5;}return v;}
float stars(vec3 d,float density,float threshold){vec3 q=d*density;vec3 cell=floor(q);vec3 center=vec3(hash(cell+3.),hash(cell+7.),hash(cell+11.));float r=length(fract(q)-center);float aa=max(length(fwidth(q)),.08);return step(threshold,hash(cell))*exp(-r*r/(aa*aa))*.20/aa;}
void sky(){
 vec3 d=normalize(EYEDIR);
 float latitude=dot(d,normalize(vec3(.28,1.,.38)));
 float belt=exp(-abs(latitude)*14.);
 float wisps=cloud(d*12.+vec3(17,4,9));
 float dust=cloud(d*28.+vec3(3,18,7));
 float nebula=pow(max(0.,wisps-.27),2.)*belt;
 vec3 deep=vec3(.0015,.003,.009);
 vec3 palette=mix(vec3(.09,.06,.21),vec3(.03,.18,.22),cloud(d*4.+21.));
 vec3 glow=palette*nebula*2.0+vec3(.13,.16,.20)*belt*.14;
 glow*=mix(.18,1.,smoothstep(.28,.62,dust));
 float fine=stars(d,680.,.985);float bright=stars(d,230.,.997);
 COLOR=deep+glow+haze_color.rgb*local_haze*pow(max(0.,cloud(d*6.+31.)-.25),2.)+fine*vec3(.70,.83,1.)+bright*vec3(1.,.82,.60)*2.;
}
