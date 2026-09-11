class_name FrontierSeededCaves
extends RefCounted
## Region-owned connected passages. Each worker owns its cache; sampling order is irrelevant.
var seed_value: int
var rules: Dictionary
var surface: Callable
var cache: Dictionary = {}

func configure(seed_number: int, definition: Dictionary, original_surface: Callable) -> void:
	seed_value=seed_number;rules=definition;surface=original_surface;cache.clear()

func region_at(x: float,z: float) -> Vector2i:
	var size: float=rules.region_size
	return Vector2i(floori((x+size*.5)/size),floori((z+size*.5)/size))

func system_at(x: float,z: float) -> Dictionary:
	var key:=region_at(x,z)
	if cache.has(key):return cache[key]
	var rng:=RandomNumberGenerator.new()
	rng.seed=FrontierUniverse.derive(seed_value,"caves-v1:%d:%d"%[key.x,key.y])
	var result: Dictionary={"id":"cave1:%d:%d"%[key.x,key.y],"segments":[],"chambers":[],"nodes":[]}
	if key!=Vector2i.ZERO and rng.randf()>float(rules.occupancy):
		cache[key]=result;return result
	var angle:=rng.randf_range(0,TAU)
	var forward:=Vector3(cos(angle),0,sin(angle))
	var side:=Vector3(-forward.z,0,forward.x)
	var center:=Vector3(key.x*float(rules.region_size),0,key.y*float(rules.region_size))
	var entrance:=center+forward*rng.randf_range(85,105)
	entrance.y=float(surface.call(entrance.x,entrance.z))+3.0
	var radius:=rng.randf_range(float(rules.radius[0]),float(rules.radius[1]))
	result.floor_a=entrance
	result.floor_b=entrance+forward*float(rules.step)-Vector3.UP*float(rules.step)*float(rules.slope)
	result.floor_offset=radius*.7
	var previous:=entrance
	result.nodes.append(entrance)
	var count:=rng.randi_range(4,6)
	for i in count:
		var distance: float=(i+1)*float(rules.step)
		var next: Vector3=entrance+forward*distance+side*sin((i+1)*.8)*float(rules.bend)*rng.randf_range(.7,1.0)
		next.y=entrance.y-distance*float(rules.slope)
		result.segments.append({"a":previous,"b":next,"radius":radius,"entrance":i==0})
		result.nodes.append(next)
		if i>=1 and (i%2==0 or i==count-1):
			var branch: Vector3=next+side*rng.randf_range(30,50)*(1 if rng.randf()>.5 else -1)
			branch.y=next.y
			result.segments.append({"a":next,"b":branch,"radius":radius,"entrance":false})
			result.chambers.append({"center":branch,"radius":rng.randf_range(9,13)})
		previous=next
	result.chambers.append({"center":previous,"radius":rng.randf_range(10,14)})
	result.deep=preload("res://scripts/world/deep_caves.gd").build(result,key,rules,surface,seed_value)
	# All geometry stays inside its owner region with a rock border; chunks share this graph.
	if cache.size()>32:cache.clear()
	cache[key]=result
	return result

func nearest(p: Vector3,segment: Dictionary) -> Vector3:
	var a: Vector3=segment.a;var b: Vector3=segment.b
	var delta:=b-a
	return a+delta*clampf((p-a).dot(delta)/delta.length_squared(),0,1)

func roof(x: float,z: float,base: float) -> float:
	var system:=system_at(x,z)
	var result:=base
	for segment in system.segments:
		var a: Vector3=segment.a;var b: Vector3=segment.b
		var flat:=Vector3(b.x-a.x,0,b.z-a.z)
		var t:=clampf(Vector3(x-a.x,0,z-a.z).dot(flat)/flat.length_squared(),0,1)
		var center: Vector3=a.lerp(b,t)
		var distance:=Vector2(x-center.x,z-center.z).length()
		var width: float=segment.radius
		var cover:=1.0-smoothstep(width+3,width+14,distance)
		if segment.entrance:cover*=smoothstep(.15,.95,t)
		result=maxf(result,lerpf(base,center.y+width+5,cover))
	for room in system.chambers:
		var center: Vector3=room.center
		var distance:=Vector2(x-center.x,z-center.z).length()
		var cover:=1.0-smoothstep(float(room.radius),float(room.radius)+12,distance)
		result=maxf(result,lerpf(base,center.y+float(room.radius)*.65+5,cover))
	return result

func density(p: Vector3) -> float:
	var system:=system_at(p.x,p.z)
	var value:=INF
	for segment in system.segments:
		var center:=nearest(p,segment)
		var offset:=p-center
		offset.y/=float(rules.ceiling_scale)
		var radius: float=segment.radius
		var shape:=offset.length()-radius
		value=minf(value,shape)
	for room in system.chambers:
		var offset: Vector3=p-room.center;offset.y/=.65
		value=minf(value,offset.length()-float(room.radius))
	# Clip the union once: branch caps cannot cut steps into the main passage floor.
	if not system.segments.is_empty():value=maxf(value,floor_height(p,system.floor_a,system.floor_b)-float(system.floor_offset)-p.y)
	return minf(value,preload("res://scripts/world/deep_caves.gd").density(system.get("deep",{}),p))

func floor_height(p: Vector3,a: Vector3,b: Vector3) -> float:
	var flat:=Vector3(b.x-a.x,0,b.z-a.z)
	# Extend the same floor plane through capsule caps and chambers. Clamping it at
	# a junction creates a recessed step where the next segment's cap overlaps.
	return a.y+(b.y-a.y)*Vector3(p.x-a.x,0,p.z-a.z).dot(flat)/flat.length_squared()
