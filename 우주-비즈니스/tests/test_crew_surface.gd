extends SceneTree
var checks:=0
var failures:=0
var disk_ok:=true
var saved: Dictionary={}
var sequences: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+label)
func persist(world: Dictionary) -> bool:
	if not disk_ok:return false
	var error:=FrontierUniverse.validate_world(world)
	if not error.is_empty():printerr("FAIL: SAVE_VALIDATION ",error);return false
	saved=JSON.parse_string(JSON.stringify(world));return true
func envelope(core: FrontierCrewAuthority,peer: int,kind: String,args: Dictionary={}) -> Dictionary:
	sequences[peer]=int(sequences.get(peer,0))+1
	return {"session_id":core.session_id,"sequence":sequences[peer],"kind":kind,"args":args,"revision":core.world.crew.revision}
func request(core: FrontierCrewAuthority,peer: int,kind: String,args: Dictionary={}) -> Dictionary:return core.request(peer,envelope(core,peer,kind,args))
func ready_all(core: FrontierCrewAuthority) -> void:
	for peer in core.peers:request(core,peer,"ready",{"value":true})
func navigate(core: FrontierCrewAuthority,ordinal: int) -> void:
	request(core,1,"navigate",{"ordinal":ordinal});ready_all(core);request(core,1,"depart")
	for i in 3000:
		FrontierCrewNavigation.step(core.world,.05)
		if core.world.crew.navigation.mode=="idle":break
