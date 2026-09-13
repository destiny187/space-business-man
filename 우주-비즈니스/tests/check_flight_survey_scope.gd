extends SceneTree
var core:=FrontierCrewAuthority.new()
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func place(system: int,ordinal: int,position: Vector3) -> void:
	var nav: Dictionary=core.world.crew.navigation
	nav.erase("solar_opening");nav.erase("freight_anchor");nav.erase("freight_anchor_source")
	nav.system=system;nav.target=ordinal;nav.position=FrontierExpeditionBusiness.array(position);nav.orbit_time=0;nav.mode="idle";nav.speed=0;nav.direction=[0,0,-1];nav.up=[0,1,0];nav.manual=true
	core.world.flight_position=nav.position.duplicate();core.world.location=FrontierUniverse.body_id(core.world.manifest,ordinal);core.world.navigation_target=core.world.location
	core.scans.clear();core.stopped=false
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("궤도 조사 범위 확인",0)
	core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);core.phase="playing"
	core.world.business=FrontierExpeditionBusiness.create()
	core.input(1,1,[0,0],[0,0,-1],true,false,FrontierCrewNavigation.stopped_input())
	var event:=FrontierFreightSalvage.definition(core.world.manifest,"freight-v1:0",0)
	place(0,int(event.body),FrontierCrewWorld.vector(event.receiver)+Vector3.BACK*350)
	core.world.crew.freight_records={event.id:{"stage":2,"carrier":"crew","at":0.0}}
	var before: Dictionary=core.world;var credits:=int(before.business.credits)
	core.save_world=func(_w):return false
	FrontierFreightSalvageSurvey.step(core,1,core.world,20)
	check(core.stopped and core.world.crew.freight_records[event.id].stage==2 and int(core.world.business.credits)==credits,"failed freight receipt preserves cargo and shared credits")
	core.stopped=false;core.save_world=func(_w):return true
	FrontierFreightSalvageSurvey.step(core,1,core.world,20)
	check(core.world.crew.freight_records[event.id].stage==3 and int(core.world.business.credits)==credits+int(event.payment) and before.crew.freight_records[event.id].stage==2 and int(before.business.credits)==credits,"successful freight receipt only replaces target and credits")
	check(is_same(before.ecology,core.world.ecology) and is_same(before.business.sites,core.world.business.sites) and is_same(before.crew.cargo,core.world.crew.cargo),"freight completion shares unrelated planets, industry and cargo")
	var revision:=int(core.world.crew.revision)
	FrontierFreightSalvageSurvey.step(core,1,core.world,20)
	check(core.world.crew.revision==revision and int(core.world.business.credits)==credits+int(event.payment),"held freight input cannot pay twice")
	var trace: Dictionary={}
	for index in [2805,53978]:
		for row in FrontierCorporateTraces.all(core.world.manifest,index,0):
			if row.company=="coopertech":trace=row;break
		if not trace.is_empty():break
	check(not trace.is_empty(),"current seeded CooperTech trace is available")
	if trace.is_empty():quit(1);return
	place(int(trace.system),int(trace.body),FrontierCrewWorld.vector(trace.position)+Vector3.BACK*520)
	core.world.crew.corporate_traces={trace.id:1};before=core.world
	core.save_world=func(_w):return false
	FrontierCorporateTraceSurvey.step(core,1,core.world,20)
	check(core.stopped and core.world.crew.corporate_traces[trace.id]==1 and not core.world.get("coopertech_clues",{}).has(trace.id),"failed trace inspection preserves stage and ground clues")
	core.stopped=false;core.save_world=func(_w):return true
	FrontierCorporateTraceSurvey.step(core,1,core.world,20)
	check(core.world.crew.corporate_traces[trace.id]==2 and before.crew.corporate_traces[trace.id]==1 and is_same(before.ecology,core.world.ecology) and is_same(before.business,core.world.business),"trace completion replaces its ledger while sharing unrelated world")
	check(core.world.coopertech_clues.has(trace.id) and not before.get("coopertech_clues",{}).has(trace.id) and before.incidents.records.size()<core.world.incidents.records.size(),"CooperTech ground clue and incident are isolated from previous state")
	var body: Dictionary={}
	for id in core.world.manifest.native_biota.planets:
		var candidate:=FrontierUniverse.body(core.world.manifest,int(id),false)
		if candidate.kind in ["gas_giant","ice_giant"] and not FrontierAtmosphereSurvey.observable(candidate).is_empty():body=candidate;break
	check(not body.is_empty(),"current galaxy has an observable native atmosphere")
	if body.is_empty():quit(1);return
	place(int(body.system_ordinal),int(body.ordinal),FrontierUniverse.position(core.world.manifest,int(body.ordinal),0)+Vector3.BACK*(FrontierUniverse.navigation_radius(body)+500))
	before=core.world
	var count: int=before.ecology.observations.size();core.save_world=func(_w):return false
	FrontierAtmosphereSurvey.step(core,1,core.world,20)
	check(core.stopped and core.world.ecology.observations.size()==count and core.scans.is_empty(),"failed atmosphere save publishes no observation or completion")
	core.stopped=false;core.save_world=func(_w):return true
	FrontierAtmosphereSurvey.step(core,1,core.world,20)
	check(core.world.ecology.observations.size()==count+1 and before.ecology.observations.size()==count and is_same(before.business,core.world.business) and is_same(before.ecology.research,core.world.ecology.research),"atmosphere completion isolates observation and naming maps")
	DirAccess.make_dir_recursive_absolute("/tmp/space-forward-surveys")
	var store:=FrontierWorldStore.new("/tmp/space-forward-surveys/world.json")
	check(store.write(core.world),"completed survey drafts pass whole-world validation and atomic save: "+store.last_error)
	var restored:=store.read_state()
	check(not restored.is_empty() and restored.crew.freight_records[event.id].stage==3 and restored.crew.corporate_traces[trace.id]==2 and restored.ecology.observations.size()==count+1,"survey receipt, ground clue and atmospheric observation reload")
	print("FLIGHT_SURVEY_SCOPE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
