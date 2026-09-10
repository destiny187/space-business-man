class_name FrontierFreightSalvageSurvey
extends RefCounted
## No client completion command: held input, current vessel, capacity and save govern transfer.
static func step(authority: FrontierCrewAuthority,peer: int,local: Dictionary,delta: float) -> bool:
	var actor: String=authority.peers[peer];var vessel:=FrontierFreightSalvage.carrier(local)
	var rows:=FrontierFreightSalvage.records(authority.world)
	var target:=FrontierFreightSalvage.target(local.manifest,local.crew.navigation,authority.inputs[peer].aim,rows,vessel)
	if target.is_empty():return false
	var stage:=int(target.stage)
	var reason:=FrontierFreightSalvage.reason(local.manifest,local.crew.navigation,target,rows,vessel,local.crew.pilot_id==actor)
	if stage>0 and absf(float(authority.inputs[peer].get("flight_controls",[0,0,0])[0]))>0:reason="추진 입력을 놓고 회수 장치를 운용하세요"
	var scan: Dictionary={"kind":"freight","id":target.id,"stage":stage,"carrier":vessel,"progress":0.0,"reason":reason}
	if not reason.is_empty():authority.scans[peer]=scan;return true
	if stage>0 or FrontierFreightSalvage.maintenance(target.id):
		local.crew.navigation.freight_anchor_source=stage==1 and FrontierFreightSalvage.maintenance(target.id)
		local.crew.navigation.freight_anchor=target.id;local.crew.navigation.speed=0;local.crew.navigation.erase("station_docked")
	var previous: Dictionary=authority.scans.get(peer,{})
	var progress: float=float(previous.get("progress",0)) if previous.get("kind","")=="freight" and previous.get("id","")==target.id and int(previous.get("stage",-1))==stage and previous.get("carrier","")==vessel else 0.0
	progress+=delta/FrontierFreightSalvage.seconds(local.manifest,target.id,stage)
	scan.progress=minf(.99,progress);authority.scans[peer]=scan
	if progress<1:return true
	var draft: Dictionary=authority.world.duplicate(true)
	if not draft.crew.has("freight_records"):draft.crew.freight_records={}
	draft.crew.freight_records.erase(target.id)
	draft.crew.freight_records[target.id]={"stage":stage+1,"carrier":"" if stage==0 else vessel,"at":float(local.crew.navigation.orbit_time)}
	if stage+1==FrontierFreightSalvage.last_stage(target.id):
		if not draft.has("business"):draft.business=FrontierExpeditionBusiness.create()
		draft.business.credits+=int(target.payment)
	draft.crew.revision+=1
	if not authority.save_world.call(draft):
		authority.scans.erase(peer);authority.stopped=true;authority.error="화물 인계 저장 실패로 공동 세계를 정지했습니다.";return true
	authority.world=draft;scan.stage=stage+1;scan.progress=0.0;scan.known=stage+1==FrontierFreightSalvage.last_stage(target.id);authority.scans[peer]=scan
	return true
static func activity(scans: Dictionary) -> Array:
	var result: Array=[]
	for scan in scans.values():
		if scan.get("kind","")=="freight" and float(scan.get("progress",0))>0:result.append(scan.duplicate())
	return result
static func vessels(world: Dictionary) -> Array:
	var result: Array=[]
	for observer in FrontierSpaceTraffic.observers(world):
		var nav: Dictionary=world.crew.navigation if observer.id=="crew" else world.crew.shuttles[str(observer.id).trim_prefix("shuttle:")].navigation
		observer.direction=nav.direction.duplicate();result.append(observer)
	return result
