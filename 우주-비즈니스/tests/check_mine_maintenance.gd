extends "res://tests/check_freight_salvage.gd"
func place(distance: float,receiver: bool=false,system: int=702) -> void:
	var nav: Dictionary=core.world.crew.navigation
	event=FrontierMineMaintenance.definition(core.world.manifest,system)
	nav.system=system;nav.target=int(event.body);nav.orbit_time=0;nav.mode="idle";nav.speed=0;nav.manual=true;nav.direction=[0,0,-1];nav.erase("freight_anchor")
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(event.receiver if receiver else event.position)+Vector3(0,0,distance))
	core.world.flight_position=nav.position.duplicate();core.world.location=event.body_id;core.world.navigation_target=event.body_id
func run() -> void:
	owner=FrontierPlayerProfile.new_character("mine 정비 검사",2)
	check(core.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host opens");core.phase="playing"
	var m: Dictionary=core.world.manifest;var credits:=int(FrontierExpeditionBusiness.config().starting_credits)
	var old:=m.duplicate(true);old.settings.corporate_space.erase("maintenance")
	check(FrontierMineMaintenance.definition(old,702).is_empty() and FrontierMineMaintenance.definition(m,2805).is_empty(),"old saves and non-industrial sites have no service event")
	place(500,true);var original:=event.duplicate(true);FrontierCorporateSites.cache.clear()
	check(event==FrontierMineMaintenance.definition(m,702) and event.source_body!=event.body,"stable industrial worksite and separate supply planet")
	hold(15);check(stage()==0,"diagnosis partial does not complete");hold(16);check(stage()==1,"diagnosis locates physical spare supply")
	hold(60);check(stage()==1,"cannot collect part remotely from worksite")
	place(180);hold(12)
	var before:=FrontierCrewWorld.vector(core.world.crew.navigation.position)
	FrontierCrewNavigation.step(core.world,.1)
	var drift:=FrontierCrewWorld.vector(core.world.crew.navigation.position)-before
	var later:=FrontierMineMaintenance.definition(m,702,.1)
	check(drift.distance_to(FrontierCrewWorld.vector(later.position)-FrontierCrewWorld.vector(original.position))<.001,"pickup station keeping follows supplier rather than worksite")
	hold(40);check(stage()==2 and FrontierFreightSalvage.carried(core.world.crew.freight_records,"crew")==event.id,"part loaded onto one shared external cradle")
	var occupied: Dictionary=core.world.crew.freight_records.duplicate(true);occupied["freight-v1:0"]={"stage":2,"carrier":"crew","at":0}
	check(not FrontierFreightSalvage.valid(occupied,core.world.crew),"spare parts and recovered freight compete for one cradle")
	place(300,true);hold(32)
	check(stage()==3 and FrontierFreightSalvage.carried(core.world.crew.freight_records,"crew").is_empty(),"installation frees cradle but does not restart machine")
	check(int(core.world.get("business",{}).get("credits",credits))==credits,"no payment at installation")
	hold(20);input(false);core.step_surface(.1);check(stage()==3 and core.scans.is_empty(),"release cancels repair before restart")
	core.save_world=func(_w):return false
	hold(72);check(stage()==3 and core.stopped,"failed save prevents restart and payment")
	core.stopped=false;core.save_world=func(_w):return true
	hold(72);check(stage()==4 and core.world.business.credits==credits+500,"saved calibration restarts mine and pays once")
	var revision: int=core.world.crew.revision;hold(80);check(core.world.crew.revision==revision and core.world.business.credits==credits+500,"held input cannot duplicate service reward")
	var store:=FrontierWorldStore.new("/tmp/corporations-sp10/world.json")
	check(store.write(core.world) and int(store.read_state().crew.freight_records[event.id].stage)==4,"restarted machine persists through reload")
	check(FrontierDiscoveryIndex.page(core.world,"mine","incident","",0).total==1,"mine service appears in J")
	print("MINE_MAINTENANCE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
