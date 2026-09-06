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
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*band*shadow/PI;
 vec3 half_vector=normalize(VIEW+LIGHT);
 float highlight=pow(max(dot(NORMAL,half_vector),0.),mix(110.,18.,rough));
 float cut=smoothstep(.52,.57,highlight);
 SPECULAR_LIGHT+=LIGHT_COLOR*cut*shadow*(.09+metal*.28)*highlight_strength/PI;
}
