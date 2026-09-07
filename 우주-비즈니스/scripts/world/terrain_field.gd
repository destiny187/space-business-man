class_name FrontierTerrainField
extends RefCounted
## Positive density is rock. Carving removes mass; it never changes the seed.
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var edits_by_chunk: Dictionary = {}
var span := 24.0
var seed_value := 0
var traits: Dictionary={}

func configure(seed_number: int, edits: Array = [], chunk_span: float = 24.0, characteristics: Dictionary={}) -> void:
	traits=characteristics.duplicate(true)
	edits_by_chunk.clear()
	seed_value=seed_number
	span=chunk_span
	noise.seed=seed_number
	noise.frequency=.013
	noise.fractal_octaves=3
	detail.seed=FrontierUniverse.derive(seed_number,"geology-detail")
	detail.frequency=.045
	detail.fractal_octaves=2
	for edit in edits:add_edit(edit)

func key_at(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x/span),floori(point.y/span),floori(point.z/span))

func add_edit(edit: Dictionary) -> Array[Vector3i]:
	var center:=Vector3(edit.center[0],edit.center[1],edit.center[2])
	var radius:=float(edit.radius)+.5
	var low:=key_at(center-Vector3.ONE*radius)
	var high:=key_at(center+Vector3.ONE*radius)
	var affected: Array[Vector3i]=[]
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for z in range(low.z,high.z+1):
				var key:=Vector3i(x,y,z)
				if not edits_by_chunk.has(key):edits_by_chunk[key]=[]
				edits_by_chunk[key].append(edit)
				affected.append(key)
	return affected

func height(x: float,z: float) -> float:
	var distance: float=Vector2(x,z).length()
	var rough: float=noise.get_noise_2d(x,z)*float(traits.get("relief",42.0))+detail.get_noise_2d(x,z)*4.0
	var base: float=2.0+rough*smoothstep(18.0,65.0,distance)
	if float(traits.get("water",0))>15 and float(traits.get("temperature",-100))>0:
		base-=smoothstep(145.0,230.0,distance)*float(traits.water)*.18
	# Keep the E0 passage under a rock ridge; an unrelated surface valley must
	# not cut steep exterior slopes into its walkable floor.
	var t: float=clampf((x-14.0)/82.0,0,1)
	var lateral: float=1.0-smoothstep(14.0,36.0,absf(z-sin(t*PI)*5.0))
	var ridge: float=lateral*smoothstep(18.0,35.0,x)*(1.0-smoothstep(110.0,145.0,x))
	return lerpf(base,maxf(base,12.0+detail.get_noise_2d(x,z)*2.0),ridge)

func density(p: Vector3) -> float:
	var value: float=height(p.x,p.z)-p.y
	# A connected, walkable inclined entrance and a deeper chamber for risk testing.
	var t: float=clampf((p.x-14.0)/82.0,0,1)
	var center:=Vector3(14.0+t*82.0,7.4-t*27.4,sin(t*PI)*5.0)
	var radius: float=5.4+sin(t*PI)*.7
	var weathering: float=(detail.get_noise_3d(p.x,p.y*1.4,p.z)*.7+sin(p.y*.65+p.x*.045)*.25)*sin(t*PI)
	value=minf(value,p.distance_to(center)-radius+weathering)
	value=minf(value,p.distance_to(Vector3(99,-20,0))-11.0+detail.get_noise_3d(p.x,p.y,p.z)*.7)
	for edit in edits_by_chunk.get(key_at(p),[]):
		value=minf(value,p.distance_to(Vector3(edit.center[0],edit.center[1],edit.center[2]))-float(edit.radius))
	return value

func normal(p: Vector3) -> Vector3:
	var e:=.15
	var gradient:=Vector3(density(p+Vector3(e,0,0))-density(p-Vector3(e,0,0)),density(p+Vector3(0,e,0))-density(p-Vector3(0,e,0)),density(p+Vector3(0,0,e))-density(p-Vector3(0,0,e)))
	return -gradient.normalized() if gradient.length_squared()>.000001 else Vector3.UP
