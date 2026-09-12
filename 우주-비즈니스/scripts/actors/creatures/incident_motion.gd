extends RefCounted
## Saved incident clocks drive only this actor. This adapter never predicts or applies damage.
static func sample(actor: Node3D,row: Dictionary) -> Dictionary:
	if actor.remodel.is_empty() or row.native.role!="guardian" or row.get("native_observed",false):return {}
	var profile: Dictionary=actor.remodel.motion_profile
	var config: Dictionary=FrontierNativeIncidents.config()
	var wait_time:=float(row.get("native_wait",0.))
	var since_contact:=float(config.guard_cooldown)-wait_time
	var recovery: float=actor.recovery_seconds
	if int(row.get("native_attack",0))>0 and wait_time>0 and since_contact<recovery:
		return {"clip":"attack","clock":lerpf(float(profile.release[0]),float(profile.duration),clampf(since_contact/recovery,0,1))}
	var alert:=float(row.get("native_alert",0.))
	if alert<=0:return {}
	# The first warning grows from the host alert clock. Later warnings approach
	# the next attempt as its saved cooldown expires, and cancel when the crew retreats.
	var preparation:=clampf(alert/maxf(.001,float(config.guard_warning)),0,1) if int(row.get("native_attack",0))==0 else clampf(1.-wait_time/maxf(.001,float(config.guard_warning)),0,1)
	return {"clip":"attack","clock":float(profile.release[0])*preparation}
