shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
 float flow=.75+.25*sin(UV.y*37.-TIME*2.+UV.x*9.);
 ALBEDO=vec3(.12,.38,1.)*2.0*flow;
 EMISSION=vec3(0.);
 float t=1.-UV.y;
 ALPHA=smoothstep(0.,.07,t)*pow(max(0.,1.-t),2.8)*.045*flow;
}
