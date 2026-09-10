extends SceneTree
var failures:=0
var checks:=0
var core:=FrontierCrewAuthority.new()
var sequence:=0
var id: String
var point:=Vector3.ZERO
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func aim_input(held: bool=true,aim: Vector3=Vector3.FORWARD) -> void:
	sequence+=1;core.now+=.1;core.input(1,sequence,[0,0],FrontierExpeditionBusiness.array(aim),held)
func hold(count: int) -> void:
	for i in count:aim_input();core.step_surface(.1)
func place(index: int,distance: float) -> void:
	var w:=core.world;var row: Dictionary=FrontierCorporateTraces.all(w.manifest,index,0)[0];id=row.id;point=FrontierCrewWorld.vector(row.position)
	var nav: Dictionary=w.crew.navigation;nav.system=index;nav.target=int(row.body);nav.orbit_time=0;nav.mode="idle";nav.speed=0;nav.position=FrontierExpeditionBusiness.array(point+Vector3(0,0,distance));nav.direction=[0,0,-1]
	w.flight_position=nav.position.duplicate();w.location=row.body_id;w.navigation_target=row.body_id
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("활동 흔적 검사",2)
	check(core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host fixture opens")
	core.phase="playing"
	var m: Dictionary=core.world.manifest
	check(FrontierCorporateTraces.valid_rules(FrontierCorporateTraces.rules(m)),"saved version and trace definitions valid")
	var old:=m.duplicate(true);old.settings.corporate_space.erase("traces")
	check(FrontierCorporateTraces.all(old,702,0).is_empty() and FrontierCorporateSites.profile(old,702).sites==FrontierCorporateSites.profile(m,702).sites,"SP07 saved sites unchanged and no retroactive traces")
	for index in [53978,702,2805]:
		var rows:=FrontierCorporateTraces.all(m,index,0);FrontierCorporateSites.cache.clear()
		check(rows==FrontierCorporateTraces.all(m,index,0) and rows.size()==1,"deterministic company-specific trace "+str(index))
	place(702,1800);hold(7)
	check(not core.world.crew.has("corporate_traces") and float(core.scans[1].progress)>0,"partial identification does not publish record")
	core.now+=1;core.step_surface(.1);check(core.scans.is_empty(),"expired held input cancels progress")
	hold(8);check(FrontierCorporateTraces.records(core.world).is_empty(),"resumed scan starts fresh")
	hold(9);check(int(FrontierCorporateTraces.records(core.world).get(id,0))==1,"host saves company identification")
	hold(40);check(int(FrontierCorporateTraces.records(core.world)[id])==1,"dossier requires physical close approach")
	place(702,520);core.world.crew.navigation.speed=200;hold(40)
	check(int(FrontierCorporateTraces.records(core.world)[id])==1,"high speed cannot inspect")
	core.world.crew.navigation.speed=0;hold(9);aim_input(true,Vector3.BACK);core.step_surface(.1)
	check(core.scans.is_empty(),"aim loss cancels close inspection")
	hold(31);check(int(FrontierCorporateTraces.records(core.world)[id])==2,"close held scan saves activity dossier")
	var revision:=int(core.world.crew.revision);hold(32)
	check(int(core.world.crew.revision)==revision,"repeat inspection does not duplicate writes or rewards")
	check(FrontierDiscoveryIndex.page(core.world,"mine","corporation","",0).total==1,"J queries discovered trace, including company filter")
	check(FrontierDiscoveryIndex.page(core.world,"Lotus","corporation","",0).total==0,"undiscovered dossiers absent from J")
	var store:=FrontierWorldStore.new("/tmp/corporations-sp08/world.json")
	check(store.write(core.world),"trace world serializes")
	var saved:=store.read_state();check(not saved.is_empty() and int(FrontierCorporateTraces.records(saved).get(id,0))==2,"reload preserves stable IDs and stages")
	var planet:=FrontierUniverse.body(m,int(core.world.crew.navigation.target),false);var center:=FrontierUniverse.position(m,int(planet.ordinal),0)
	check(FrontierCorporateTraces.occluded(m,702,0,center-(point-center),point),"planet blocks orbital investigation ray")
	# FINCH independently surveys a different company while the main ship remains here.
	var ship: Dictionary=core.world.crew.shuttles[owner.character_id];ship.state="sortie";ship.landing={};core.world.crew.members[owner.character_id].shuttle_id=owner.character_id
	var row: Dictionary=FrontierCorporateTraces.all(m,53978,0)[0]
	ship.navigation=core.world.crew.navigation.duplicate(true);ship.navigation.system=53978;ship.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(row.position)+Vector3(0,0,520));ship.navigation.target=int(row.body);ship.location=row.body_id
	hold(47);check(int(FrontierCorporateTraces.records(core.world).get(row.id,0))==2 and int(core.world.crew.navigation.system)==702,"FINCH records shared traces using its own system and position")
	# Failed persistence never publishes a completed stage or success cue.
	core.world.crew.members[owner.character_id].erase("shuttle_id");place(2805,520);core.scans.clear();core.save_world=func(_w):return false
	hold(16)
	check(core.stopped and not FrontierCorporateTraces.records(core.world).has(id) and core.scans.is_empty(),"save failure stops world without claiming completion")
	var large: Dictionary={}
	for i in range(1,301):large["trace:"+FrontierCorporateSites.address(i,0)]=1
	var bounded:=FrontierCorporateTraces.snapshot(large,1)
	check(bounded.size()==257 and bounded.has("trace:corp_1_0"),"movement snapshots retain current plus recent records within bound")
	check(not FrontierCorporateTraces.valid({"trace:corp_702_0":3}) and not FrontierCorporateTraces.valid({"arbitrary":1}),"malformed saved stages and IDs rejected")
	print("CORPORATE_TRACE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
