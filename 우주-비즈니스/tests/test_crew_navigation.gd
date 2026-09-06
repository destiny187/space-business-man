extends SceneTree
var checks:=0
var failures:=0
var saved: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func persist(world: Dictionary) -> bool:
	if not FrontierUniverse.validate_world(world).is_empty():return false
	saved=JSON.parse_string(JSON.stringify(world));return true
func command(core: FrontierCrewAuthority,peer: int,kind: String,args: Dictionary={}) -> Dictionary:
	var id: String=core.peers[peer]
	return core.request(peer,{"session_id":core.session_id,"sequence":int(core.world.crew.members[id].last_sequence)+1,"revision":core.world.crew.revision,"kind":kind,"args":args})
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("항해사")
	var guest:=FrontierPlayerProfile.new_character("지질학자",1)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"host navigation state created")
	var admission:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(core.acknowledge(2,core.session_id).ok,"crew aboard before route")
	check(not command(core,2,"navigate",{"ordinal":12}).ok,"passenger cannot redirect ship")
	check(not command(core,1,"navigate",{"ordinal":1000000}).ok,"past last planet rejected")
	check(command(core,1,"navigate",{"ordinal":999999}).ok,"last planet selectable")
	check(not command(core,1,"depart").ok,"unready crew prevents launch")
	command(core,1,"ready",{"value":true});command(core,2,"ready",{"value":true})
	check(command(core,1,"depart").ok and core.world.crew.navigation.mode=="jump","one shared jump begins")
	check(not command(core,1,"depart").ok,"second departure cannot restart jump")
	var before:=FrontierCrewWorld.vector(core.world.crew.navigation.position)
	for i in 10:FrontierCrewNavigation.step(core.world,.1)
	check(before.distance_to(FrontierCrewWorld.vector(core.world.crew.navigation.position))>600,"ship actually moves through 3D space during jump")
	check(core.checkpoint(),"mid-jump checkpoint commits")
	var remaining: float=saved.crew.navigation.jump_left
	var resumed:=FrontierCrewAuthority.new()
	check(resumed.start(saved,owner,persist),"same host reopens mid-jump")
	check(is_equal_approx(float(resumed.world.crew.navigation.jump_left),remaining),"jump progress preserved")
	var finished:=false
	for i in 500:
		if FrontierCrewNavigation.step(resumed.world,.1):finished=true;break
	var nav: Dictionary=resumed.world.crew.navigation
	check(finished and int(nav.system)==249999 and int(nav.target)==999999,"resumed ship reaches target system and completes approach")
	var body:=FrontierUniverse.body(resumed.world.manifest,999999)
	var distance:=FrontierCrewWorld.vector(nav.position).distance_to(FrontierCrewNavigation.center(999999))-(240+float(body.seed%190))
	check(distance>=599 and distance<=603,"physical arrival has safe orbit clearance")
	check(resumed.world.location==body.id and resumed.world.visited.has(body.id),"visit recorded only at destination")
	check(not resumed.world.crew.members[owner.character_id].ready,"arrival clears old readiness")
	check(resumed.checkpoint() and FrontierUniverse.validate_world(saved).is_empty(),"arrival and profile remain valid durable world")
	var invalid:=saved.duplicate(true);invalid.crew.navigation.jump_left=INF
	check(not FrontierUniverse.validate_world(invalid).is_empty(),"corrupted flight checkpoint rejected")
	var identity:=FrontierPlayerProfile.new("user://test_crew_profile_validation.json")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(identity.path+suffix)
	check(identity.ensure("원본 보존"),"separate profile persists")
	var original: Dictionary=identity.data.character.duplicate(true)
	check(identity.remember(saved.crew.world_id,admission.token),"session capability persists separately")
	var reopened:=FrontierPlayerProfile.new(identity.path)
	var opened:=reopened.ensure()
	if not opened:printerr("PROFILE_READ_ERROR ",reopened.error)
	check(opened and FrontierUniverse.fingerprint(reopened.data.get("character",{}))==FrontierUniverse.fingerprint(original),"reopening profile preserves equipment IDs and traits")
	var bad:=identity.data.duplicate(true);bad.character.equipment[0].definition="unknown_future_suit"
	var bad_text:=JSON.stringify(bad);FileAccess.open(identity.path,FileAccess.WRITE).store_string(bad_text)
	check(not reopened.ensure() and FileAccess.get_file_as_string(identity.path)==bad_text,"unknown equipment rejected without rewriting original")
	var malformed:=original.duplicate(true);malformed.name="bad\nname"
	check(not FrontierPlayerProfile.validate_character(malformed).is_empty(),"control characters rejected")
	for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(identity.path+suffix)
	print("CREW_NAVIGATION_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
