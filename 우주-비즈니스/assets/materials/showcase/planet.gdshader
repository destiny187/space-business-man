shader_type spatial;
render_mode unshaded;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){float band=sin(p.y*.095+sin(p.x*.06)*.8)*.5+.5;float rim=pow(1.-max(dot(NORMAL,VIEW),0.),3.);float lit=.16+.84*max(dot(normalize(p),normalize(vec3(-.55,.4,.8))),0.);ALBEDO=mix(vec3(.06,.15,.17),vec3(.26,.36,.32),band*.6)*lit+rim*vec3(.025,.075,.085);}
