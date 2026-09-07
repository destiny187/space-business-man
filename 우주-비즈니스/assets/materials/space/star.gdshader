shader_type spatial;
render_mode unshaded;
uniform vec4 tint:source_color=vec4(1.0,.65,.22,1.0);
void fragment(){
 float cells=sin(UV.x*220.0+sin(UV.y*130.0))*sin(UV.y*160.0+TIME*.13);
 float limb=pow(max(dot(normalize(NORMAL),normalize(VIEW)),0.0),.4);
 ALBEDO=tint.rgb*(2.2+cells*.24+limb*1.65);
}
