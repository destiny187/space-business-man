class_name FrontierCrewAuthority
extends RefCounted
## Host-only admission, immutable profile references and durable transactions.
# Host scene resolves a live device descriptor (area/body/position/enabled); no RPC setter.
var augmentation_station_provider: Callable
var research_station_provider: Callable
var world: Dictionary={}
var phase: String="lobby"
var lobby_ready: Dictionary={}
var peers: Dictionary={}
var pending: Dictionary={}
var reserved: Dictionary={}
var inputs: Dictionary={}
var input_sequences: Dictionary={}
var motions: Dictionary={}
var session_id: String
var save_world: Callable
var stopped:=false
var error:=""
var now:=0.0
var scans: Dictionary={}
var last_dig: Dictionary={}
var scan_timer:=0.0
var ecology_timer:=0.0
var industry_timer:=0.0
var last_mine: Dictionary={}
var rover_spawn_validator: Callable
var rover_runtime: Dictionary={"seats":{},"exits":{},"tasks":{},"status":{}}
func start(source: Dictionary,profile: Dictionary,persist: Callable) -> bool:
	FrontierCrewSurface.reset_cache()
	error=FrontierPlayerProfile.validate_character(profile)
	if not error.is_empty():return false
	error=FrontierExpeditionResearch.validate(source)
	if not error.is_empty():return false
	world=source.duplicate(true);save_world=persist
	rover_runtime={"seats":{},"exits":{},"tasks":{},"status":{}}
	FrontierRovers.brake_all(world)
	for site in world.get("business",{}).get("sites",{}).values():
		for robot in site.robots.values():FrontierRobotWork.ensure(robot)
	for robot in world.get("business",{}).get("hangar",{}).values():FrontierRobotWork.ensure(robot)
	if not world.has("crew"):world.crew=FrontierCrewWorld.create(profile)
	if not world.crew.has("navigation"):world.crew.navigation=FrontierCrewNavigation.create(world)
	if world.crew.owner_id!=profile.character_id:error="이 세계를 만든 호스트의 개인 프로필이 필요합니다.";return false
	error=FrontierCrewWorld.validate(world.crew)
	if not error.is_empty():return false
	FrontierExpeditionResearch.ensure(world)
	for id in world.crew.members:
		FrontierCrewAugmentation.ensure(world.crew.members[id])
		FrontierExpeditionBusiness.release_carrier(world,id);FrontierCrewWorld.disconnect_member(world.crew,id);FrontierShuttles.resume(world,id)
	FrontierCrewSurface.spawn_member(world,world.crew.members[profile.character_id],0)
	world.crew.pilot_id=world.crew.owner_id
	world.crew.members[profile.character_id].profile=profile.duplicate(true)
	if not save_world.call(world):error="호스트 세계를 저장할 수 없습니다.";return false
	session_id=FrontierPlayerProfile.token();peers={1:profile.character_id};pending.clear();reserved.clear();stopped=false
	return true
func advance_time(time_seconds: float) -> Array[int]:
	now=time_seconds
	var expired: Array[int]=[]
	for peer in pending.keys():
		if pending[peer].expires<=now:_drop_pending(peer);expired.append(peer)
	for id in reserved.keys():
		if reserved[id]<=now:reserved.erase(id)
	return expired
func _drop_pending(peer: int) -> void:
	if not pending.has(peer):return
	var entry: Dictionary=pending[peer]
	if float(entry.reserved_until)>now:reserved[entry.profile.character_id]=entry.reserved_until
	pending.erase(peer)
func slots() -> int:return peers.size()+pending.size()+reserved.size()
func admit(peer: int,profile: Variant,capability: String,protocol: int,content: String) -> Dictionary:
	if stopped or peer<=1:return failure("세션이 닫혔습니다.")
	if peers.has(peer) or pending.has(peer):return failure("이미 참가 처리 중입니다.")
	if protocol!=int(FrontierCrewWorld.config().protocol) or content!=FrontierCrewWorld.content_hash():return failure("게임/생성/장비 버전이 호스트와 다릅니다.")
	var reason:=FrontierPlayerProfile.validate_character(profile)
	if not reason.is_empty():return failure(reason)
	var id: String=profile.character_id
	if id==world.crew.owner_id or id in peers.values():return failure("같은 캐릭터가 이미 접속해 있습니다.")
	for entry in pending.values():
		if entry.profile.character_id==id:return failure("같은 캐릭터가 참가 처리 중입니다.")
	var known: bool=world.crew.members.has(id)
	if known and (not FrontierPlayerProfile.identifier(capability,64) or capability.sha256_text()!=world.crew.members[id].capability_hash):return failure("이 캐릭터의 재접속 자격을 확인할 수 없습니다.")
	var reclaiming: bool=reserved.has(id)
	if slots()-(1 if reclaiming else 0)>=int(FrontierCrewWorld.config().maximum_players):return failure("호스트 포함 최대 6명입니다.")
	var token: String=capability if known else FrontierPlayerProfile.token(32)
	var reserved_until: float=float(reserved.get(id,0))
	if reclaiming:reserved.erase(id)
	pending[peer]={"profile":profile.duplicate(true),"token":token,"known":known,"reserved_until":reserved_until,"expires":now+float(FrontierCrewWorld.config().handshake_seconds)}
	return {"ok":true,"world_id":world.crew.world_id,"token":token,"session_id":session_id,"snapshot":snapshot(peer)}
