shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 float y=max(EYEDIR.y,0.);
 vec3 col=mix(vec3(.28,.47,.53),vec3(.028,.12,.24),pow(y,.48));
 vec2 p=EYEDIR.xz/max(.15,EYEDIR.y+.18)*2.;
 float n=noise(p)*.55+noise(p*2.)*.28+noise(p*4.)*.12+noise(p*8.)*.05;
 float cloud=smoothstep(.54,.76,n)*smoothstep(.04,.30,EYEDIR.y);
 col=mix(col,vec3(.63,.65,.59),cloud*.72);
 COLOR=pow(col,vec3(1.8));
}
