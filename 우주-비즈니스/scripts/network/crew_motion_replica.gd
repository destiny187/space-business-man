class_name FrontierCrewMotionReplica
extends RefCounted
## Position and pose use the same delayed snapshot timeline.
var frames: Array[Dictionary]=[]
func push(position: Vector3,motion: Dictionary) -> void:
	var now:=Time.get_ticks_msec()/1000.0
	if not frames.is_empty() and position.distance_to(frames.back().position)>float(FrontierCrewLocomotion.config().teleport_distance):frames.clear()
	frames.append({"time":now,"position":position,"motion":motion.duplicate(true)})
	while frames.size()>6:frames.pop_front()
func sample() -> Dictionary:
	if frames.is_empty():return {}
	var c:=FrontierCrewLocomotion.config()
	var at:=Time.get_ticks_msec()/1000.0-float(c.remote_delay)
	while frames.size()>2 and float(frames[1].time)<=at:frames.pop_front()
	var a: Dictionary=frames[0]
	if frames.size()==1 or at<=float(a.time):return a.duplicate(true)
	var b: Dictionary=frames[1]
	var t:=clampf((at-float(a.time))/maxf(.001,float(b.time)-float(a.time)),0,1)
	var result: Dictionary=(a if t<1 else b).duplicate(true)
	result.position=a.position.lerp(b.position,t)
	if not a.motion.is_empty() and not b.motion.is_empty():
		result.motion.phase=fposmod(lerp_angle(float(a.motion.phase),float(b.motion.phase),t),TAU)
		result.motion.yaw=lerp_angle(float(a.motion.yaw),float(b.motion.yaw),t)
	return result
