shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 world_pos;
varying float shore;
void vertex(){
 shore=length(UV*2.0-1.0);
 world_pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 float fade=1.0-smoothstep(.70,1.0,shore);
 VERTEX.y+=(sin(world_pos.x*.7+TIME*.65)+sin(world_pos.z*.9-TIME*.5))*.022*fade;
}
void fragment(){
 vec2 p=world_pos.xz;
 float a=p.x*1.1+p.y*.4+TIME*.85;
 float b=p.y*1.65-p.x*.5-TIME*.65;
 vec3 n=normalize(vec3(-cos(a)*.065+cos(b)*.025,1.0,-cos(a)*.024-cos(b)*.082));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0)).xyz);
 float wave=sin(a)+sin(b);
 float foam=smoothstep(.94,.998,shore)*(.45+.55*smoothstep(-.2,.5,sin(shore*130.0-wave*1.5-TIME*1.2)));
 float crests=smoothstep(1.83,1.98,wave)*(1.0-smoothstep(.6,.95,shore))*.3;
 vec3 deep=vec3(.025,.16,.18);
 vec3 shallow=vec3(.13,.34,.27);
 ALBEDO=mix(mix(deep,shallow,smoothstep(.45,.99,shore)),vec3(.38,.57,.47),max(foam,crests));
 ROUGHNESS=mix(.17,.56,foam);
 METALLIC=.12;
 SPECULAR=.72;
}
