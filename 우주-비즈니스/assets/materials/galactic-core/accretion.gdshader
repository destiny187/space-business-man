shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform bool lens = false;
uniform float energy = 3.0;
float wave(float phase) {
 float footprint=fwidth(phase);
 return sin(phase)*exp(-footprint*footprint*.45);
}
void fragment() {
 float v=1.0-UV.y;
 float a=UV.x*6.2831853*(lens ? .5 : 1.)-TIME*.055/(.24+v);
 float strata=.52+.20*wave(v*174.+sin(a*3.+v*17.)*1.2)+.13*wave(v*411.-a*7.)+.08*wave(a*37.+v*290.);
 float filament=pow(max(0.,wave(v*260.+a*9.+sin(a*5.)*2.)),10.);
 float heat=clamp((1.-v)*.78+strata*.30+filament*.13,0.,1.);
 vec3 ember=mix(vec3(.12,.006,.001),vec3(1.,.25,.015),smoothstep(.12,.70,heat));
 vec3 plasma=mix(ember,vec3(1.,.88,.56),smoothstep(.72,1.,heat));
 float beaming=.58+.42*cos(a+.7);
 ALBEDO=plasma*(.28+strata+filament*.35)*beaming*energy;
 EMISSION=vec3(0.);
 ALPHA=smoothstep(0.,.035,v)*pow(max(0.,1.-v),.6)*.95;
}
