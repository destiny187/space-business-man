// Shared art direction for native seas, flowing channels and simulated pools.
// Height + analytic slopes. Different directions and wavelengths avoid a dot lattice.
uniform int water_quality : hint_range(0,2) = 1;
vec3 water_wave(vec2 p, float t, float detail) {
 vec2 a=vec2(.27,.16); vec2 b=vec2(-.13,.37);
 float pa=dot(p,a)-t*.72; float pb=dot(p,b)-t*.51+1.7;
 vec3 wave=vec3(sin(pa)*.56+sin(pb)*.32, cos(pa)*a*.56+cos(pb)*b*.32);
 if(water_quality>0) {
  vec2 c=vec2(.71,-.39); vec2 d=vec2(.31,1.03);
  float pc=dot(p,c)-t*1.09+.42*sin(pb*.43);
  float pd=dot(p,d)-t*.89+2.3;
  wave+=vec3(sin(pc)*.16+sin(pd)*.10,cos(pc)*c*.16+cos(pd)*d*.10);
 }
 if(water_quality==2 && detail>.01) {
  vec2 e=vec2(2.3,.91); vec2 f=vec2(-1.17,3.13);
  float pe=dot(p,e)-t*1.72+.65*sin(pa*.73);
  float pf=dot(p,f)-t*1.43+.47*sin(pb*.61);
  wave+=vec3(sin(pe)*.045+sin(pf)*.027,cos(pe)*e*.045+cos(pf)*f*.027)*detail;
 }
 return wave;
}
vec3 water_tint(vec3 base,vec3 wave,vec2 p,float t,float distance_to_eye,float fresnel) {
 float band=smoothstep(-.35,-.20,wave.x)*.16+smoothstep(.38,.51,wave.x)*.12;
 vec3 color=base*(.80+band);
 if(water_quality>0) {
  // Broken, elongated ribbons; never isolated bright maxima of a sine product.
  float phase=dot(p,vec2(.62,.21))-t*.67+.8*sin(dot(p,vec2(.09,-.14))+t*.13);
  float width=max(fwidth(phase)*1.3,.025);
  float crest=1.-smoothstep(.05,.05+width,abs(sin(phase)));
  float breakup=smoothstep(.15,.65,sin(dot(p,vec2(.12,.39))+1.8*sin(p.x*.047)));
  float near_fade=1.-smoothstep(35.,150.,distance_to_eye);
  color=mix(color,base*1.45+vec3(.055,.09,.095),crest*breakup*near_fade*(water_quality==1 ? .12 : .28));
  color=mix(color,vec3(.20,.34,.40),fresnel*(water_quality==1 ? .10 : .24));
 }
 return color;
}
