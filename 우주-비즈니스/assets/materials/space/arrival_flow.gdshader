shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 vessel_uv = vec2(0.5, 0.5);
uniform vec4 tint : source_color = vec4(0.9, 0.75, 0.55, 1.0);
// The same foreground layer crosses the hull, with bounded translucency.
uniform float cloud_opacity : hint_range(0.0, 0.65) = 0.58;
uniform float flow_time = -1.0;
float cloud_noise(vec2 p) {
 vec2 cell=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
 vec4 h=fract(sin(vec4(dot(cell,vec2(127.1,311.7)),dot(cell+vec2(1,0),vec2(127.1,311.7)),dot(cell+vec2(0,1),vec2(127.1,311.7)),dot(cell+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
 return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void fragment() {
 vec2 p=UV-vessel_uv;
 float clock=flow_time<0.0?TIME:flow_time;
 // Slanted atmospheric wisps stream past the hull, never an opaque wipe.
 float lane=floor((p.x+p.y*0.22)*45.0);
 float seed=fract(sin(lane*127.1)*43758.5453);
 float trail=fract(p.y*(1.5+seed)+clock*(1.0+seed*0.6)+seed*9.0);
 float narrow=pow(max(0.0,1.0-abs(fract((p.x+p.y*0.22)*45.0)-0.5)*2.0),22.0);
 float streak=narrow*smoothstep(0.65,0.86,trail)*(1.0-smoothstep(0.91,1.0,trail));
 float hull_clear=smoothstep(0.08,0.22,length(p*vec2(1.0,1.6)));
 float bow=exp(-abs(length((p-vec2(0.0,0.07))*vec2(1.0,2.0))-0.20)*100.0);
 float front=smoothstep(0.02,0.08,p.y);
 vec2 drift=vec2(clock*0.32,-clock*0.85);
 vec2 cloud_p=UV*vec2(5.0,8.0)+drift;
 float broad=cloud_noise(cloud_p);
 float detail=cloud_noise(cloud_p*2.7+vec2(clock*0.1,0.0));
 float density=smoothstep(0.30,0.76,broad*0.76+detail*0.24);
 // No hull-clear mask here: irregular cloud banks pass in FRONT of the ship.
 float cloud=density*cloud_opacity;
 float wisps=streak*0.27*hull_clear+bow*front*0.16;
 float alpha=strength*min(0.65,1.0-(1.0-cloud)*(1.0-wisps));
 vec3 cloud_color=mix(tint.rgb*0.82,vec3(1.0,0.91,0.77),0.30+detail*0.18);
 COLOR=vec4(cloud_color,alpha);
}
