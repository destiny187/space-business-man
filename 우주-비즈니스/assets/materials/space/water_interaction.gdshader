shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform int shape = 0;
varying vec4 event;
void vertex() { event = INSTANCE_CUSTOM; }
void fragment() {
 float age=event.x;
 float fade=smoothstep(1.0,0.52,age)*smoothstep(0.0,0.06,age);
 vec3 ink=vec3(0.035,0.12,0.16);
 vec3 foam=vec3(0.63,0.89,0.89);
 if(shape==0) {
  vec2 p=UV*2.0-1.0;
  float r=length(p);
  float angle=atan(p.y,p.x);
  float ripple=0.70+sin(angle*7.0+event.y)*0.015;
  float d=abs(r-ripple);
  float border=1.0-smoothstep(0.045,0.060,d);
  float inner=1.0-smoothstep(0.013,0.032,d);
  float broken=0.5+0.5*smoothstep(-0.8,0.5,sin(angle*5.0+event.y));
  ALBEDO=mix(ink,foam,inner);
  ALPHA=border*fade*broken*0.64;
 } else if(shape==1) {
  float rim=smoothstep(0.62,0.96,UV.y);
  ALBEDO=mix(vec3(0.16,0.49,0.56),foam,rim);
  ALPHA=fade*(0.20+rim*0.53);
 } else {
  float edge=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
  float band=step(0.4,NORMAL.y*.5+.5);
  ALBEDO=mix(mix(vec3(0.13,0.46,0.55),foam,band),ink,step(.64,edge));
  ALPHA=fade*0.88;
 }
}
