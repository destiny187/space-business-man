class_name FrontierRegionalTraffic
extends RefCounted
## A route references two generated endpoints; unloaded systems have no ticking objects.
static func freighters(m: Dictionary,system: int,t: float,observers: Array=[]) -> Array:
	var result: Array=[]
	for route in FrontierCorporateSites.profile(m,system).routes:
		if route.active:
			for i in 2:result.append(sample(m,system,i,t,observers))
	return result
static func phase(m: Dictionary,system: int,index: int,t: float) -> Dictionary:
	var route: Dictionary=FrontierCorporateSites.profile(m,system).routes[0]
	var duration:=float(FrontierCorporateSites.rules(m).leg_seconds)
	var elapsed:=maxf(0,t)+float(int(route.seed)%int(duration))+index*duration*.5
	var leg:=floori(elapsed/duration);var p:=fposmod(elapsed,duration)/duration
	var stage: String="dock";var u:=0.0
	for cut in [["unload",0,.05],["load",.05,.10],["depart",.10,.15],["ascend",.15,.32],["cruise",.32,.72],["descend",.72,.89],["wait",.89,.93],["dock",.93,1.0]]:
		if p<float(cut[2]):stage=cut[0];u=inverse_lerp(float(cut[1]),float(cut[2]),p);break
	return {"stage":stage,"u":u,"from":route.ends[leg%2],"to":route.ends[(leg+1)%2],"leg":leg,"p":p,"route":route}
static func point(m: Dictionary,system: int,index: int,t: float,row: Dictionary) -> Vector3:
	var side:=index*2-1
	var a:=FrontierSpaceTraffic.berth(m,row.from,t,side);var b:=FrontierSpaceTraffic.berth(m,row.to,t,side)
	var a_gate:=a+Vector3(side*420,220,0);var b_gate:=b+Vector3(side*420,220,0)
	# Positive polar corridor remains clear of the star and moving inclined orbits.
	var high:=maxf(float(FrontierUniverse.star_settings(m,system).star_warning_radius)+12000,FrontierUniverse.orbit_radius(m,system,FrontierUniverse.body_count(m,system)-1)*1.7+10000)+index*1800
	var a_high:=Vector3(a_gate.x,high,a_gate.z);var b_high:=Vector3(b_gate.x,high,b_gate.z)
	var u:=smoothstep(0,1,float(row.u));var result:=a
	match row.stage:
		"unload","load":return a
		"depart":result=a.lerp(a_gate,u)
		"ascend":result=a_gate.lerp(a_high,u)
		"cruise":result=a_high.lerp(b_high,u)
		"descend":result=b_high.lerp(b_gate,u)
		"wait":result=b_gate
		"dock":result=b_gate.lerp(b,u)
	return FrontierSpacePatrol.clear_celestials(m,result,t,system)
static func sample(m: Dictionary,system: int,index: int,t: float,observers: Array=[]) -> Dictionary:
	var row:=phase(m,system,index,t);var p:=point(m,system,index,t,row)
	var next:=point(m,system,index,t+.1,phase(m,system,index,t+.1))
	var direction: Vector3=(next-p).normalized()
	if row.stage in ["unload","load","wait","dock","depart"] or direction.length_squared()<.5:direction=Vector3.FORWARD
	var pods:=1.0
	if row.stage=="unload":pods=1.0-smoothstep(.1,.85,float(row.u))
	elif row.stage=="load":pods=smoothstep(.15,.9,float(row.u))
	row.merge({"id":m.id+":"+row.route.id+":carrier:"+str(index),"call_sign":"CARRIER Y-%d-%02d"%[system,index+1],"operator":"space_y","kind":"freighter","index":index,"system":system,"side":index*2-1,"position":p,"direction":direction,"speed":p.distance_to(next)*10,"pods":pods,"cargo":row.route.cargo,"label":FrontierSpaceTraffic.LABELS[row.stage],"model":"space_y_freighter","destination":FrontierSpaceTraffic.port(m,row.to,t).short_name})
	row.erase("route")
	if row.stage not in ["load","unload"]:
		row.position=FrontierSpacePatrol.clear_celestials(m,FrontierSpaceTraffic.avoid(p,observers,float(FrontierSpaceTraffic.rules(m).avoidance_radius),sin(PI*clampf((float(row.p)-.1)/.9,0,1))),t,system)
	return row
