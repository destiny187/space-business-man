extends RefCounted
## Bounded host pose history, never a world snapshot. Each shooter retains six
## nearby shape sets; no inventory, terrain, save or unrelated UI is copied.
const Targets=preload("res://scripts/domain/firearm_targets.gd")
var frames: Dictionary={}
var issued: Dictionary={}
var captured_at:=-1.0
func issue(peer: int,time: float) -> void:
	if not issued.has(peer):issued[peer]=[]
	if not issued[peer].is_empty() and issued[peer].back()==time:return
	issued[peer].append(time)
	while issued[peer].size()>8:issued[peer].pop_front()
func capture(world: Dictionary,peers: Dictionary,time: float) -> void:
	var rules: Dictionary=FrontierFirearms.config().rewind
	if time-captured_at<float(rules.sample):return
	captured_at=time
	for peer in issued.keys():
		if not peers.has(peer):issued.erase(peer)
	for id in frames.keys():
		if id not in peers.values():frames.erase(id)
	for actor in peers.values():
		var member: Dictionary=world.crew.members[actor]
		if member.area!="surface" or member.aboard or not FrontierEquipment.active(member).has("firearm"):frames.erase(actor);continue
		var local:=FrontierShuttles.context(world,actor)
		if not FrontierCrewSurface.landed(local):continue
		if not frames.has(actor):frames[actor]=[]
		frames[actor].append({"time":time,"body":local.location,"origin":FrontierCrewWorld.vector(member.position)+Vector3.UP*FrontierFirearms.eye(member),"rows":Targets.candidates(local,actor)})
		while frames[actor].size()>int(rules.samples):frames[actor].pop_front()
func authorized(peer: int,actor: String,body: String,stamp: Variant,now: float,origin: Vector3) -> Dictionary:
	if peer==1 or not FrontierUniverse._finite(stamp,maxf(0,now-float(FrontierFirearms.config().rewind.window)),now):return {}
	if stamp not in issued.get(peer,[]):return {}
	var frame:=at(actor,body,float(stamp))
	if frame.is_empty() or now-float(frame.time)>float(FrontierFirearms.config().rewind.window) or origin.distance_to(frame.origin)>float(FrontierFirearms.config().rewind.max_origin_distance):return {}
	return frame
func at(actor: String,body: String,time: float) -> Dictionary:
	var rows: Array=frames.get(actor,[])
	for index in range(rows.size()-1,-1,-1):
		var frame: Dictionary=rows[index]
		if frame.body==body and float(frame.time)<=time+.001 and time-float(frame.time)<=float(FrontierFirearms.config().rewind.sample)*1.6:return frame
	return {}
