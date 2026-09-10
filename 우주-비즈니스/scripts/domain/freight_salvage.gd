class_name FrontierFreightSalvage
extends RefCounted
## Immutable incident per route; the saved ledger is also the external cargo inventory.
const MODEL := "ships/lost_freight_pod"
const ICON := "res://assets/ui/corporations/lost_freight_pod.png"
static func maintenance(id: String) -> bool:return id.begins_with(FrontierMineMaintenance.PREFIX)
static func states(id: String) -> Array:return FrontierMineMaintenance.STATES if maintenance(id) else STATES
static func last_stage(id: String) -> int:return states(id).size()-1
static func icon(id: String) -> String:return "res://assets/ui/corporations/mine_service_pack.png" if maintenance(id) else ICON
static func all(m: Dictionary,system: int,t: float=0) -> Array:
	var result: Array=[]
	for id in [address(system),FrontierMineMaintenance.address(system)]:
		var row:=definition(m,id,t)
		if not row.is_empty():result.append(row)
	return result
static func endpoint(row: Dictionary,stage: int) -> Array:return row.receiver if stage>=2 or (maintenance(row.id) and stage==0) else row.position
static func seconds(m: Dictionary,id: String,stage: int) -> float:
	var cfg:=rules(m)
	if maintenance(id):
		var service:=FrontierMineMaintenance.rules(m)
		return float([service.diagnose_seconds,cfg.recover_seconds,cfg.handover_seconds,service.repair_seconds][stage])
	return float([cfg.identify_seconds,cfg.recover_seconds,cfg.handover_seconds][stage])
const STATES := ["미확인 구조 신호","회수 대기","선박에 적재","항만 인계 완료"]
static func rules(m: Dictionary) -> Dictionary:return m.settings.get("corporate_space",{}).get("salvage",{})
static func records(world: Dictionary) -> Dictionary:return world.get("crew",{}).get("freight_records",{})
static func address(system: int) -> String:return "freight-v1:"+str(system)
static func system_of(id: String) -> int:
	var prefix:=FrontierMineMaintenance.PREFIX if maintenance(id) else "freight-v1:"
	var suffix:=id.trim_prefix(prefix);var system:=int(suffix)
	return system if suffix.is_valid_int() and system>=0 and system<125000 and prefix+str(system)==id else -1
static func carrier(local: Dictionary) -> String:return "shuttle:"+str(local.local_shuttle) if local.has("local_shuttle") else "crew"
static func carried(rows: Dictionary,vessel: String) -> String:
	for id in rows:
		if int(rows[id].stage)==2 and rows[id].carrier==vessel:return id
	return ""
static func valid_rules(v: Variant) -> bool:
	if not v is Dictionary or v.get("version")!=1:return false
	for e in [["chance",0,100],["signal_distance",5000,15000],["identify_distance",1000,4000],["recover_distance",120,300],["handover_distance",300,450],["identify_seconds",1,5],["recover_seconds",3,10],["handover_seconds",2,8],["max_speed",50,200],["payment",1,10000]]:
		if not FrontierUniverse._finite(v.get(e[0]),e[1],e[2]):return false
	return FrontierExpeditionBusiness.integer(v.payment,1,10000) and FrontierExpeditionBusiness.integer(v.chance,0,100)
static func valid(rows: Variant,crew: Dictionary) -> bool:
	if not rows is Dictionary or rows.size()>250000:return false
	var occupied: Dictionary={}
	for id in rows:
		if not id is String or system_of(id)<0:return false
		var row: Variant=rows[id]
		if not row is Dictionary or not FrontierExpeditionBusiness.integer(row.get("stage"),1,last_stage(id)) or not row.get("carrier") is String or not FrontierUniverse._finite(row.get("at"),0,9007199254740000):return false
		if int(row.stage)==1:
			if row.carrier!="":return false
		elif row.carrier!="crew":
			if not row.carrier.begins_with("shuttle:") or not FrontierPlayerProfile.identifier(row.carrier.trim_prefix("shuttle:")):return false
			if int(row.stage)==2 and not crew.get("shuttles",{}).has(row.carrier.trim_prefix("shuttle:")):return false
		if int(row.stage)==2:
			if occupied.has(row.carrier):return false
			occupied[row.carrier]=id
	return true
static func snapshot(rows: Dictionary,system: int) -> Dictionary:
	var result: Dictionary={};var keys: Array=rows.keys()
	for id in keys.slice(maxi(0,keys.size()-256)):result[id]=rows[id].duplicate()
	for id in rows:
		if int(rows[id].stage)==2 or system_of(id)==system:result[id]=rows[id].duplicate()
	return result
