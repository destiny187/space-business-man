class_name FrontierSurfaceGeology
extends RefCounted
## The same metre-scale masks are used in terrain.gdshader: rock, wash, sand.
static func sample(x: float,z: float,phase: float) -> Vector3:
	var q:=Vector2(x,z)+Vector2(phase*13.0,phase*7.0)
	var exposure: float=sin(q.x*.045+sin(q.y*.023)*1.8)*.6+sin(q.y*.073+q.x*.019)*.35+sin(q.x*.14-q.y*.09)*.12
	var rock: float=smoothstep(-.12,.48,exposure)
	var bend: float=q.y+sin(q.x*.017+phase)*17.0+sin(q.x*.057)*4.0
	var distance: float=absf(sin(bend*.022+phase))/.022
	var wash: float=1.0-smoothstep(1.8,6.5,distance)
	var sand: float=(1.0-rock)*(1.0-wash)
	return Vector3(rock,wash,sand)
static func phase(traits: Dictionary) -> float:
	return fposmod(float(traits.get("pattern_seed",0)),TAU)
