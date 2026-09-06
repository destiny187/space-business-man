extends "res://tests/test_expedition_business.gd"
func run() -> void:
	for environment in ["basalt","cold","arid"]:
		core=FrontierCrewAuthority.new();sequences.clear()
		var owner:=FrontierPlayerProfile.new_character("현장 연구",0);owner_id=owner.character_id
		check(core.start(FrontierUniverse.new_world(71491),owner,persist),"research world opens "+environment)
		var ordinal: int=-1
		for i in 300:
			var body:=FrontierUniverse.body(core.world.manifest,i);var profile:=FrontierEcology.profile(body)
			if profile.environment==environment and profile.origin=="established":ordinal=i;break
		check(ordinal>=0,"seed provides matching environment "+environment)
		navigate(core,ordinal);ready_all(core);check(command("land").ok,"actual navigation and landing "+environment)
		check(command("business_register").ok,"free research site "+environment)
		var sample:=find_sample(core,1)
		check(not sample.is_empty(),"physical native organism found "+environment)
		if sample.is_empty():quit(1);return
		for i in 20:
			core.advance_time(core.now+.1);core.input(1,i+1,[0,0],[sample.aim.x,sample.aim.y,sample.aim.z],true);core.step_surface(.1)
		check(core.world.ecology.observations.has(core.world.location+":"+sample.form_id),"held scanner records original organism "+environment)
		core.update_position(1,Vector3(0,2,0))
		check(command("surface_analyze",{"form_id":sample.form_id}).ok,"paid basic analysis "+environment)
		for resource in ["iron","copper","stone","ice"]:mine_resource(resource,{"iron":230,"copper":140,"stone":100,"ice":80}[resource])
		core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
		for key in ["robotics","atmosphere","thermal","water","biotech"]:check(command("business_technology",{"technology":key}).ok,"foundation technology "+key)
		build("solar");var factory:=build("factory")
		var key: String={"basalt":"mineral_scaffold","cold":"thermal_exchange","arid":"water_membrane"}[environment]
		var target:=build(FrontierFieldEngineering.definition(key).building)
		if failures:quit(1);return
		FrontierExpeditionIndustry.tick(core.world,1)
		core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).buildings[factory].position)+Vector3(0,0,4))
		var args: Dictionary={"project":key,"building_id":factory}
		var before:=FrontierUniverse.fingerprint(core.world);disk_ok=false
		check(not command("business_research_prototype",args).ok and FrontierUniverse.fingerprint(core.world)==before,"prototype write failure rolls back both materials and record")
		disk_ok=true
		var replay:=envelope(core,1,"business_research_prototype",args)
		check(core.request(1,replay).ok,"prototype starts from scanned and analyzed evidence "+key)
		before=FrontierUniverse.fingerprint(core.world)
		check(core.request(1,replay).ok and FrontierUniverse.fingerprint(core.world)==before,"repeated request cannot consume more material")
		check(not command("business_demolish",{"building_id":factory}).ok,"cannot demolish running prototype facility")
		check(command("business_toggle",{"building_id":factory}).ok,"pause fabrication power")
		for i in 10:FrontierExpeditionIndustry.tick(core.world,1)
		check(core.world.engineering.projects[key].progress==0,"unpowered experiment cannot progress")
		var cancelled_inventory: Dictionary=FrontierExpeditionBusiness.site(core.world).inventory.duplicate()
		check(command("business_research_cancel",args).ok,"unpowered experiment can be cancelled")
		check(not core.world.engineering.projects.has(key) and FrontierExpeditionBusiness.site(core.world).inventory==cancelled_inventory,"cancellation never refunds spent test inputs")
		check(command("business_toggle",{"building_id":factory}).ok,"restore fabrication power")
		FrontierExpeditionIndustry.tick(core.world,1)
		check(command("business_research_prototype",args).ok,"cancelled prototype can restart with new materials")
		var ship_lab:=core.world.duplicate(true)
		ship_lab.vessel=FrontierVesselRefit.create(int(ship_lab.manifest.seed),ship_lab.crew.world_id)
		ship_lab.vessel.loadout.utility=FrontierVesselRefit.add_module(ship_lab.vessel,"lab","standard")
		var plain_lab:=core.world.duplicate(true)
		FrontierExpeditionIndustry.tick(ship_lab,1);FrontierExpeditionIndustry.tick(plain_lab,1)
		check(is_equal_approx(ship_lab.engineering.projects[key].progress,plain_lab.engineering.projects[key].progress*1.15),"installed mobile lab accelerates actual powered prototype")
		for i in 30:FrontierExpeditionIndustry.tick(core.world,1)
		check(core.world.engineering.projects[key].stage=="prototype_ready","powered prototype completes")
		core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).buildings[target].position)+Vector3(0,0,4))
		check(not command("business_research_install",{"project":key,"building_id":target}).ok,"untested prototype cannot modify production")
		check(command("business_research_trial",{"project":key,"building_id":target}).ok,"field trial starts in correct real facility")
		check(not command("business_demolish",{"building_id":target}).ok,"cannot remove live field trial")
		if environment=="basalt":
			for i in 5:FrontierExpeditionIndustry.tick(core.world,1)
			check(core.world.engineering.projects[key].progress==0,"biological trial waits for viable culture conditions")
			check(command("business_research_cancel",{"project":key,"building_id":target}).ok and core.world.engineering.projects[key].stage=="prototype_ready","blocked trial can stop while retaining prototype knowledge")
			check(command("business_research_trial",{"project":key,"building_id":target}).ok,"trial can restart after paying new test inputs")
			# Controlled climate fixture isolates quantitative retrofit behavior; actual game route runs the facilities.
			FrontierExpeditionBusiness.site(core.world).environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":70.0,"ecology":0.0,"stable_seconds":0.0}
		for i in 30:FrontierExpeditionIndustry.tick(core.world,1)
		check(core.world.engineering.projects[key].stage=="certified","material-fed field trial certifies "+key)
		check(command("business_research_install",{"project":key,"building_id":target}).ok,"pay for retrofit of one facility")
		check(not command("business_research_install",{"project":key,"building_id":target}).ok,"same facility cannot stack modifier")
		var upgraded: Dictionary=core.world.duplicate(true);var baseline: Dictionary=core.world.duplicate(true)
		FrontierExpeditionBusiness.site(baseline).buildings[target].erase("engineering")
		for w in [upgraded,baseline]:
			FrontierExpeditionBusiness.site(w).environment={"temperature":-40.0 if environment=="cold" else 18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":60.0,"ecology":0.0,"stable_seconds":0.0}
			FrontierExpeditionBusiness.site(w).buildings[target].work=0.0
		for i in 30:FrontierExpeditionIndustry.tick(upgraded,1);FrontierExpeditionIndustry.tick(baseline,1)
		var metric: String={"basalt":"ecology","cold":"temperature","arid":"water"}[environment]
		check(FrontierExpeditionBusiness.site(upgraded).environment[metric]>FrontierExpeditionBusiness.site(baseline).environment[metric],"retrofit changes actual "+metric+" output")
		check(FrontierUniverse.validate_world(core.world).is_empty(),"complete research save validates")
		var invalid:=core.world.duplicate(true);invalid.engineering.projects[key].stage="prototype_ready"
		check(not FrontierUniverse.validate_world(invalid).is_empty(),"save rejects uncertified installed retrofit")
		var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner_id)
		check(FrontierCrewSurfaceReplica.validate(packet,core.world.manifest),"research and facility replica validates")
		var restarted:=FrontierCrewAuthority.new()
		check(restarted.start(JSON.parse_string(JSON.stringify(core.world)),owner,persist),"research survives saved-world reload")
		check(restarted.world.engineering.projects[key].source_body==core.world.location and restarted.world.engineering.projects[key].form_id==sample.form_id,"reloaded prototype keeps original biological evidence")
		check(core.close(),"research world closes")
	print("FIELD_ENGINEERING_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