func acknowledge(peer: int,received_session: String) -> Dictionary:
	if stopped or received_session!=session_id or not pending.has(peer):return failure("유효한 참가 준비 응답이 아닙니다.")
	var entry: Dictionary=pending[peer]
	var draft:=world.duplicate(true)
	var id: String=entry.profile.character_id
	if not draft.crew.members.has(id):draft.crew.members[id]=FrontierCrewWorld.member(entry.profile,entry.token.sha256_text(),peers.size())
	else:
		# Equipment stays a reference to the owner's profile. World cargo never
		# gets written into the owner's equipment list.
		draft.crew.members[id].profile=entry.profile.duplicate(true)
	FrontierCrewSurface.spawn_member(draft,draft.crew.members[id],peers.size())
	draft.crew.members[id].erase("shuttle_recalled")
	draft.crew.revision+=1
	if not save_world.call(draft):return failure("참가 상태 저장에 실패했습니다.")
	world=draft;peers[peer]=id;pending.erase(peer)
	return {"ok":true,"snapshot":snapshot(peer)}
func snapshot(viewer: int=1) -> Dictionary:
	var data: Dictionary=world.crew.duplicate(true)
	var visible: Dictionary=peers.duplicate()
	if pending.has(viewer):
		var entry: Dictionary=pending[viewer];var id: String=entry.profile.character_id
		if not data.members.has(id):data.members[id]=FrontierCrewWorld.member(entry.profile,"",peers.size())
		visible[viewer]=id
	for id in data.members.keys():
		if id not in visible.values() and not data.get("shuttles",{}).has(id):data.members.erase(id)
	var actor:=str(visible.get(viewer,""))
	var local:=FrontierShuttles.context(world,actor)
	for id in data.members:
		data.members[id]["place_key"]=FrontierShuttles.area_key(world,id) if world.crew.members.has(id) else "cabin"
	if local.has("local_shuttle"):
		for key in ["navigation","landing","cargo","cargo_equipment","rock","pilot_id","cargo_slots"]:data[key]=local.crew[key]
	var target_id:=FrontierUniverse.body_id(world.manifest,int(local.crew.navigation.target))
	var site: Dictionary=world.get("business",{}).get("sites",{}).get(target_id,{})
	var vessel_stats:=FrontierVesselRefit.stats(local)
	if local.has("local_shuttle"):vessel_stats.stellar_range=0.0
	return {"expedition_research":world.expedition_research.duplicate(true),"main_location":world.location,"main_landing":world.crew.get("landing",{}).duplicate(),"local_shuttle":actor if local.has("local_shuttle") else "","rovers":FrontierRovers.fleet(world).duplicate(true),"rover_runtime":rover_runtime.duplicate(true),"station":{} if local.has("local_shuttle") else FrontierSpaceStation.snapshot(world),"inventory":FrontierExpeditionBusiness.bag(world,str(visible.get(viewer,""))).duplicate(true),"motion":motions.duplicate(true),"motion_time":now,"supply_sites":FrontierPlanetSupply.summaries(world),"navigation_site":{"state":site.get("state","")},"phase":phase,"lobby_ready":lobby_ready.duplicate(),"vessel_seed":int(world.manifest.seed),"vessel":world.get("vessel",{}).duplicate(true),"vessel_stats":vessel_stats,"session_id":session_id,"crew":FrontierCrewWorld.public_snapshot(data,peers),"self_id":visible.get(viewer,""),"active":peers.has(viewer),"galaxy_id":world.manifest.id,"location":local.location,"scan":scans.get(viewer,{"progress":0.0}).duplicate(true)}
