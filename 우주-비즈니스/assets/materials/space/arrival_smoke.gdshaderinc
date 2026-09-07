vec2 smoke_gradient(vec2 p) {
 return -1.0+2.0*fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);
}
float smoke_noise(vec2 p) {
 vec2 i=floor(p), f=fract(p);vec2 u=f*f*f*(f*(f*6.0-15.0)+10.0);
 return mix(mix(dot(smoke_gradient(i),f),dot(smoke_gradient(i+vec2(1,0)),f-vec2(1,0)),u.x),mix(dot(smoke_gradient(i+vec2(0,1)),f-vec2(0,1)),dot(smoke_gradient(i+vec2(1,1)),f-vec2(1,1)),u.x),u.y);
}
float smoke_fbm(vec2 p) {
 float n=0.0, amplitude=0.55;
 for(int i=0;i<5;i++) {n+=amplitude*smoke_noise(p);p=mat2(vec2(0.8,0.6),vec2(-0.6,0.8))*p*2.03+vec2(7.3,13.1);amplitude*=0.5;}
 return n;
}
float smoke_density(vec2 p, float clock) {
 vec2 curl=vec2(smoke_fbm(p*0.63+vec2(clock*0.09,0)),smoke_fbm(p*0.63+vec2(4.7,-clock*0.07)));
 return clamp(0.5+smoke_fbm(p+curl*2.8)*1.7,0.0,1.0);
}