static func definition(m: Dictionary,id: String,t: float=0) -> Dictionary:
	var system:=system_of(id);var cfg:=rules(m)
	if maintenance(id):return FrontierMineMaintenance.definition(m,system,t)
	if system<0 or cfg.is_empty() or not FrontierSpaceTraffic.enabled(m):return {}
	var seed_value:=FrontierUniverse.derive(int(m.seed),id)
	var destination: String="solar_mars_port";var cargo: String="환경 유지 부품"
	if system>0:
		if seed_value%100>=int(cfg.chance):return {}
		var routes: Array=FrontierCorporateSites.profile(m,system).routes
		if routes.is_empty() or not routes[0].active:return {}
		destination=routes[0].ends[1];cargo=routes[0].cargo
	var port:=FrontierSpaceTraffic.port(m,destination,t)
	if port.is_empty():return {}
	var receiver:=FrontierCrewWorld.vector(port.position)+Vector3(0,0,245)
	var loose:=receiver+Vector3(950,450,800)+Vector3(float(seed_value%150),0,0)
	return {"id":id,"system":system,"body":int(port.body),"body_id":FrontierUniverse.body_id(m,int(port.body)),"company":"space_y","name":"CARRIER 유실 화물","model":MODEL,"cargo":cargo,"destination":destination,"port_name":port.name,"call_sign":"CARRIER Y-01" if system==0 else "CARRIER Y-%d-01"%system,"receiver":FrontierExpeditionBusiness.array(receiver),"position":FrontierExpeditionBusiness.array(loose),"payment":int(cfg.payment),"seed":seed_value}
static func target(m: Dictionary,nav: Dictionary,aim: Vector3,rows: Dictionary,vessel: String) -> Dictionary:
	if rules(m).is_empty() or nav.get("mode","")!="idle" or aim.length_squared()<.5:return {}
	var best: Dictionary={}
	for row in all(m,int(nav.system),float(nav.get("orbit_time",0))):
		var record: Dictionary=rows.get(row.id,{"stage":0,"carrier":""})
		row.stage=int(record.stage);row.carrier=record.carrier
		if row.stage==2 and row.carrier!=vessel:continue
		row.position=endpoint(row,row.stage)
		var point:=FrontierCrewWorld.vector(row.position);var origin:=FrontierCrewWorld.vector(nav.position);var offset:=point-origin
		if offset.length()>float(rules(m).signal_distance) or offset.normalized().dot(aim.normalized())<.985 or FrontierCorporateTraces.occluded(m,int(nav.system),float(nav.get("orbit_time",0)),origin,point):continue
		row.distance=offset.length()
		if best.is_empty() or row.distance<best.distance:best=row
	return best
static func reason(m: Dictionary,nav: Dictionary,target: Dictionary,rows: Dictionary,vessel: String,pilot: bool) -> String:
	var stage:=int(target.stage);var cfg:=rules(m)
	if stage==last_stage(target.id):return "작업 완료 · 대금 지급 · J"
	if stage>0 and not pilot:return "조종사가 회수 장치를 운용합니다"
	if stage==1 and not carried(rows,vessel).is_empty():return "회수 거치대 사용 중 · 기존 화물을 인계하세요"
	var limit:=float(cfg.identify_distance if stage==0 else (cfg.recover_distance if stage==1 else cfg.handover_distance))
	if maintenance(target.id):
		if stage==0:limit=float(FrontierMineMaintenance.rules(m).diagnose_distance)
		elif stage==3:limit=float(FrontierMineMaintenance.rules(m).repair_distance)
	if float(target.distance)>limit:return "%.0fm 이내로 접근"%limit
	if absf(float(nav.get("speed",0)))>float(cfg.max_speed):return "속도를 %.0fm/s 이하로 낮추세요"%float(cfg.max_speed)
	return ""
static func missing_pod(m: Dictionary,ship: Dictionary) -> bool:
	return ship.get("kind","")=="freighter" and int(ship.get("index",-1))==0 and int(ship.get("leg",-1))==0 and not definition(m,address(int(ship.get("system",0)))).is_empty()
static func drift(world: Dictionary,old_time: float) -> bool:
	var nav: Dictionary=world.crew.navigation
	var id: String=nav.get("freight_anchor","")
	if id.is_empty():return false
	var row:=definition(world.manifest,id,float(nav.orbit_time))
	if nav.mode!="idle" or row.is_empty() or int(row.system)!=int(nav.system):nav.erase("freight_anchor");return false
	var previous:=definition(world.manifest,id,old_time)
	var field: String="position" if nav.get("freight_anchor_source",false) else "receiver"
	var drift_vector:=FrontierCrewWorld.vector(row[field])-FrontierCrewWorld.vector(previous[field])
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(nav.position)+drift_vector)
	world.flight_position=nav.position.duplicate();nav.speed=0
	return true
static func obstacles(m: Dictionary,system: int,t: float,rows: Dictionary={}) -> Array:
	var result: Array=[]
	for row in all(m,system,t):
		result.append({"id":row.id,"field":"receiver","point":FrontierCrewWorld.vector(row.receiver),"radius":150.0 if maintenance(row.id) else 85.0})
		if maintenance(row.id) or int(rows.get(row.id,{}).get("stage",0))<2:result.append({"id":row.id,"field":"position","point":FrontierCrewWorld.vector(row.position),"radius":50.0})
	return result
static func reassign(world: Dictionary,previous: String,current: String) -> void:
	# The public FINCH changes its fleet key on borrowing; its attached pod stays aboard.
	for row in records(world).values():
		if int(row.stage)==2 and row.carrier=="shuttle:"+previous:row.carrier="shuttle:"+current
