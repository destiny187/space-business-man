shader_type canvas_item;
uniform vec4 soil : source_color = vec4(0.7,0.48,0.35,1.0);
uniform float aspect = 1.6;
uniform float seed = 1.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))+seed)*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p=(UV-0.5)*vec2(aspect,1.0)*2.2;
	float r=length(p);
	vec3 color=vec3(0.035,0.075,0.10);
	float stars=step(0.996,hash(floor(UV*vec2(270,170))));
	color+=stars*0.32;
	if(r<0.82) {
		vec3 normal=vec3(p/0.82,sqrt(max(0.0,1.0-dot(p,p)/(0.82*0.82))));
		vec2 land=vec2(atan(normal.x,normal.z),asin(normal.y))*3.5+vec2(TIME*0.015,0);
		float n=noise(land*4.0)+noise(land*9.0)*0.3+noise(land*20.0)*0.1;
		vec3 surface=mix(soil.rgb*0.48,soil.rgb*1.2,smoothstep(0.2,1.05,n));
		float light=clamp(dot(normal,normalize(vec3(-0.65,0.4,0.65))),0.0,1.0);
		color=surface*(.12+.4*smoothstep(.10,.125,light)+.48*smoothstep(.58,.605,light))+vec3(0.33,0.7,0.7)*pow(1.0-normal.z,3.0)*light*0.5;
	}
	float line=1.-smoothstep(.006,.012,abs(r-.82));
	color=mix(color,vec3(.012,.016,.02),line);
	COLOR=vec4(color,1.0);
}
