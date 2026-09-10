class_name FrontierSpacePatrol
extends RefCounted
## Host-owned arrival checks; a berth visit is never a permission gate or combat trigger.
static func rules(m: Dictionary) -> Dictionary:return FrontierSpaceTraffic.rules(m).get("patrol",{})
static func enabled(m: Dictionary) -> bool:return FrontierSpaceTraffic.enabled(m) and not rules(m).is_empty()
static func valid_rules(v: Variant) -> bool:
	if not v is Dictionary or v.get("version")!=1:return false
	for e in [["period",60,300],["arrival_radius",2000,5000],["out_seconds",6,30],["scan_seconds",3,15],["return_seconds",6,30],["rearm_seconds",60,300]]:
		if not FrontierUniverse._finite(v.get(e[0]),e[1],e[2]):return false
	return true
static func valid_state(v: Variant) -> bool:
	if not v is Dictionary or v.size()>4096:return false
	for id in v:
		var row: Variant=v[id]
		if not id is String or (id not in FrontierSpaceTraffic.PORTS and FrontierCorporateSites.system_of(id)<0) or not row is Dictionary or not row.get("armed") is bool:return false
		if row.has("target_id") and (not row.target_id is String or row.target_id.length()>192):return false
		if not FrontierUniverse._finite(row.get("started"),-1,1e12) or not FrontierUniverse._vector3_array(row.get("target")):return false
	return true
static func step(world: Dictionary) -> void:
	if not enabled(world.manifest):return
	var nav: Dictionary=world.crew.navigation;var t:=float(nav.orbit_time);var cfg:=rules(world.manifest)
	if not nav.has("traffic_patrols"):nav.traffic_patrols={}
	var records: Dictionary=nav.traffic_patrols
	var systems: Dictionary={int(nav.system):true}
	for observer in nav.get("traffic_observers",[]):systems[int(observer.get("system",0))]=true
	var ports: Array=[]
	for index in systems:ports.append_array(FrontierCorporateSites.guard_ports(world.manifest,index))
	for old in records.keys():
		if old not in ports and t-float(records[old].started)>float(cfg.rearm_seconds):records.erase(old)
	for port in ports:
		if not records.has(port):records[port]={"started":-1.0,"target":[0.0,0.0,0.0],"armed":true}
		var state: Dictionary=records[port];var nearest: Dictionary={};var distance:=float(cfg.arrival_radius)
		var center:=FrontierCrewWorld.vector(FrontierSpaceTraffic.port(world.manifest,port,t).position)
		for observer in nav.get("traffic_observers",[]):
			if int(observer.get("system",0))!=maxi(0,FrontierCorporateSites.system_of(port)):continue
			var gap:=center.distance_to(FrontierCrewWorld.vector(observer.position))
			if not state.armed and observer.get("id","")==state.get("target_id","-") and t-float(state.started)<float(cfg.out_seconds)+float(cfg.scan_seconds) and gap<float(cfg.arrival_radius):state.target=observer.position.duplicate()
			if gap<distance:distance=gap;nearest=observer
		if nearest.is_empty():
			if t-float(state.started)>float(cfg.rearm_seconds):state.armed=true
		elif state.armed:
			state.started=t;state.target=nearest.position.duplicate();state.target_id=nearest.get("id","");state.armed=false
	for craft in FrontierShuttles.fleet(world).values():craft.navigation.traffic_patrols=records
static func frame(m: Dictionary,port: String,t: float) -> Dictionary:
	var station:=FrontierSpaceTraffic.port(m,port,t)
	var center:=FrontierCrewWorld.vector(station.position)
	var radial: Vector3=(center-FrontierUniverse.position(m,int(station.body),t)).normalized()
	var tangent: Vector3=Vector3.RIGHT if absf(radial.y)>.98 else Vector3.UP.cross(radial).normalized()
	return {"center":center,"radial":radial,"tangent":tangent}
