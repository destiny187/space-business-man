shader_type sky;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void sky(){
 vec3 d=normalize(EYEDIR);float belt=pow(max(0.,1.-abs(d.y+d.x*.25)),14.);
 float cloud=sin(d.x*13.+sin(d.z*6.))*sin(d.z*9.-d.x*3.)*.5+.5;
 vec3 base=vec3(.005,.009,.019)+belt*mix(vec3(.021,.025,.063),vec3(.026,.065,.065),cloud);
 vec3 cell=floor(d*700.);float h=hash(cell);vec3 f=fract(d*700.)-.5;
 float star=step(.997,h)*pow(max(0.,1.-length(f)*2.),4.);
 COLOR=base+star*mix(vec3(.60,.81,1.),vec3(1.,.72,.4),hash(cell+8.))*3.;
}
