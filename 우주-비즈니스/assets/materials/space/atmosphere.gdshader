shader_type spatial;
render_mode unshaded, cull_front, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(.18,.48,.60,1);
void fragment(){float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),3.5);ALBEDO=tint.rgb;ALPHA=rim*.32;}
