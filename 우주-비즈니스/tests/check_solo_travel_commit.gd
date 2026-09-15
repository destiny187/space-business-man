extends SceneTree
var failures:=0
var writes:=0
var owner: Dictionary
var source: Dictionary
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func core() -> FrontierCrewAuthority:
	var a:=FrontierCrewAuthority.new()
	assert(a.start(source,owner,func(_w):return true))
	a.phase="playing";a.world.crew.navigation.erase("solar_opening")
	a.world.crew.navigation.target=destination(a.world)
	a.save_request=func(_w):writes+=1;return true
	a.poll_autonomous=func():return 0
	a.finish_autonomous=func():return 1
	return a
func destination(world: Dictionary) -> int:
	var m: Dictionary=world.manifest
	var origin:=FrontierUniverse.map_position(m,0)
	for i in 10000:
		if i==0 or origin.distance_to(FrontierUniverse.map_position(m,i))>FrontierVesselRefit.stellar_range(world):continue
		var ordinal:=FrontierUniverse.first_ordinal(m,i)
		if FrontierVesselAccess.departure_reason(world,ordinal).is_empty():return ordinal
	assert(false,"nearby first route exists")
	return -1
func envelope(a: FrontierCrewAuthority,n: int,kind: String,args: Dictionary) -> Dictionary:
	return {"session_id":a.session_id,"sequence":n,"revision":a.world.crew.revision,"kind":kind,"args":args}
func run() -> void:
	owner=FrontierPlayerProfile.new_character("출항 재현")
	source=FrontierUniverse.new_world(61739)
	var old:=core();old.world.crew.members[owner.character_id].ready=true
	var ready:=envelope(old,1,"ready",{"value":true})
	var depart:=envelope(old,2,"depart",{})
	old.request(1,ready);old.request(1,depart);old.resolve_autonomous(true);old.pump_requests()
	check(old.completed_requests.back().result.get("error","").contains("세계 상태가 바뀌"),"old ready + depart reproduces stale revision")
	var a:=core();writes=0
	var before:=a.world.duplicate(true)
	depart=envelope(a,1,"depart",{"auto_ready":true})
	var submitted:=a.request(1,depart);print("SUBMITTED ",submitted)
	check(submitted.get("pending",false) and a.world==before,"combined travel waits for save without publishing readiness or energy cost")
	check(a.request(1,depart).get("pending",false) and writes==1,"pending duplicate creates only one save")
	a.resolve_autonomous(true)
	check(a.world.crew.navigation.mode=="jump" and a.world.crew.members[owner.character_id].ready,"first request starts interstellar travel from unready state")
	check(a.world.crew.revision==before.crew.revision+1 and writes==1,"readiness and departure share one revision and save")
	if a.world.crew.navigation.mode!="jump":quit(1);return
	var energy: float=a.world.crew.navigation.energy
	check(a.request(1,depart).get("ok",false) and a.world.crew.navigation.energy==energy and writes==1,"committed replay cannot charge departure twice")
	var unrelated:=before.duplicate();unrelated.erase("crew");unrelated.erase("navigation_target")
	var after:=a.world.duplicate();after.erase("crew");after.erase("navigation_target")
	check(unrelated==after,"travel leaves unrelated world branches unchanged")
	a=core();a.world.crew.navigation.energy=0;before=a.world.duplicate(true);writes=0
	check(not a.request(1,envelope(a,1,"depart",{"auto_ready":true})).get("ok",true) and a.world==before and writes==0,"failed travel preserves readiness and writes nothing")
	a=core();before=a.world.duplicate(true);a.finish_autonomous=func():return -1
	a.request(1,envelope(a,1,"depart",{"auto_ready":true}))
	check(not a.resolve_autonomous(true) and a.world==before and not a.completed_requests.back().result.ok,"failed save cannot publish readiness or departure")
	a=core()
	var guest:=FrontierPlayerProfile.new_character("승무원")
	a.world.crew.members[guest.character_id]=FrontierCrewWorld.member(guest,"",1);a.peers[2]=guest.character_id
	before=a.world.duplicate(true);writes=0
	check(not a.request(1,envelope(a,1,"depart",{"auto_ready":true})).get("ok",true) and a.world==before and writes==0,"shared crew cannot be forced ready")
	check(not a.request(1,envelope(a,2,"depart",{})).get("ok",true),"ordinary co-op departure still requires crew readiness")
	print("SOLO TRAVEL COMMIT failures ",failures)
	quit(1 if failures else 0)