func request(peer: int,envelope: Variant) -> Dictionary:
	if stopped or not peers.has(peer):return failure("참가 동기화가 끝나지 않았습니다.")
	if not envelope is Dictionary or envelope.get("session_id")!=session_id:return failure("지난 세션의 요청입니다.")
	if not envelope.get("kind") is String or not envelope.get("args") is Dictionary:return failure("요청 형식 오류")
	if JSON.stringify(envelope).length()>int(FrontierCrewWorld.config().maximum_message_bytes):return failure("요청 크기 초과")
	if not FrontierUniverse._finite(envelope.get("sequence"),1,9007199254740000) or envelope.sequence!=floorf(envelope.sequence):return failure("요청 순번 오류")
	var actor: String=peers[peer]
	if envelope.kind=="lobby_ready":
		if phase!="lobby" or not envelope.args.get("value") is bool:return failure("대기실 준비 상태 오류")
		lobby_ready[actor]=envelope.args.value
		return {"ok":true,"sequence":envelope.sequence}
	if envelope.kind=="start_game":
		if phase!="lobby" or peer!=1:return failure("대기실에서 호스트만 게임을 시작할 수 있습니다.")
		if not pending.is_empty():return failure("참가자 동기화가 끝날 때까지 기다려 주세요.")
		for id in peers.values():
			if id!=world.crew.owner_id and not lobby_ready.get(id,false):return failure("모든 참가자의 준비 완료가 필요합니다.")
		if not save_world.call(world):return failure("세계 저장에 실패해 시작하지 않았습니다.")
		phase="playing";lobby_ready.clear()
		return {"ok":true,"sequence":envelope.sequence}
	if phase!="playing":return failure("호스트가 게임을 시작한 뒤 사용할 수 있습니다.")
	var sequence:=int(envelope.sequence)
	var key: String=actor+":"+str(sequence)
	var digest:=JSON.stringify({"kind":envelope.kind,"args":envelope.args,"revision":envelope.get("revision")},"",true).sha256_text()
	if world.crew.receipts.has(key):
		var receipt: Dictionary=world.crew.receipts[key]
		return receipt.result.duplicate(true) if receipt.digest==digest else failure("같은 요청 번호의 내용이 달라졌습니다.")
	if sequence<=int(world.crew.members[actor].last_sequence):return failure("이미 확정된 오래된 요청입니다.")
	if (envelope.kind in ["withdraw","deposit","recover","pilot","navigate","depart","tutorial_depart","land","launch","augmentation_upgrade","research_contribute"] or envelope.kind.begins_with("surface_") or envelope.kind.begins_with("business_") or envelope.kind.begins_with("station_") or envelope.kind.begins_with("vessel_") or envelope.kind.begins_with("equipment_") or envelope.kind.begins_with("rover_") or envelope.kind.begins_with("shuttle_")) and envelope.get("revision")!=world.crew.revision:return failure("세계 상태가 바뀌었습니다. 최신 상태에서 다시 요청하세요.")
	if envelope.kind=="shuttle_recall":
		var target: String=str(envelope.args.get("character_id",""))
		if peer!=1:return failure("호스트만 이탈 승무원을 회수할 수 있습니다.")
		if target in peers.values():return failure("접속 중인 승무원은 회수할 수 없습니다.")
		for entry in pending.values():
			if entry.profile.character_id==target:return failure("승무원이 재접속 중입니다. 동기화를 기다려 주세요.")
	var restriction:=FrontierShuttles.guard(world,actor,envelope.kind,envelope.args)
	if not restriction.is_empty():return failure(restriction)
	var canonical:=world.duplicate(true)
	var draft:=canonical if envelope.kind.begins_with("shuttle_") else FrontierShuttles.context(canonical,actor)
	var group:=FrontierShuttles.peer_group(world,actor,peers)
	var rover_draft:=rover_runtime.duplicate(true)
	if not FrontierRovers.seated(rover_runtime,actor).is_empty() and envelope.kind not in ["rover_exit","rover_switch"]:return failure("먼저 로버에서 내리세요.")
	if envelope.kind.begins_with("rover_") or envelope.kind.begins_with("station_") or envelope.kind.begins_with("equipment_") or envelope.kind.begins_with("business_") or envelope.kind in ["surface_dig","withdraw","deposit"]:FrontierItemInventory.merge_legacy(draft,actor)
	if FrontierCrewSurface.landed(draft) and draft.crew.members[actor].aboard and envelope.kind not in ["surface_unboard","surface_board","launch","ready","shuttle_recall"]:return failure("착륙선에서 내린 뒤 실행하세요.")
	var facility_id:=str(envelope.args.get("building_id",envelope.args.get("facility_id","")))
	if not envelope.kind.begins_with("rover_") and (FrontierRovers.factory_busy(draft,facility_id) or (envelope.kind=="business_settle" and FrontierRovers.fleet(draft).jobs.values().any(func(job: Dictionary):return job.body_id==draft.location))):return failure("로버 조립이 끝난 뒤 실행하세요.")
	var reason: String=""
	if envelope.kind=="augmentation_upgrade":
		var station: Dictionary={}
		if augmentation_station_provider.is_valid():
			var offered: Variant=augmentation_station_provider.call(actor,str(envelope.args.get("station_id","")))
			if offered is Dictionary:station=offered
		reason=FrontierCrewAugmentation.apply(draft,actor,envelope.args,station)
	elif envelope.kind=="research_contribute":
		var station: Dictionary={}
		if research_station_provider.is_valid():
			var offered: Variant=research_station_provider.call(actor,str(envelope.args.get("station_id","")))
			if offered is Dictionary:station=offered
		reason=FrontierExpeditionResearch.contribute(draft,actor,envelope.args,station)
	elif envelope.kind.begins_with("shuttle_"):reason=FrontierShuttles.apply(draft,actor,envelope.kind,envelope.args)
	elif envelope.kind.begins_with("rover_"):reason=FrontierRovers.apply(draft,actor,envelope.kind,envelope.args,rover_draft)
	elif envelope.kind in ["withdraw","deposit"]:reason=FrontierItemInventory.ship_transfer(draft,actor,envelope.kind,envelope.args)
	elif envelope.kind.begins_with("equipment_"):reason=FrontierEquipment.apply(draft,actor,envelope.kind,envelope.args)
	elif envelope.kind.begins_with("station_"):reason=FrontierSpaceStation.apply(draft,actor,envelope.kind,envelope.args,group)
	elif envelope.kind.begins_with("vessel_"):reason=FrontierVesselRefit.apply(draft,actor,envelope.kind,envelope.args)
	elif envelope.kind.begins_with("business_"):
		if envelope.kind=="business_mine":
			var remaining:=float(last_mine.get(actor,-100))+float(FrontierEquipment.active(world.crew.members[actor]).get("interval",.6))-now
			if remaining>0:
				var waiting:=failure("채광 도구가 준비 중입니다.");waiting.code="mining_cooldown";waiting.retry_after=remaining;return waiting
		reason=FrontierExpeditionBusiness.apply(draft,actor,envelope.kind,envelope.args,group)
	elif envelope.kind in ["navigate","depart","tutorial_depart"]:reason=FrontierCrewNavigation.apply(draft,actor,envelope.kind,envelope.args,group)
	elif envelope.kind in ["land","launch"] or envelope.kind.begins_with("surface_") or (envelope.kind in ["withdraw","deposit"] and FrontierCrewSurface.landed(draft)):
		if envelope.kind=="surface_scan":return failure("스캔은 장비 입력을 유지해 완료하세요.")
		if envelope.kind in ["surface_dig","surface_attack"] and now<float(last_dig.get(actor,-100))+float(FrontierEquipment.active(world.crew.members[actor]).get("interval",.45)):return failure("굴착 도구가 준비 중입니다.")
		reason=FrontierCrewSurface.apply(draft,actor,envelope.kind,envelope.args,group)
	else:reason=FrontierCrewWorld.apply(draft.crew,actor,envelope.kind,envelope.args,group)
	if not reason.is_empty():return failure(reason)
	FrontierShuttles.commit(canonical,draft,actor);draft=canonical
	draft.crew.revision+=1;draft.crew.members[actor].last_sequence=sequence
	var result: Dictionary={"ok":true,"sequence":sequence,"revision":draft.crew.revision}
	if envelope.kind=="augmentation_upgrade":result.augmentation=FrontierCrewAugmentation.outcome(draft.crew.members[actor],envelope.args.field)
	if envelope.kind=="research_contribute":result.research={"project":envelope.args.project,"stage":draft.expedition_research.projects[envelope.args.project].stage,"contributed":{envelope.args.resource:int(envelope.args.amount)}}
	if envelope.kind=="equipment_research_prototype":result.research={"project":"deep_mining","stage":"prototyped","item_id":"crafted:"+str(int(draft.crew.members[actor].loadout.counter))}
	var gains: Dictionary={}
	var old_bag:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	old_bag.stone=int(old_bag.get("stone",0))+int(world.crew.members[actor].carried)
	var new_bag:=FrontierExpeditionBusiness.bag(draft,actor).duplicate()
	new_bag.stone=int(new_bag.get("stone",0))+int(draft.crew.members[actor].carried)
	for resource in new_bag:
		var amount: int=int(new_bag[resource])-int(old_bag.get(resource,0))
		if amount>0:gains[resource]=amount
	if envelope.kind=="surface_collect":
		for sample_id in draft.ecology.specimens:
			if not world.ecology.specimens.has(sample_id):
				var form:=FrontierEcologyCatalog.form(draft.ecology.specimens[sample_id].form_id)
				gains[FrontierResourceIcons.specimen_id(form)]=1
	result["gains"]=gains
	draft.crew.receipts[key]={"digest":digest,"result":result.duplicate()}
	if draft.crew.receipts.size()>128:
		var oldest: String="";var revision:=INF
		for id in draft.crew.receipts:
			if float(draft.crew.receipts[id].result.revision)<revision:revision=float(draft.crew.receipts[id].result.revision);oldest=id
		draft.crew.receipts.erase(oldest)
	if not save_world.call(draft):return failure("저장에 실패했습니다. 변경은 확정되지 않았습니다.")
	world=draft;rover_runtime=rover_draft
	if envelope.kind=="shuttle_recall":motions.erase(str(envelope.args.character_id))
	if envelope.kind in ["surface_dig","surface_attack"]:last_dig[actor]=now
	if envelope.kind=="business_mine":last_mine[actor]=now
	return result
