uniform float rough = .5;
uniform float highlight_strength = 1.;
uniform float metal = 0.;
void light(){
 float n=dot(NORMAL,LIGHT);
 // Three deliberate bands, with a narrow antialiased transition.
 float band=.12+.40*smoothstep(.10,.125,n)+.48*smoothstep(.58,.605,n);
 // Local lights include distance falloff in attenuation; thresholding it
 // as a directional shadow makes lamps disappear a few metres away.
 float shadow=LIGHT_IS_DIRECTIONAL?smoothstep(.28,.48,ATTENUATION):ATTENUATION;
 #ifdef INK_SPACE_LIGHTING
 if(space_lighting){
  vec3 to_sun=normalize((VIEW_MATRIX*vec4(space_sun-space_world_position,0.0)).xyz);
  if(dot(to_sun,LIGHT)>.995){
   shadow*=space_visibility(space_world_position);
   band*=mix(.035,1.0,smoothstep(-.08,.12,n));
  }
 }
 #endif
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*band*shadow/PI;
 vec3 half_vector=normalize(VIEW+LIGHT);
 #ifdef INK_SURFACE_ROUGHNESS
 float highlight=pow(max(dot(NORMAL,half_vector),0.),mix(110.,18.,ROUGHNESS));
#else
 float highlight=pow(max(dot(NORMAL,half_vector),0.),mix(110.,18.,rough));
#endif
 float cut=smoothstep(.52,.57,highlight);
 SPECULAR_LIGHT+=LIGHT_COLOR*cut*shadow*(.09+metal*.28)*highlight_strength/PI;
}
