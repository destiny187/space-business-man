shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.22,0.95,0.82,1.0);
uniform vec3 impact_direction = vec3(0.0,0.0,-1.0);
uniform float age = 0.0;
uniform float strength = 1.0;
varying vec3 local_normal;
void vertex(){local_normal=normalize(VERTEX);}
void fragment(){
 float angle=acos(clamp(dot(normalize(local_normal),normalize(impact_direction)),-1.0,1.0));
 float wave=exp(-pow((angle-age*5.5)/0.085,2.0));
 float patch=exp(-angle*angle*2.3)*(1.0-clamp(age*3.0,0.0,1.0));
 float rim=pow(1.0-abs(dot(NORMAL,VIEW)),3.0)*0.08;
 vec2 grid=abs(fract(UV*vec2(32.0,16.0))-0.5);
 float cells=smoothstep(0.43,0.49,max(grid.x,grid.y));
 ALBEDO=tint.rgb*.35;
 EMISSION=tint.rgb*(wave*.7+patch*.3);
 ALPHA=clamp((wave*.55+patch*.22+rim*wave+cells*.10*patch)*strength*(1.0-clamp(age/0.65,0.0,1.0)),0.0,0.48);
}