func input(peer: int,sequence: int,direction: Variant,aim_value: Variant=[],scanning: bool=false,sprinting: bool=false,flight_controls: Array=[0.0,0.0,0.0],jump_request: int=0,controls_enabled: bool=true,vehicle_controls: Array=[]) -> bool:
	if phase!="playing" or stopped or not peers.has(peer) or sequence<=int(input_sequences.get(peer,0)) or not direction is Array or direction.size()!=2:return false
	for axis in direction:
		if not FrontierUniverse._finite(axis,-1,1):return false
	if jump_request<0 or jump_request>9007199254740000:return false
	if flight_controls.size() not in [3,4]:return false
	for axis in flight_controls:
		if not FrontierUniverse._finite(axis,-1,1):return false
	if vehicle_controls.size() not in [0,4]:return false
	for axis in vehicle_controls:
		if not FrontierUniverse._finite(axis,-1,1):return false
	var seat:=FrontierRovers.seated(rover_runtime,str(peers[peer]))
	if not seat.is_empty() and int(seat.seat)==0:scanning=false
	var aim: Vector3=Vector3.FORWARD if aim_value is Array and aim_value.is_empty() else FrontierCrewSurface.direction(aim_value)
	if aim==Vector3.ZERO:return false
	input_sequences[peer]=sequence;inputs[peer]={"direction":Vector2(direction[0],direction[1]).limit_length(),"expires":now+float(FrontierCrewSurface.config().scan_input_expiry),"aim":aim,"scanning":scanning,"sprinting":sprinting,"flight_controls":flight_controls.duplicate(),"jump_request":jump_request,"controls_enabled":controls_enabled,"vehicle_controls":vehicle_controls.duplicate()}
	return true
