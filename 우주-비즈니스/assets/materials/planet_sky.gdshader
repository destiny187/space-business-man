shader_type sky;
uniform vec4 zenith : source_color = vec4(.12,.23,.33,1);
uniform vec4 horizon : source_color = vec4(.68,.49,.36,1);
uniform float life : hint_range(0,1) = 0.0;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y); }
void sky(){
 float altitude=max(EYEDIR.y,0.0);
 vec3 color=mix(horizon.rgb,zenith.rgb,pow(altitude,.42));
 if(EYEDIR.y>0.015){
  vec2 p=EYEDIR.xz/(altitude+.17)*2.5;
  float cloud=noise(p)*.57+noise(p*2.13)*.28+noise(p*4.3)*.15;
  float density=smoothstep(.50,.75,cloud)*smoothstep(.025,.2,altitude)*(1.0-smoothstep(.75,1.0,altitude));
  vec3 cloud_color=mix(horizon.rgb,vec3(.82,.87,.81),.55+life*.3);
  color=mix(color,cloud_color,density*(.45+life*.35));
 }
 if(LIGHT0_ENABLED){
  float alignment=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
  color+=LIGHT0_COLOR*pow(alignment,24.0)*.1;
  color+=LIGHT0_COLOR*smoothstep(.99972,.99994,alignment)*4.0;
 }
 if(EYEDIR.y<0.0) color=mix(horizon.rgb,vec3(.065,.07,.06),pow(-EYEDIR.y,.3));
 // No TIME/POSITION: radiance is refreshed only when terraforming changes the sky.
 COLOR=color;
}