static func clear_celestials(m: Dictionary,point: Vector3,t: float,system: int=0) -> Vector3:
	var safe:=point
	var spheres: Array=[{"point":Vector3.ZERO,"radius":float(FrontierUniverse.star_settings(m,system).star_warning_radius)+150}]
	for i in FrontierUniverse.body_count(m,system):
		var ordinal:=FrontierUniverse.first_ordinal(m,system)+i
		var body:=FrontierUniverse.body(m,ordinal);var center:=FrontierUniverse.position(m,ordinal,t)
		spheres.append({"point":center,"radius":FrontierUniverse.navigation_radius(body)+300})
		for moon in body.get("moons",[]):spheres.append({"point":center+FrontierUniverse.moon_offset(body,moon,t),"radius":FrontierUniverse.moon_radius(body,moon)+300})
	for sphere in spheres:
		var away: Vector3=safe-sphere.point
		if away.length()<float(sphere.radius):safe=sphere.point+(away.normalized() if away.length()>1 else Vector3.UP)*float(sphere.radius)
	return safe
static func center_sample(m: Dictionary,port: String,t: float,record: Dictionary,observers: Array) -> Dictionary:
	var f:=frame(m,port,t);var cfg:=rules(m)
	var angle:=t/float(cfg.period)*TAU+float(FrontierUniverse.derive(int(m.seed),port+":patrol")%100)/100*TAU
	var point: Vector3=f.center+f.radial*1200+f.tangent*cos(angle)*800+Vector3.UP*(450+sin(angle)*400)
	var stage: String="patrol";var weight:=0.0
	var start:=float(record.get("started",-1));var age:=t-start
	var out:=float(cfg.out_seconds);var scan:=float(cfg.scan_seconds);var back:=float(cfg.return_seconds)
	if start>=0 and age>=0 and age<out+scan+back:
		if age<out:stage="inspect_approach";weight=smoothstep(0,out,age)
		elif age<out+scan:stage="inspect";weight=1.0
		else:stage="return";weight=1.0-smoothstep(out+scan,out+scan+back,age)
		var destination: Vector3=FrontierCrewWorld.vector(record.target)+f.radial*480+Vector3.UP*140
		point=point.lerp(destination,weight)
	point=FrontierSpaceTraffic.avoid(point,observers,650)
	point=clear_celestials(m,point,t,maxi(0,FrontierCorporateSites.system_of(port)))
	return {"point":point,"stage":stage,"frame":f,"angle":angle,"age":age}
static func all(m: Dictionary,t: float,observers: Array,records: Dictionary,system: int=0,only_port: String="") -> Array:
	if not enabled(m):return []
	var result: Array=[]
	var ports:=FrontierCorporateSites.guard_ports(m,system)
	for port in ports:
		if not only_port.is_empty() and port!=only_port:continue
		var record: Dictionary=records.get(port,{})
		var sample:=center_sample(m,port,t,record,observers)
		var next:=center_sample(m,port,t+.1,record,observers)
		var direction: Vector3=(next.point-sample.point).normalized()
		if direction.length_squared()<.5:direction=sample.frame.tangent
		if sample.stage=="inspect":direction=(FrontierCrewWorld.vector(record.target)-sample.point).normalized()
		for wing in 2:
			var index: int=ports.find(port)*2+wing
			var point: Vector3=sample.point+sample.frame.radial*(wing*2-1)*90
			result.append({"id":m.id+":space_y:warden:"+(str(index) if system==0 else port+":"+str(wing)),"system":system,"call_sign":"WARDEN Y-%02d"%(index+1),"operator":"space_y","kind":"fighter","index":index,"side":wing*2-1,"position":point,"direction":direction,"speed":sample.point.distance_to(next.point)*10,"pods":0.0,"cargo":"항로 경비  2기 편대","stage":sample.stage,"label":{"patrol":"편대 순찰","inspect_approach":"선박 확인 접근","inspect":"센서 확인","return":"순찰 복귀"}[sample.stage],"from":port,"to":port,"destination":FrontierSpaceTraffic.port(m,port,t).short_name,"leg":int(record.get("started",-1)),"u":0.0,"model":"space_y_fighter","bank":sin(sample.angle)*.15 if sample.stage=="patrol" else 0.0})
	return result