func find_sample(core: FrontierCrewAuthority,peer: int) -> Dictionary:
	var id: String=core.world.crew.landing.body_id
	var body:=FrontierUniverse.body_from_id(core.world.manifest,id)
	var terrain:=FrontierCrewSurface.field(core.world)
	for candidate in FrontierEcologyPlacement.candidates(body,core.world.ecology.planets[id],Vector3.ZERO):
		if candidate.layer!="surface":continue
		var point:=FrontierEcologyPlacement.ground(terrain,candidate)
		if not point.is_finite():continue
		var form:=FrontierEcologyCatalog.form(candidate.form_id)
		var height: float=(form.geometry.near.max[1]-form.geometry.near.floor_y)*FrontierEcologyCatalog.look(form.id,candidate.look_id).scale
		for angle in 8:
			var position:=point+Vector3(sin(angle*TAU/8)*2.2,0,cos(angle*TAU/8)*2.2)
			position.y=terrain.height(position.x,position.z)
			core.update_position(peer,position)
			var aim: Vector3=(point+terrain.normal(point)*maxf(.35,height*.5)-position-Vector3.UP*1.72).normalized()
			var target:=FrontierCrewSurface.target(core.world,core.peers[peer],aim)
			if target.get("id")==candidate.id:target.aim=aim;target.observer=position;return target
	return {}
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("지표 호스트",0)
	var original:=owner.duplicate(true)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"open compatible host world")
	var guest:=FrontierPlayerProfile.new_character("현장 연구원",1)
	check(not core.admit(2,guest,"",1,FrontierCrewWorld.content_hash()).ok,"old protocol cannot join shared terrain session")
	var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok,"guest joins with persistent personal equipment")
	check(not request(core,1,"surface_dig",{"aim":[0,-1,0]}).ok,"surface command before landing is safely rejected")
	check(not request(core,1,"land").ok,"landing requires actual orbital approach")
	navigate(core,15)
	check(core.world.location==FrontierUniverse.body_id(core.world.manifest,15),"shared ship arrives at chosen seeded planet")
	check(not request(core,1,"land").ok,"landing requires fresh crew readiness after arrival")
	ready_all(core)
	check(not request(core,2,"land").ok,"guest cannot take pilot landing authority")
	check(request(core,1,"land").ok,"prepared crew land as one authoritative world transition")
	check(core.world.crew.members[owner.character_id].area=="surface" and not core.world.crew.members[guest.character_id].aboard,"crew spawn on same actual planet")
	check(not request(core,1,"depart").ok,"cannot depart in orbit while crew are on surface")
	var before: int=core.world.crew.members[owner.character_id].carried
	var dig:=envelope(core,1,"surface_dig",{"aim":[0,-1,0]})
	check(core.request(1,dig).ok,"host traces actual solid terrain and records excavation")
	var id: String=core.world.crew.landing.body_id
	check(core.world.terrain_edits[id].size()==1 and core.world.crew.members[owner.character_id].carried==before+1,"one terrain edit produces exactly one carried unit")
	check(core.request(1,dig).ok and core.world.terrain_edits[id].size()==1,"replayed excavation has no duplicate terrain or cargo")
	check(not request(core,1,"surface_dig",{"aim":[0,-1,0]}).ok,"server enforces tool cooldown")
	var sample:=find_sample(core,2)
	check(not sample.is_empty(),"server finds a seeded specimen using ground and line-of-sight checks")
	if sample.is_empty():quit(1);return
	check(not request(core,2,"surface_scan").ok,"instant scan command cannot bypass host scan timer")
	var input_sequence:=0
	for i in 5:
		core.advance_time(float(i)*.1);input_sequence+=1;core.input(2,input_sequence,[0,0],[sample.aim.x,sample.aim.y,sample.aim.z],true);core.step_surface(.1)
	check(core.world.ecology.observations.is_empty(),"partial scan creates no research knowledge")
	core.input(2,input_sequence+1,[0,0],[sample.aim.x,sample.aim.y,sample.aim.z],false);input_sequence+=1;core.step_surface(.1)
	check(not core.scans.has(2),"releasing scanner resets incomplete progress")
	for i in 20:
		core.advance_time(1+float(i)*.1);input_sequence+=1;core.input(2,input_sequence,[0,0],[sample.aim.x,sample.aim.y,sample.aim.z],true);core.step_surface(.1)
	check(core.world.ecology.observations.size()==1,"host-confirmed sustained scan is shared and persisted")
	core.update_position(1,sample.observer)
	var args: Dictionary={"encounter_id":sample.id,"aim":[sample.aim.x,sample.aim.y,sample.aim.z]}
	var first:=envelope(core,2,"surface_collect",args)
	var second:=envelope(core,1,"surface_collect",args)
	check(core.request(2,first).ok and not core.request(1,second).ok,"two-player race collects only one physical specimen")
	check(core.world.ecology.specimens.size()==1,"shared cargo has exactly one globally identified specimen")
	var specimen_id: String=core.world.ecology.specimens.keys()[0]
	var packet:=FrontierCrewSurfaceReplica.packet(core.world,guest.character_id)
	check(FrontierCrewSurfaceReplica.validate(packet,core.world.manifest),"current-interest replica validates without full world history")
	var encoded:=FrontierCrewSurfaceReplica.encode(packet)
	check(not FrontierCrewSurfaceReplica.decode(encoded,core.world.manifest).is_empty(),"compressed reliable snapshot preserves terrain and ecology")
	check(encoded.size()<int(FrontierCrewSurface.config().maximum_compressed_bytes),"surface transfer fits bounded payload")
	var invalid:=packet.duplicate(true);invalid.ecology.planets[id].profile.temperature=999
	check(not FrontierCrewSurfaceReplica.validate(invalid,core.world.manifest),"replica rejects changed native climate")
	invalid=packet.duplicate(true);invalid.edits[0].center=[INF,0,0]
	check(not FrontierCrewSurfaceReplica.validate(invalid,core.world.manifest),"replica rejects malformed terrain")
	core.update_position(1,Vector3(0,2,0));core.update_position(2,Vector3(0,2,4))
	disk_ok=false;var original_world:=FrontierUniverse.fingerprint(core.world)
	check(not request(core,1,"surface_analyze",{"form_id":sample.form_id}).ok and FrontierUniverse.fingerprint(core.world)==original_world,"failed shared research save preserves materials and knowledge")
	disk_ok=true
	check(request(core,1,"surface_analyze",{"form_id":sample.form_id}).ok,"crew can analyze another member's shared observation")
	check(core.disconnect_member(1,false),"surface disconnection stores carried ore at actual location")
	check(core.world.crew.recovery.values()[0].body_id==id,"dropped cargo retains its planet identity")
	# The real host stays peer 1 in play; restore this unit-test actor to inspect departure gates.
	core.peers[1]=owner.character_id
	core.update_position(2,Vector3(90,-20,0));ready_all(core)
	check(request(core,1,"surface_board").ok and FrontierCrewSurface.landed(core.world),"boarded host waits without stranding remote crew")
	core.update_position(2,Vector3(0,2,4));ready_all(core)
	check(request(core,2,"surface_board").ok and not FrontierCrewSurface.landed(core.world),"last returned crew boards and launches automatically")
	check(core.world.ecology.specimens[specimen_id].state=="cargo","unique specimen remains aboard during launch")
	navigate(core,21);ready_all(core);check(request(core,1,"land").ok,"same crew can land on destination planet B")
	var other_id: String=core.world.crew.landing.body_id
	var crate: String=core.world.crew.recovery.keys()[0]
	check(not request(core,1,"recover",{"crate_id":crate}).ok,"planet A cargo cannot be recovered at same coordinates on B")
	check(request(core,1,"surface_restore",{"environment":"basalt"}).ok,"shared research unlocks compatible destination plot")
	check(request(core,1,"surface_introduce",{"sample_id":specimen_id,"aim":[0,0,-1]}).ok,"shared specimen transfers from cargo to destination habitat")
	check(core.world.ecology.specimens[specimen_id].destination==other_id and core.world.ecology.specimens[specimen_id].state=="introduced","cross-planet specimen has one destination")
	check(FrontierUniverse.validate_world(core.world).is_empty() and owner==original,"shared world validates while original equipment remains unchanged")
	var malformed:=core.world.duplicate(true);malformed.ecology="invalid"
	check(not FrontierUniverse.validate_world(malformed).is_empty(),"corrupted landed ecology is rejected without a runtime exception")
	malformed=core.world.duplicate(true);malformed.crew.erase("navigation")
	check(not FrontierUniverse.validate_world(malformed).is_empty(),"landed world requires fixed navigation state")
	check(core.close(),"host shutdown saves landed ecology and crew cargo")
	var reopened:=FrontierCrewAuthority.new()
	check(reopened.start(saved,owner,persist) and reopened.world.crew.members[owner.character_id].area=="surface","host resumes at landed ship with existing terrain/ecology")
	print("CREW_SURFACE_CHECKS ",checks," FAILURES ",failures," compressed_bytes=",encoded.size())
	quit(1 if failures else 0)
