extends "res://tests/check_facility_interactions.gd"
func request(authority: FrontierCrewAuthority,kind: String,args: Dictionary={}) -> Dictionary:
	var id: String=authority.world.crew.owner_id
	return authority.request(1,{"session_id":authority.session_id,"sequence":int(authority.world.crew.members[id].last_sequence)+1,"revision":authority.world.crew.revision,"kind":kind,"args":args})
func add_guest(authority: FrontierCrewAuthority,peer: int,ack: bool=true) -> void:
	var profile: Dictionary=authority.world.crew.members[authority.world.crew.owner_id].profile.duplicate(true)
	profile.character_id=FrontierPlayerProfile.token();profile.name="Review guest"
	var result:=authority.admit(peer,profile,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(result.ok,"guest admission fixture")
	if ack:check(authority.acknowledge(peer,authority.session_id).ok,"guest synchronized fixture")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
	if not await until(func():return app.session.active,15):quit(1);return
	app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierCrewNavigation.first_destination(world.manifest)
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=FrontierUniverse.system_index(world.manifest,ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):quit(1);return
	app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	var baseline: Dictionary=app.session.authority.world.duplicate(true)
	var id: String=baseline.crew.owner_id
	var profile: Dictionary=baseline.crew.members[id].profile
	var examples: Dictionary={}
	for count in [1,2,6]:
		var authority:=FrontierCrewAuthority.new()
		check(authority.start(baseline,profile,func(value: Dictionary):return FrontierUniverse.validate_world(value).is_empty()),"authority starts with valid world")
		authority.phase="playing"
		authority.world.crew.members[id].position=FrontierCrewSurface.config().ship_position.duplicate()
		for peer in range(2,count+1):add_guest(authority,peer)
		if count<6:add_guest(authority,20,false)
		# A rejected first construction must not persist activation or its participant snapshot.
		var rejected:=request(authority,"business_build",{"type":"solar","position":[0,2,0],"yaw":0.0})
		check(not rejected.ok and not FrontierExpeditionBusiness.site(authority.world).has("coop_workload"),"failed first operation never fixes participants")
		var result:=request(authority,"business_register")
		check(result.ok,"first accepted registration activates contract")
		var site:=FrontierExpeditionBusiness.site(authority.world)
		var fixed: Dictionary=site.get("coop_workload",{})
		check(fixed.get("participant_count")==count and is_equal_approx(float(fixed.get("coefficient",0)),1+.15*(count-1)),"T1 counts only acknowledged participants")
		check(FrontierCoopWorkload.valid(site,1),"fixed workload validates")
		check(FrontierEvaluator.environment_report(site).overall==FrontierEvaluator.environment_report(FrontierExpeditionBusiness.site(baseline)).overall,"participant count never changes suitability of identical environment")
		var frozen:=fixed.duplicate(true)
		authority.peers={1:id}
		FrontierCoopWorkload.activate(site,body,6)
		check(site.coop_workload==frozen,"join and leave cannot recalculate fixed contract")
		examples[count]=site.duplicate(true)
	# Equal facilities keep rates, cycle timers and input recipes; one volume factor only.
	for count in [1,2,6]:
		var isolated:=baseline.duplicate(true);isolated.business.sites[body.id]=examples[count].duplicate(true);isolated.business.active=body.id
		var site:=FrontierExpeditionBusiness.site(isolated)
		site.inventory.ice=10
		site.buildings={"water":{"id":"water","type":"water","active":true,"work":0.0,"status":""},"air":{"id":"air","type":"atmosphere","active":true,"work":0.0,"status":""}}
		var before: Dictionary=site.environment.duplicate()
		var cfg:=FrontierExpeditionBusiness.config();var dt:=float(cfg.water_cycle_seconds)
		FrontierExpeditionIndustry.environment(isolated,site,dt)
		var factor: float=site.coop_workload.coefficient
		check(site.inventory.ice==9 and is_equal_approx((float(site.environment.water)-float(before.water))*factor,float(cfg.water_per_ice)),"equal water cycle consumes one ice and treats one machine quantity")
		check(is_equal_approx((float(before.toxicity)-float(site.environment.toxicity))*factor,minf(float(before.toxicity),float(cfg.toxicity_rate)*dt)),"equal air work scales treated volume once")
		check(is_equal_approx(float(site.coop_workload.target_workload.water),float(site.coop_workload.base_workload.water)*factor),"stored treatment target scales once")
		# Stability is a wall-clock observation, regardless of participants.
		site.environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":100.0,"ecology":20.0,"stable_seconds":0.0};site.buildings={}
		FrontierExpeditionIndustry.environment(isolated,site,1)
		check(site.environment.stable_seconds==1,"stable observation stays one second")
	for count in [1,2,6]:
		var sample: Dictionary=examples[1].duplicate(true);sample.erase("coop_workload");sample.workload_eligible=true;sample.restoration2={"salinity":70.0,"soil":10.0}
		var tier2:=body.duplicate(true);tier2.planet_tier=2
		FrontierCoopWorkload.activate(sample,tier2,count)
		check(is_equal_approx(float(sample.coop_workload.coefficient),1+.30*(count-1)) and FrontierCoopWorkload.valid(sample,2),"T2 coefficient and additional workload validate")
		var env: Dictionary=sample.environment.duplicate();var old: Dictionary=sample.restoration2.duplicate()
		sample.restoration2.salinity-=10;sample.restoration2.soil+=10
		FrontierCoopWorkload.distribute(sample,env,old)
		check(is_equal_approx((70-float(sample.restoration2.salinity))*float(sample.coop_workload.coefficient),10),"T2 module performs one quantity across expanded volume")
	var legacy: Dictionary=examples[1].duplicate(true);legacy.erase("coop_workload")
	var old:=legacy.duplicate(true);FrontierCoopWorkload.activate(legacy,body,6)
	check(legacy==old and FrontierCoopWorkload.reward(legacy,1)==6000,"existing active contract keeps quantity and reward")
	# Render fixed two-player terms using the exact authority-produced snapshot.
	var display: Dictionary=baseline.business.duplicate(true);display.sites[body.id]=examples[2]
	app.open_station("ship")
	app.business_panel.update(display,body.id,id,1,{}, {},body,Vector3.ZERO,6)
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.3).timeout
	check("2" in app.business_panel.workload_label.text and "6900" in app.business_panel.workload_label.text,"UI shows original fixed count and reward after participant change")
	await capture("fixed-contract-960")
	app.close_menus()
	# Actual live host activates and pays only the fixed reward; accepted receipt is replay safe.
	app.session.send_request("business_register",{})
	world=app.session.authority.world
	var current:=FrontierExpeditionBusiness.site(world)
	check(current.coop_workload.participant_count==1,"live solo host fixes one participant")
	current.environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":100.0,"ecology":20.0,"stable_seconds":30.0}
	world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	var credits: int=world.business.credits
	var envelope: Dictionary={"session_id":app.session.authority.session_id,"sequence":int(world.crew.members[id].last_sequence)+1,"revision":world.crew.revision,"kind":"business_settle","args":{}}
	check(app.session.authority.request(1,envelope).ok,"host settlement accepts completed fixed contract")
	check(app.session.authority.world.business.credits==credits+6000,"host pays fixed reward exactly once")
	check(app.session.authority.request(1,envelope).ok and app.session.authority.world.business.credits==credits+6000,"replayed settlement receipt cannot duplicate payment")
	check(await app.session.close_session(),"fixed contract saved")
	var saved:=app.world_store.read_state()
	check(not saved.is_empty() and FrontierExpeditionBusiness.site(saved).coop_workload.participant_count==1,"fixed contract survives reload")
	print("COOP_WORKLOAD_FAILURES ",failures);quit(1 if failures else 0)
