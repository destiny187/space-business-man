shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.51,0.85,0.77,1.0);
uniform float coverage_dot = 0.3;
varying vec3 local_normal;
void vertex(){local_normal=normalize(VERTEX);}
void fragment(){
 float facing=dot(normalize(local_normal),vec3(0.0,0.0,-1.0));
 float coverage=smoothstep(coverage_dot,coverage_dot+0.07,facing);
 float edge=1.0-smoothstep(coverage_dot+0.04,coverage_dot+0.12,facing);
 vec2 grid=abs(fract(UV*vec2(24.0,12.0))-0.5);
 float cells=smoothstep(0.45,0.49,max(grid.x,grid.y));
 float rim=pow(1.0-abs(dot(NORMAL,VIEW)),2.0);
 ALBEDO=tint.rgb*.25;
 EMISSION=tint.rgb*(0.4+rim*0.6);
 ALPHA=coverage*(0.06+cells*0.12+edge*0.45+rim*0.10)*(0.92+sin(TIME*4.0)*0.08);
}
