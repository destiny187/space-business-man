shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz; VERTEX.y+=sin(wp.x*1.8+wp.z*.9+TIME*.6)*.018;}
void fragment(){
 float a=sin(wp.x*3.+wp.z*1.7+TIME*.6),b=sin(wp.z*4.-wp.x*1.2-TIME*.4);
 ALBEDO=mix(vec3(.025,.19,.18),vec3(.075,.36,.31),a*.15+b*.1+.45);
 float river=7.4+sin(wp.z*.095)*2.4;
 float h=sin(wp.x*.29)*sin(wp.z*.19)*.22+sin(wp.z*.35+wp.x*.11)*.10-exp(-pow((wp.x-river)/2.1,4.0))*.72;
 float shore=(1.-smoothstep(.025,.15,abs(h+.33)))*(sin(wp.x*19.+wp.z*11.+TIME*.35)*.25+.65);
 ALBEDO=mix(ALBEDO,vec3(.36,.58,.48),shore*.65);
 ROUGHNESS=.15; METALLIC=.30; SPECULAR=.7;
 NORMAL=normalize(NORMAL+vec3(a*.065,b*.045,0.));
}
