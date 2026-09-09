shader_type canvas_item;
uniform float atmosphere=1.0;
uniform float heat=0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 vessel_uv = vec2(0.5, 0.5);
uniform vec4 tint : source_color = vec4(0.9, 0.75, 0.55, 1.0);
// The same foreground layer crosses the hull, with bounded translucency.
uniform float cloud_opacity : hint_range(0.0, 0.65) = 0.58;
uniform float flow_time = -1.0;
#include "res://assets/materials/space/arrival_smoke.gdshaderinc"
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
 vec2 cloud_p=UV*vec2(4.5,5.5)+drift;
 float broad=smoke_density(cloud_p,clock);
 float detail=smoke_density(cloud_p*1.8+vec2(clock*0.1,0.0),clock);
 float density=smoothstep(0.18,0.82,broad*0.80+detail*0.20);
 // No hull-clear mask here: irregular cloud banks pass in FRONT of the ship.
 float cloud=density*cloud_opacity;
 float wisps=streak*0.27*hull_clear+bow*front*0.16;
 float alpha=atmosphere*strength*min(0.65,1.0-(1.0-cloud)*(1.0-wisps));
 vec3 cloud_color=mix(tint.rgb*0.82,tint.rgb*1.18,0.30+detail*0.18);
 cloud_color=mix(cloud_color,vec3(1.0,.42,.13),clamp(bow*front*heat*.7,0.0,.65));
 COLOR=vec4(cloud_color,alpha);
}
