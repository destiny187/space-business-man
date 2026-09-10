extends SceneTree
var core:=FrontierCrewAuthority.new()
var owner: Dictionary
var sequence:=0
var checks:=0
var failures:=0
var event: Dictionary
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;printerr("FAIL ",label)
func input(held: bool=true,aim: Vector3=Vector3.FORWARD,peer: int=1) -> void:
	sequence+=1;core.now+=.1;core.input(peer,sequence,[0,0],FrontierExpeditionBusiness.array(aim),held)
func hold(count: int) -> void:
	for i in count:input();core.step_surface(.1)
func stage() -> int:return int(FrontierFreightSalvage.records(core.world).get(event.id,{}).get("stage",0))
func place(distance: float,receiver: bool=false,system: int=0) -> void:
	var local:=FrontierShuttles.context(core.world,owner.character_id)
	event=FrontierFreightSalvage.definition(core.world.manifest,FrontierFreightSalvage.address(system),0)
	var nav: Dictionary=local.crew.navigation;nav.system=system;nav.target=int(event.body);nav.orbit_time=0;nav.mode="idle";nav.speed=0;nav.manual=true;nav.direction=[0,0,-1]
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(event.receiver if receiver else event.position)+Vector3(0,0,distance))
	local.flight_position=nav.position.duplicate();local.location=event.body_id;local.navigation_target=event.body_id
	FrontierShuttles.commit(core.world,local,owner.character_id)
func run() -> void:
	owner=FrontierPlayerProfile.new_character("유실 화물 검사",2)
	check(core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host fixture opens");core.phase="playing"
	var m: Dictionary=core.world.manifest;var credits:=int(core.world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits))
	check(FrontierFreightSalvage.valid_rules(FrontierFreightSalvage.rules(m)),"optional saved event rules valid")
	var old:=m.duplicate(true);old.settings.corporate_space.erase("salvage")
	check(FrontierFreightSalvage.definition(old,"freight-v1:0").is_empty() and FrontierSpaceTraffic.sample(old,0,0).id==FrontierSpaceTraffic.sample(m,0,0).id,"SP08 saves retain traffic without retroactive events")
	place(1800);var stable:=event.duplicate(true);FrontierCorporateSites.cache.clear()
	check(stable==FrontierFreightSalvage.definition(m,event.id) and event.destination=="solar_mars_port","stable Solar freight ID and Mars receiver")
	check(FrontierFreightSalvage.missing_pod(m,FrontierSpaceTraffic.sample(m,0,0)) and not FrontierFreightSalvage.missing_pod(m,FrontierSpaceTraffic.sample(m,0,1300)),"affected CARRIER load has one missing pod and later trips reload")
	hold(7);check(stage()==0 and float(core.scans[1].progress)>0,"partial identification has no saved success")
	core.now+=1;core.step_surface(.1);check(core.scans.is_empty(),"expired input cancels held action")
	hold(16);check(stage()==1,"live E input saves manifest identification")
	hold(52);check(stage()==1,"remote scan cannot load cargo")
	place(180);core.world.crew.navigation.speed=180;hold(52);check(stage()==1,"excess speed prevents winch operation")
	core.world.crew.navigation.speed=0;hold(12);input(true,Vector3.BACK);core.step_surface(.1);check(core.scans.is_empty() and stage()==1,"lost aim releases winch without claiming cargo")
	# A crew member may identify, but only the current local pilot operates the rig.
	core.world.crew.pilot_id="other";hold(51);check(stage()==1,"passenger cannot load the external cradle");core.world.crew.pilot_id=owner.character_id
	hold(52);check(stage()==2 and FrontierFreightSalvage.carried(FrontierFreightSalvage.records(core.world),"crew")==event.id,"single external pod is now attached to main vessel")
	check(int(core.world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits))==credits and not FrontierShuttles.guard(core.world,owner.character_id,"land",{}).is_empty(),"loading does not pay and external cargo must be handed over before landing")
	var store:=FrontierWorldStore.new("/tmp/corporations-sp09/freight-world.json")
	check(store.write(core.world),"loaded cargo serializes with host world")
	var saved:=store.read_state();check(not saved.is_empty() and FrontierFreightSalvage.carried(FrontierFreightSalvage.records(saved),"crew")==event.id,"reload retains physical cargo owner")
	# The receiver follows the actual moving orbital port, even after an unload/reload.
	core.world=saved;place(350,true)
	for i in 10:
		FrontierCrewNavigation.step(core.world,.1);input();core.step_surface(.1)
	check(stage()==2 and float(core.scans[1].progress)>.2 and core.world.crew.navigation.has("freight_anchor"),"station keeping tracks moving port during held handover")
	core.scans.clear();core.save_world=func(_w):return false
	hold(32);check(core.stopped and stage()==2 and int(core.world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits))==credits,"failed handover save preserves cargo and denies payment")
	core.stopped=false;core.save_world=func(_w):return true
	hold(32);check(stage()==3 and int(core.world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits))==credits+350,"successful atomic handover frees rig and pays shared fund once")
	check(FrontierFreightSalvage.obstacles(m,0,0,core.world.crew.freight_records).size()==1,"delivered pod clears its old collision site")
	FrontierCrewNavigation.steer(core.world,[1,0,0],.1)
	check(not core.world.crew.navigation.has("freight_anchor"),"pilot throttle releases relative station keeping")
	core.world.crew.navigation.speed=0
	var revision:=int(core.world.crew.revision);hold(40);check(core.world.crew.revision==revision and int(core.world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits))==credits+350,"held E after receipt cannot repeat payment")
	check(store.write(core.world) and int(store.read_state().crew.freight_records[event.id].stage)==3,"receipt survives reload without respawn")
	check(FrontierDiscoveryIndex.page(core.world,"Space Y","incident","",0).total==1,"J includes actual identified freight incident")
	# Find one eligible regional incident using the same saved spatial profile, no reseeding.
	var regional:=-1
	for index in range(1,200):
		if not FrontierFreightSalvage.definition(m,FrontierFreightSalvage.address(index)).is_empty():regional=index;break
	check(regional>0 and FrontierFreightSalvage.definition(m,"freight-v1:1403").is_empty(),"sparse active regional routes have events; unoccupied system stays quiet")
	var ship: Dictionary=core.world.crew.shuttles[owner.character_id];ship.state="sortie";ship.landing={};core.world.crew.members[owner.character_id].shuttle_id=owner.character_id
	place(180,false,regional);hold(68)
	check(stage()==2 and core.world.crew.freight_records[event.id].carrier=="shuttle:"+owner.character_id and int(core.world.crew.navigation.system)==0,"FINCH uses own location and own cradle while main vessel stays Solar")
	check(FrontierFreightSalvage.valid(core.world.crew.freight_records,core.world.crew),"shared cargo ledger validates independent vessels")
	var invalid: Dictionary=core.world.crew.freight_records.duplicate(true);invalid["freight-v1:124999"]=invalid[event.id].duplicate()
	check(not FrontierFreightSalvage.valid(invalid,core.world.crew),"two cargo records cannot occupy one cradle")
	var result:=FrontierFreightSalvage.snapshot(core.world.crew.freight_records,0)
	check(result.has(event.id) and result.has("freight-v1:0"),"snapshots keep carried cargo and local receipt")
	print("FREIGHT_SALVAGE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
