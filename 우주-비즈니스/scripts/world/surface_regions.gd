extends RefCounted
## Cosmetic geological zones. Matches the terrain vertex shader, not a climate simulation.
static func definition(traits: Dictionary) -> Dictionary:
 var value: Dictionary=traits.get("terrain_layout",{}).get("surface_regions",{})
 return value if int(value.get("version",0))==1 else {}
static func weights(point: Vector3,rules: Dictionary,phase: float) -> Vector3:
 if rules.is_empty():return Vector3(0,1,0)
 var x:=point.x*float(rules.frequency);var z:=point.z*float(rules.frequency)
 var band:=.55*sin(x+sin(z*.73+phase)*1.6+phase)+.45*sin(z*.83+phase*1.3)
 var level:=point.y+band*float(rules.relief)
 var edges: Array=rules.thresholds
 var low:=1.0-smoothstep(float(edges[0]),float(edges[1]),level)
 var high:=smoothstep(float(edges[2]),float(edges[3]),level)
 return Vector3(low,1.0-low-high,high)
