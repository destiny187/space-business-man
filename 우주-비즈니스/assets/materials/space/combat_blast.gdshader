shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
// Camera-facing plasma, flash and ejecta. No opaque sphere or rigid shock ring.
uniform float age : hint_range(0.0,1.0) = 0.0;
uniform float variation = 0.0;
uniform int kind = 0;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) { return noise(p)*0.57+noise(p*2.13+4.1)*0.28+noise(p*4.27)*0.15; }
void fragment() {
 vec2 p=UV*2.0-1.0;
 float t=clamp(age,0.0,1.0), r=length(p);
 float n=fbm(p*3.8+vec2(variation,variation*0.7)+p*t*2.3);
 float envelope=smoothstep(0.0,0.035,t)*(1.0-smoothstep(0.42,1.0,t));
 vec3 color=vec3(1.0,0.28,0.045); float alpha=0.0;
 if (kind==1) {
  // One very brief irregular pressure flash with fine radial spikes.
  float a=atan(p.y,p.x);
  float spikes=pow(abs(sin(a*7.0+variation)),14.0)*0.28+pow(abs(sin(a*13.0-variation)),22.0)*0.18;
  float edge=0.26+spikes+(n-0.5)*0.12;
  alpha=(1.0-smoothstep(edge*0.55,edge,r))*envelope;
  color=mix(vec3(1.0,0.48,0.1),vec3(1.0,0.91,0.68),1.0-smoothstep(0.03,0.2,r));
 } else if (kind==2) {
  // Thin tapered ejecta streak, hot leading edge and cooler tail.
  float taper=sqrt(max(0.0,1.0-p.x*p.x));
  alpha=(1.0-smoothstep(0.1*taper,0.55*taper+0.001,abs(p.y)))*(1.0-smoothstep(0.65,1.0,abs(p.x)))*envelope;
  color=mix(vec3(0.85,0.13,0.025),vec3(1.0,0.84,0.5),smoothstep(-0.75,0.65,p.x))*(1.0-t*0.55);
 } else {
  // Advect a broken filament field through an uneven outline, then dissolve.
  float edge=0.58+(n-0.5)*0.6;
  float body=1.0-smoothstep(edge-0.17,edge+0.05,r);
  float filaments=fbm(p*6.5+vec2(variation+t*2.2,-variation-t*1.8));
  float dissolve=smoothstep(t*0.62-0.06,t*0.62+0.16,filaments);
  float heat=(1.0-r)*0.5+n*0.58-t*0.68;
  color=mix(vec3(0.32,0.035,0.013),vec3(1.0,0.24,0.028),smoothstep(0.17,0.24,heat));
  color=mix(color,vec3(1.0,0.69,0.22),smoothstep(0.47,0.53,heat));
  color=mix(color,vec3(1.0,0.91,0.65),smoothstep(0.73,0.78,heat));
  alpha=body*dissolve*envelope*0.88;
  if (kind==3) {
   color=mix(vec3(0.06,0.07,0.085),vec3(0.22,0.12,0.065),n)*(1.0-t*0.4);
   alpha*=0.48;
  }
 }
 ALBEDO=color; EMISSION=color*(kind==1 ? 1.0 : (kind==3 ? 0.0 : 0.25*(1.0-t)));
 ALPHA=clamp(alpha,0.0,1.0);
}
