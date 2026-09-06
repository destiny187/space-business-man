class_name FrontierTerrainNavigation
extends RefCounted
## Bounded support-surface A*. It samples geometry, not the fixture's cave curve.
var field: FrontierTerrainField
var settings: Dictionary
var rejected: Dictionary={}
var samples: Dictionary={}
var expanded:=0
func find_path(source: FrontierTerrainField,start: Vector3,goal: Vector3,cfg: Dictionary) -> Dictionary:
	field=source;settings=cfg;expanded=0;samples.clear()
	var started:=Time.get_ticks_usec()
	var first:=support(start.x,start.z,start.y)
	if not first.is_finite():return {"points":[],"reason":"출발 지점에 안전한 바닥이 없습니다."}
	var open: Array[Vector3i]=[]
	var positions: Dictionary={};var costs: Dictionary={};var parents: Dictionary={};var closed: Dictionary={}
	var first_key:=key(first);open.append(first_key);positions[first_key]=first;costs[first_key]=0.0
	while not open.is_empty() and expanded<int(settings.search_limit):
		var best:=0;var best_cost:=INF
		for i in open.size():
			var score: float=float(costs[open[i]])+positions[open[i]].distance_to(goal)
			if score<best_cost:best_cost=score;best=i
		var current: Vector3i=open[best];open.remove_at(best)
		if closed.has(current):continue
		closed[current]=true;expanded+=1
		var p: Vector3=positions[current]
		if Vector2(p.x-goal.x,p.z-goal.z).length()<float(settings.step)*1.1 and absf(p.y-goal.y)<2.5:
			var points: Array[Vector3]=[p]
			while parents.has(current):current=parents[current];points.push_front(positions[current])
			return {"points":points,"reason":"","expanded":expanded,"milliseconds":(Time.get_ticks_usec()-started)/1000.0}
		for dx in [-1,0,1]:
			for dz in [-1,0,1]:
				if dx==0 and dz==0:continue
				var next:=support(p.x+dx*float(settings.step),p.z+dz*float(settings.step),p.y)
				if not next.is_finite() or next.distance_to(start)>float(settings.search_radius):continue
				var next_key:=key(next)
				if closed.has(next_key) or not segment_clear(p,next):continue
				var cost: float=float(costs[current])+p.distance_to(next)
				if cost>=float(costs.get(next_key,INF)):continue
				costs[next_key]=cost;positions[next_key]=next;parents[next_key]=key(p)
				if next_key not in open:open.append(next_key)
	return {"points":[],"reason":"통과 가능한 경로가 없습니다. 통로를 넓히거나 화물을 회수하세요.","expanded":expanded,"milliseconds":(Time.get_ticks_usec()-started)/1000.0}
func key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x/float(settings.step)),floori(p.y),roundi(p.z/float(settings.step)))
func support(x: float,z: float,reference_y: float) -> Vector3:
	var cache_key:=Vector3i(roundi(x*10),roundi(reference_y*5),roundi(z*10))
	if samples.has(cache_key):return samples[cache_key]
	var high: float=reference_y+float(settings.step_height)+.4
	var low: float=reference_y-float(settings.step_height)-.4
	var previous:=Vector3(x,high,z)
	var previous_density: float=field.density(previous)
	var y:=high-.2
	while y>=low:
		var point:=Vector3(x,y,z);var density: float=field.density(point)
		if density>=0 and previous_density<0:
			var surface:=previous.lerp(point,-previous_density/(density-previous_density))
			if absf(surface.y-reference_y)<=float(settings.step_height) and clear_at(surface):samples[cache_key]=surface;return surface
		previous=point;previous_density=density;y-=.2
	samples[cache_key]=Vector3(INF,INF,INF);return samples[cache_key]
func clear_at(foot: Vector3) -> bool:
	var radius: float=float(settings.radius)
	# Side samples start above the rounded wheel/contact region.
	for height in [.55,float(settings.height)]:
		for offset in [Vector3.ZERO,Vector3(radius,0,0),Vector3(-radius,0,0),Vector3(0,0,radius),Vector3(0,0,-radius)]:
			if field.density(foot+Vector3.UP*height+offset)>-.06:return false
	return true
func segment_clear(a: Vector3,b: Vector3) -> bool:
	var horizontal: float=Vector2(a.x-b.x,a.z-b.z).length()
	if absf(a.y-b.y)>horizontal*float(settings.max_slope):return false
	for t in [.25,.5,.75]:
		var expected:=a.lerp(b,t)
		var supported:=support(expected.x,expected.z,expected.y)
		if not supported.is_finite() or absf(supported.y-expected.y)>.45:return false
	return true