func direction_for(peer: int) -> Vector2:
	if not inputs.has(peer) or inputs[peer].expires<now:return Vector2.ZERO
	return inputs[peer].direction
func update_position(peer: int,position: Vector3) -> void:
	# Called exclusively by host-side collision simulation, never an RPC.
	if not peers.has(peer) or not position.is_finite():return
	var id: String=peers[peer]
	world.crew.members[id].position=[position.x,position.y,position.z]
func disconnect_member(peer: int,reserve_slot: bool=true) -> bool:
	if peers.has(peer):motions.erase(peers[peer])
	_drop_pending(peer);inputs.erase(peer);input_sequences.erase(peer);scans.erase(peer)
	if not peers.has(peer):return true
	var id: String=peers[peer]
	var draft:=world.duplicate(true)
	var rover_draft:=rover_runtime.duplicate(true)
	FrontierRovers.release(draft,rover_draft,id)
	FrontierExpeditionBusiness.release_carrier(draft,id);FrontierCrewWorld.disconnect_member(draft.crew,id);FrontierShuttles.resume(draft,id);draft.crew.revision+=1
	var remaining:=peers.duplicate();remaining.erase(peer)
	if not FrontierShuttles.fleet(draft).values().any(func(ship: Dictionary):return ship.state=="sortie"):FrontierCrewSurface.launch_if_boarded(draft,remaining)
	if not save_world.call(draft):stopped=true;error="연결 종료 상태를 저장하지 못해 세계 진행을 정지했습니다.";return false
	world=draft;rover_runtime=rover_draft;peers.erase(peer);lobby_ready.erase(id)
	if reserve_slot and peer!=1:reserved[id]=now+float(FrontierCrewWorld.config().reconnect_seconds)
	return true
