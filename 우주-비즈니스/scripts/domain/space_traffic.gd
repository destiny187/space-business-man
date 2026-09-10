class_name FrontierSpaceTraffic
extends RefCounted
## Two scheduled NPC carriers. Host game time is the only clock; no market mutations.
const PORTS := ["solar_earth_logistics","solar_mars_port"]
const LABELS := {"unload":"하역", "load":"적재", "depart":"계류 해제", "ascend":"가속", "cruise":"순항", "descend":"감속", "wait":"접근 승인 대기", "dock":"접안"}
static func rules(m: Dictionary) -> Dictionary:return m.settings.get("corporate_space",{}).get("traffic",{})
static func enabled(m: Dictionary) -> bool:return not rules(m).is_empty() and not FrontierOrbitalPorts.rules(m).is_empty()
static func valid(v: Variant) -> bool:
	if not v is Dictionary or v.get("version")!=1:return false
	for e in [["leg_seconds",600,2400],["lane_height",40000,200000],["avoidance_radius",350,1000],["near_distance",1500,10000],["far_distance",20000,500000]]:
		if not FrontierUniverse._finite(v.get(e[0]),e[1],e[2]):return false
	return true
static func berth(m: Dictionary,port: String,t: float,side: int) -> Vector3:
	return FrontierCrewWorld.vector(FrontierOrbitalPorts.definition(m,port,t).position)+Vector3(side*151,0,38)
static func phase(m: Dictionary,index: int,t: float) -> Dictionary:
	var cfg:=rules(m);var duration:=float(cfg.leg_seconds)
	var offset:=float(FrontierUniverse.derive(int(m.seed),"space_y_freight_phase")%20)+75+index*duration*.5
	var elapsed:=maxf(0,t)+offset
	var leg:=floori(elapsed/duration);var p:=fposmod(elapsed,duration)/duration
	var stage: String="dock";var u:=0.0
	var cuts: Array=[["unload",0,.05],["load",.05,.10],["depart",.10,.15],["ascend",.15,.32],["cruise",.32,.72],["descend",.72,.89],["wait",.89,.93],["dock",.93,1.0]]
	for cut in cuts:
		if p<float(cut[2]):stage=cut[0];u=inverse_lerp(float(cut[1]),float(cut[2]),p);break
	return {"stage":stage,"u":u,"from":PORTS[leg%2],"to":PORTS[(leg+1)%2],"leg":leg,"p":p}
static func path_point(m: Dictionary,index: int,t: float,row: Dictionary) -> Vector3:
	var side:=index*2-1
	var a:=berth(m,row.from,t,side);var b:=berth(m,row.to,t,side)
	var a_gate:=a+Vector3(side*420,220,0);var b_gate:=b+Vector3(side*420,220,0)
	var high:=float(rules(m).lane_height)+index*1800.0
	var a_high:=Vector3(a_gate.x,high,a_gate.z);var b_high:=Vector3(b_gate.x,high,b_gate.z)
	var u:=smoothstep(0,1,float(row.u))
	match row.stage:
		"unload","load":return a
		"depart":return a.lerp(a_gate,u)
		"ascend":return a_gate.lerp(a_high,u)
		"cruise":return a_high.lerp(b_high,u)
		"descend":return b_high.lerp(b_gate,u)
		"wait":return b_gate
		_:return b_gate.lerp(b,u)
static func avoid(point: Vector3,observers: Array,radius: float,weight: float=1.0) -> Vector3:
	var offset:=Vector3.ZERO
	for observer in observers:
		var delta:=point-FrontierCrewWorld.vector(observer.position)
		var distance:=delta.length()
		if distance>=radius:continue
		# Broad continuous displacement, shared by every client. No player hull damage.
		var axis:=delta.normalized() if distance>1 else Vector3.RIGHT
		offset+=axis*(radius-distance)*smoothstep(radius,0,distance)*weight
	return point+offset
static func sample(m: Dictionary,index: int,t: float,observers: Array=[]) -> Dictionary:
	var row:=phase(m,index,t);var point:=path_point(m,index,t,row)
	var next:=path_point(m,index,t+.1,phase(m,index,t+.1))
	var direction: Vector3=(next-point).normalized()
	if row.stage in ["unload","load","wait","dock","depart"]:direction=Vector3.FORWARD
	if direction.length_squared()<.5:direction=Vector3.FORWARD
	var pods:=1.0
	if row.stage=="unload":pods=1.0-smoothstep(.1,.85,float(row.u))
	elif row.stage=="load":pods=smoothstep(.15,.9,float(row.u))
	row.merge({"id":m.id+":space_y:carrier:"+str(index),"call_sign":"CARRIER Y-%02d"%(index+1),"operator":"space_y","kind":"freighter","index":index,"side":index*2-1,"position":point,"direction":direction,"speed":point.distance_to(next)*10,"pods":pods,"cargo":"환경 유지 부품" if row.from==PORTS[0] else "회수·재생 모듈","label":LABELS[row.stage],"model":"space_y_freighter"})
	# Berths are reserved physical machinery space; their cargo may not detach from the crane.
	if row.stage not in ["load","unload"]:row.position=avoid(point,observers,float(rules(m).avoidance_radius),sin(PI*clampf((float(row.p)-.1)/.9,0,1)))
	return row
static func all(m: Dictionary,system: int,t: float,observers: Array=[]) -> Array:
	if system!=0 or not enabled(m):return []
	return [sample(m,0,t,observers),sample(m,1,t,observers)]
static func observers(world: Dictionary) -> Array:
	var result: Array=[];var navs: Array=[]
	if world.crew.landing.is_empty():navs.append(world.crew.navigation)
	for ship in FrontierShuttles.fleet(world).values():
		if ship.state=="sortie" and ship.landing.is_empty():navs.append(ship.navigation)
	for nav in navs:
		if int(nav.system)==0 and nav.mode!="jump":result.append({"position":nav.position.duplicate()})
	return result
