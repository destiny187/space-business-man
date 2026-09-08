extends "res://tests/test_crew_surface.gd"
var station: Dictionary={}
func check(condition: bool,label: String) -> void:
	super.check(condition,label)
	if condition:print("PASS ",label)
func args_for(resource: String="sapphire",amount: int=1) -> Dictionary:
	return {"station_id":"ship:research","project":"deep_mining","resource":resource,"amount":amount,"expected_stage":"discovered"}
func denied(core: FrontierCrewAuthority,peer: int,args: Dictionary,label: String) -> void:
	var before:=FrontierUniverse.fingerprint(core.world)
	check(not request(core,peer,"research_contribute",args).ok and FrontierUniverse.fingerprint(core.world)==before,label)
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("연구 호스트",0)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"new shared research world starts")
	check(request(core,1,"start_game").ok,"play starts")
	check(core.world.expedition_research.origin=="new" and not FrontierExpeditionResearch.licensed(core.world,"miner_3"),"new worlds receive no legacy license")
	var old:=core.world.duplicate(true);old.erase("expedition_research")
	var body_id: String=old.location
	old.crew.survey={body_id+"/mineral/sapphire":{"body_id":body_id,"resource":"sapphire","vein_id":"legacy:gem","tier":2}}
	old.crew.members[owner.character_id].loadout.items["old:miner"]="miner_3"
	DirAccess.make_dir_recursive_absolute("/tmp/research-a05")
	var store:=FrontierWorldStore.new("/tmp/research-a05/legacy.json")
	check(store.write(old),"old save remains accepted")
	var migrated:=store.read_state();var migrated_hash:=FrontierUniverse.fingerprint(migrated)
	check(migrated.expedition_research.origin=="legacy" and FrontierExpeditionResearch.licensed(migrated,"miner_3") and migrated.expedition_research.projects.deep_mining.stage=="discovered","old survey imports and existing-world license migrates")
	FrontierExpeditionResearch.ensure(migrated)
	check(FrontierUniverse.fingerprint(migrated)==migrated_hash and migrated.crew.members[owner.character_id].loadout.items["old:miner"]=="miner_3","migration is idempotent and keeps held equipment")
	check(store.write(migrated) and store.read_state().expedition_research.projects.deep_mining.contributions.is_empty(),"migrated save reload does not invent contributions")
	var future:=migrated.duplicate(true);future.expedition_research.version=3
	check(not store.write(future) and store.read_state().expedition_research.version==2,"unknown research version cannot overwrite save")
	var forged:=core.world.duplicate(true);forged.expedition_research.projects.deep_mining.stage="analyzed"
	check(not FrontierUniverse.validate_world(forged).is_empty(),"stage cannot advance without evidence and samples")
	forged=core.world.duplicate(true);forged.expedition_research.licenses.miner_3="legacy"
	check(not FrontierUniverse.validate_world(forged).is_empty(),"new state cannot claim legacy license")
	# The same record hook used after a host-confirmed mineral scan.
	var scan_world:=core.world.duplicate(true);scan_world.crew.landing={"body_id":body_id}
	FrontierSurfaceSurvey.record(scan_world,{"kind":"mineral","resource":"sapphire","id":"scan:gem","required_tier":2},owner.character_id)
	core.world.expedition_research=scan_world.expedition_research
	var research_hash:=FrontierUniverse.fingerprint(core.world.expedition_research)
	FrontierExpeditionResearch.record(core.world,body_id,"sapphire","another:gem",2,"extraction",owner.character_id)
	FrontierExpeditionResearch.record(core.world,body_id,"diamond","diamond:gem",3,"extraction",owner.character_id)
	check(FrontierUniverse.fingerprint(core.world.expedition_research)==research_hash,"duplicate material proof and T3 diamond do not advance first research")
	core.world.business=FrontierExpeditionBusiness.create();core.world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();core.world.business.bags[owner.character_id].sapphire=4
	station={"enabled":true,"position":FrontierCrewWorld.vector(core.world.crew.members[owner.character_id].position),"area":"cabin","body_id":""}
	denied(core,1,args_for(),"missing live research provider rejects contribution")
	core.research_station_provider=func(_actor: String,_id: String):return station
	var bad:=args_for();bad.stage="analyzed";denied(core,1,bad,"client cannot inject a stage")
	bad=args_for();bad.expected_stage="analyzed";denied(core,1,bad,"unexpected stage rejected")
	denied(core,1,args_for("ruby"),"unobserved specimen rejected")
	station.position+=Vector3(20,0,0);denied(core,1,args_for(),"remote contribution rejected");station.position-=Vector3(20,0,0)
	var pending_request:=envelope(core,1,"research_contribute",args_for())
	disk_ok=false;var before:=FrontierUniverse.fingerprint(core.world)
	check(not core.request(1,pending_request).ok and FrontierUniverse.fingerprint(core.world)==before,"save failure rolls back bag and research together")
	disk_ok=true;var result:=core.request(1,pending_request)
	check(result.ok and core.world.business.bags[owner.character_id].sapphire==3 and core.world.expedition_research.projects.deep_mining.stage=="discovered","partial contribution spends own sample and retains discovery stage")
	before=FrontierUniverse.fingerprint(core.world)
	check(core.request(1,pending_request)==result and before==FrontierUniverse.fingerprint(core.world),"exact retry returns receipt without duplicate sample consumption")
	denied(core,1,args_for("sapphire",3),"over-contribution rejected")
	var guest:=FrontierPlayerProfile.new_character("연구 동료",1)
	check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"guest joins shared project")
	core.world.crew.members[guest.character_id].position=FrontierExpeditionBusiness.array(station.position)
	core.world.crew.cargo={"sapphire":99}
	denied(core,2,args_for(),"guest cannot consume host bag or shared cargo")
	core.world.business.bags[guest.character_id]=FrontierExpeditionBusiness.inventory();core.world.business.bags[guest.character_id].sapphire=2
	result=request(core,2,"research_contribute",args_for("sapphire",2))
	check(result.ok and result.research.stage=="analyzed" and core.world.business.bags[guest.character_id].sapphire==0 and core.world.crew.cargo.sapphire==99,"guest completes shared analysis with own samples")
	denied(core,1,args_for(),"completed analysis cannot consume more samples")
	check(core.snapshot(1).expedition_research==core.snapshot(2).expedition_research and not owner.has("expedition_research") and not guest.has("expedition_research"),"both crew see one ledger; profiles remain unchanged")
	var local:=core.world.duplicate(true);local.local_shuttle=guest.character_id
	check(not FrontierExpeditionResearch.reason(local,guest.character_id,args_for(),station).is_empty(),"FINCH cannot act as a research lab")
	var restored:=FrontierCrewAuthority.new()
	check(restored.start(saved,owner,persist) and FrontierExpeditionResearch.sample_count(restored.world.expedition_research.projects.deep_mining)==3 and restored.world.expedition_research.projects.deep_mining.stage=="analyzed","host resume retains shared analysis and contributions")
	check(not FrontierExpeditionResearch.licensed(core.world,"miner_3") and not FrontierExpeditionResearch.craft_reason(migrated,"miner_3").is_empty() and FrontierExpeditionResearch.craft_reason(core.world,"miner_2").is_empty(),"A05 analysis grants no T3 recipe; existing T2 and unavailable T3 remain unchanged")
	# Exercise the shared future gate without enabling new content in shipped data.
	FrontierEquipment.config().items.miner_3.craftable=true
	var crafting:=core.world.duplicate(true);crafting.crew.members[owner.character_id].area="surface";crafting.business.bags[owner.character_id].iron=12;crafting.business.bags[owner.character_id].crystal=4
	check(not FrontierEquipment.apply(crafting,owner.character_id,"equipment_craft",{"definition":"miner_3"}).is_empty(),"craft execution uses the same unlicensed-recipe gate")
	crafting.expedition_research=FrontierExpeditionResearch.create(true)
	check(FrontierEquipment.apply(crafting,owner.character_id,"equipment_craft",{"definition":"miner_3"}).is_empty(),"legacy license preserves access when recipe becomes available")
	FrontierEquipment.config().items.miner_3.craftable=false
	print("EXPEDITION_RESEARCH_A05 ",checks," FAILURES ",failures);quit(1 if failures else 0)