func close() -> bool:
	stopped=true
	var draft:=world.duplicate(true)
	FrontierRovers.brake_all(draft)
	for id in peers.values():
		FrontierExpeditionBusiness.release_carrier(draft,id);FrontierCrewWorld.disconnect_member(draft.crew,id)
	draft.crew.revision+=1
	if not save_world.call(draft):error="마지막 호스트 저장에 실패했습니다.";return false
	world=draft;peers.clear();pending.clear();inputs.clear();return true
func failure(message: String) -> Dictionary:return {"ok":false,"error":message,"revision":world.get("crew",{}).get("revision",0)}

func checkpoint() -> bool:
	if stopped:return false
	if not save_world.call(world):stopped=true;error="항해 상태 저장 실패로 세계를 정지했습니다.";return false
	return true

func step_surface(delta: float) -> void:
	if stopped:return
	industry_timer+=delta
	if industry_timer>=1.0:
		industry_timer-=1.0
		var draft:=world.duplicate(true)
		var operated:=false
		for body_id in draft.get("business",{}).get("sites",{}):
			if not FrontierPlanetSupply.operating(draft.business.sites[body_id]):continue
			var local:=FrontierPlanetSupply.context(draft,body_id)
			FrontierExpeditionIndustry.tick(local,1.0)
			# Vehicle assembly uses a visible collision-space validator and resumes on return.
			if FrontierCrewSurface.landed(draft) and body_id==draft.location:FrontierRovers.manufacture(draft,1.0,rover_spawn_validator)
			operated=true
		FrontierShuttles.manufacture(draft,1.0)
		if operated:
			if not save_world.call(draft):stopped=true;error="사업 생산 저장 실패로 세계를 정지했습니다.";return
			world=draft
	ecology_timer+=delta
	if ecology_timer>=1.0:
		ecology_timer=0.0
		var bodies: Dictionary={}
		for id in peers.values():
			var local:=FrontierShuttles.context(world,id)
			if FrontierCrewSurface.landed(local):bodies[local.location]=true
		for id in bodies:FrontierEcology.advance(world.ecology,id,1.0)
	scan_timer+=delta
	if scan_timer<.1:return
	var duration: float=minf(scan_timer,.15);scan_timer=0
	for peer in peers:
		if not inputs.has(peer) or inputs[peer].expires<now or not inputs[peer].scanning:scans.erase(peer);continue
		var actor: String=peers[peer]
		var local:=FrontierShuttles.context(world,actor)
		if not FrontierCrewSurface.landed(local) or world.crew.members[actor].aboard:scans.erase(peer);continue
		var target:=FrontierSurfaceSurvey.target(local,actor,inputs[peer].aim)
		if target.is_empty():scans.erase(peer);continue
		if FrontierSurfaceSurvey.known(world,target):
			scans[peer]={"id":target.id,"progress":1.0,"known":true,"info":FrontierSurfaceSurvey.result(world,target,actor)};continue
		var progress: float=float(scans.get(peer,{}).get("progress",0)) if scans.get(peer,{}).get("id","")==target.id else 0.0
		progress=minf(1.0,progress+duration/float(FrontierCrewSurface.config().scan_seconds))
		scans[peer]={"id":target.id,"progress":progress,"known":false,"point":[target.point.x,target.point.y,target.point.z]}
		if progress<1.0:continue
		var draft:=world.duplicate(true)
		var survey_local:=FrontierShuttles.context(draft,actor)
		FrontierSurfaceSurvey.record(survey_local,target,actor);FrontierShuttles.commit(draft,survey_local,actor)
		draft.crew.revision+=1
		if not save_world.call(draft):stopped=true;error="스캔 저장 실패로 공동 세계를 정지했습니다.";return
		world=draft
		scans[peer]={"id":target.id,"progress":1.0,"known":true,"info":FrontierSurfaceSurvey.result(world,target,actor)}
