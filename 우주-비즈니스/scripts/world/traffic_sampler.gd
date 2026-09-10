class_name FrontierTrafficSampler
extends RefCounted
## Evaluate distant ships at saved low frequency, interpolate their render poses.
var tracks: Dictionary={}
var evaluations:=0
func sample(m: Dictionary,system: int,t: float,camera: Vector3,observers: Array,patrols: Dictionary,focus: String="") -> Array:
	observers=FrontierSpaceTraffic.local_observers(observers,system)
	if tracks.is_empty():
		for row in FrontierSpaceTraffic.all(m,system,t,observers,patrols):tracks[row.id]={"a":row,"b":row,"time":-1.0,"step":0.0}
	var cfg:=FrontierCorporateSites.rules(m);var result: Array=[]
	for id in tracks:
		var track: Dictionary=tracks[id]
		var near: bool=camera.distance_to(track.b.position)<float(FrontierSpaceTraffic.rules(m).near_distance)*1.4 or id==focus
		var step:=float(cfg.get("near_step",.1) if near else cfg.get("far_step",1.0))
		if t<float(track.time) or t>=float(track.time)+float(track.step) or step<float(track.step):
			track.a=_evaluate(m,system,track.a,t,observers,patrols);track.b=_evaluate(m,system,track.a,t+step,observers,patrols);track.time=t;track.step=step
		var row: Dictionary=track.a.duplicate();var weight:=clampf((t-float(track.time))/maxf(.01,float(track.step)),0,1)
		row.position=track.a.position.lerp(track.b.position,weight)
		row.direction=track.a.direction.slerp(track.b.direction,weight).normalized()
		if row.stage==track.b.stage:row.u=lerpf(float(track.a.u),float(track.b.u),weight);row.pods=lerpf(float(track.a.pods),float(track.b.pods),weight)
		result.append(row)
	return result
func _evaluate(m: Dictionary,system: int,row: Dictionary,t: float,observers: Array,patrols: Dictionary) -> Dictionary:
	evaluations+=1
	if row.kind=="freighter":return FrontierSpaceTraffic.sample(m,int(row.index),t,observers) if system==0 else FrontierRegionalTraffic.sample(m,system,int(row.index),t,observers)
	var obstacles: Array=observers.duplicate()
	var freighters: Array=[FrontierSpaceTraffic.sample(m,0,t),FrontierSpaceTraffic.sample(m,1,t)] if system==0 else FrontierRegionalTraffic.freighters(m,system,t)
	for ship in freighters:obstacles.append({"position":FrontierExpeditionBusiness.array(ship.position)})
	for fighter in FrontierSpacePatrol.all(m,t,obstacles,patrols,system,row.from):
		if fighter.id==row.id:return fighter
	return row
