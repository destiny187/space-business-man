extends "res://tests/test_solo_entry.gd"
## One isolated T2 production-to-upgrade smoke, using real host commands and Metal UI.
var owner: String
func world() -> Dictionary:return app.session.authority.world
func site() -> Dictionary:return FrontierExpeditionBusiness.site(world())
func move_to(p: Vector3) -> void:
	app.actors[owner].position=p;app.session.authority.update_position(1,p)
func command(kind: String,args: Dictionary={}) -> void:
	app.session.send_request(kind,args)
func make(product: String,times: int=1) -> void:
	for i in times:
		move_to(FrontierCrewWorld.vector(site().buildings["fixture:factory"].position)+Vector3(0,0,3))
		command("business_produce",{"building_id":"fixture:factory","product":product})
		if site().buildings["fixture:factory"].get("production",{}).is_empty():check(false,"production starts "+product);return
		for j in 9:FrontierExpeditionIndustry.tick(world(),1.0)
func take(product: String,amount: int) -> void:
	move_to(FrontierCrewWorld.vector(site().center))
	command("business_withdraw",{"resource":product,"amount":amount})
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	assert("--crew-ui-test" in OS.get_cmdline_user_args())
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800)
	var initial:=FrontierUniverse.new_world(112052220)
	var destination: Dictionary={}
	for ordinal in range(8,100000,71):
		var candidate:=FrontierUniverse.body(initial.manifest,ordinal)
		if int(candidate.planet_tier)==2 and FrontierUniverse.landable(candidate):destination=candidate;break
	check(not destination.is_empty(),"seed has landable T2 destination")
	if destination.is_empty():quit(1);return
	initial.location=destination.id
	var ordinal:=FrontierUniverse.ordinal_of(initial.manifest,destination.id)
	var p:=FrontierUniverse.position(initial.manifest,ordinal)+Vector3(0,0,FrontierUniverse.radius(destination)+float(initial.manifest.settings.flight.arrival_clearance))
	initial.flight_position=FrontierExpeditionBusiness.array(p)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	check(app.world_store.write(initial),"isolated destination saved")
	app.start_solo(true)
	if not await until(func():return app.session.active,"solo host starts",20):quit(1);return
	app.travel_action("land")
	print("LAND_STATUS ",app.status.value)
	if not await until(func():return app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"T2 landing streams",60):quit(1);return
	if not await until(func():return not app.arrival.active,"arrival hands over field controls",60):quit(1);return
	owner=app.session.latest.self_id
	command("business_register")
	check(site().has("restoration2"),"new T2 contract has salinity and soil requirements")
	# Supply and placed machinery fixture isolate new progression from established mining/build costs.
	site().inventory={"iron":500,"copper":500,"stone":500,"ice":500,"crystal":0}
	world().business.technologies=FrontierExpeditionBusiness.config().technologies.duplicate()
	var index:=0
	for kind in ["solar","solar","solar","factory","water","biolab","thermal","charger","atmosphere"]:
		var placed:=false
		for x in range(-36,25,7):
			for z in range(-30,25,7):
				p=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(world()),x,z,float(FrontierCatalog.entry("buildings",kind).radius))
				if not p.is_finite() or not FrontierExpeditionBusiness.placement(world(),kind,p,app.session.authority.peers).is_empty():continue
				var key: String="fixture:"+kind if kind!="solar" else "fixture:solar"+str(index)
				site().buildings[key]={"id":key,"type":kind,"position":FrontierExpeditionBusiness.array(p),"yaw":0.0,"enabled":true,"active":false,"status":"대기","work":0.0};placed=true;index+=1;break
			if placed:break
		check(placed,"supported "+kind+" fixture")
	FrontierExpeditionIndustry.tick(world(),1)
	make("refined_iron",25);make("refined_copper",22);make("reinforced_frame",11);make("control_circuit",8);make("heat_transfer_unit",6);make("mineral_filter",8);make("soil_base",8)
	check(int(site().inventory.get("reinforced_frame",0))==11 and int(site().inventory.get("control_circuit",0))==8,"raw inputs produce shared parts into warehouse")
	var factory: Dictionary=site().buildings["fixture:factory"]
	move_to(FrontierCrewWorld.vector(factory.position)+Vector3(0,0,3));command("business_produce",{"building_id":factory.id,"product":"refined_iron"})
	factory=site().buildings["fixture:factory"];factory.enabled=false
	FrontierExpeditionIndustry.tick(world(),1);check(float(factory.production.progress)==0,"disabled factory pauses reserved production")
	factory.enabled=true
	for i in 5:FrontierExpeditionIndustry.tick(world(),1)
	for resource in ["reinforced_frame","control_circuit","heat_transfer_unit"]:take(resource,3)
	var gear: Dictionary=FrontierEquipment.state(world().crew.members[owner]);var starter: String=gear.slots[0]
	command("equipment_upgrade",{"item_id":starter})
	check(FrontierEquipment.state(world().crew.members[owner]).items[starter]=="miner_2" and FrontierEquipment.state(world().crew.members[owner]).slots[0]==starter,"miner upgrade preserves identity and equipped slot")
	take("iron",10);take("copper",4);take("stone",3)
	command("equipment_craft",{"definition":"pulse_1"});command("equipment_craft",{"definition":"terrain_1"})
	gear=FrontierEquipment.state(world().crew.members[owner])
	for id in gear.items.keys():
		if gear.items[id] in ["pulse_1","terrain_1"]:command("equipment_upgrade",{"item_id":id})
	check("pulse_2" in FrontierEquipment.state(world().crew.members[owner]).items.values() and "terrain_2" in FrontierEquipment.state(world().crew.members[owner]).items.values(),"weapon and terrain tool upgrade through products")
	take("reinforced_frame",1);command("equipment_suit_upgrade")
	check(int(FrontierEquipment.state(world().crew.members[owner]).get("suit_tier",1))==2,"suit takes one permanent retrofit")
	var before:=FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.bag(world(),owner));command("equipment_upgrade",{"item_id":starter})
	check(FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.bag(world(),owner))==before,"repeat upgrade cannot spend twice")
	for kind in ["water","biolab"]:
		move_to(FrontierCrewWorld.vector(site().buildings["fixture:"+kind].position)+Vector3(0,0,3));command("business_facility_upgrade",{"building_id":"fixture:"+kind})
	check(int(site().buildings["fixture:water"].get("tier",1))==2 and int(site().buildings["fixture:biolab"].get("tier",1))==2,"water and biolab retrofit uses common stock")
	site().environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":80.0,"ecology":0.0,"stable_seconds":0.0}
	check(not FrontierProductionTier2.restoration_ready(site()),"normal environment alone cannot bypass T2 requirements")
	for i in 40:FrontierExpeditionIndustry.tick(world(),1)
	check(FrontierProductionTier2.restoration_ready(site()) and float(site().environment.ecology)>0,"filters and soil products unlock actual ecology")
	var robot_id: String="fixture:robot"
	site().robots[robot_id]={"id":robot_id,"grade":"standard","position":site().center.duplicate(),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":[],"status":"대기","work":0.0,"charging":false}
	move_to(FrontierCrewWorld.vector(site().center));command("business_robot_upgrade",{"robot_id":robot_id})
	check(FrontierProductionTier2.robot_capacity(site().robots[robot_id])==64,"robot retrofit increases actual carrying capacity")
	move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));command("vessel_build",{"module_type":"drive"})
	if world().get("vessel",{}).get("modules",{}).is_empty():check(false,"ship module build")
	else:
		var module_id: String=world().vessel.modules.keys()[0]
		command("vessel_upgrade",{"module_id":module_id});command("vessel_equip",{"module_id":module_id})
		check(world().vessel.modules[module_id].grade=="improved" and is_equal_approx(float(FrontierVesselRefit.stats(world()).speed),1.2),"first ship upgrade uses manufactured parts without lottery parts")
	move_to(FrontierCrewWorld.vector(site().center));command("business_deposit")
	await create_timer(1).timeout
	app.toggle_business();await capture("production-ui")
	app.business_panel.production_panel.selected_product="control_circuit";app.business_panel.production_panel.refresh();await capture("circuit-ui")
	app.business_panel.hide();app.toggle_inventory();app.inventory_panel.tabs.current_tab=0;await capture("equipment-mk2")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await capture("equipment-960")
	app.inventory_panel.hide();app.toggle_business();await capture("production-960")
	check(app.feedback.audio.last_played.has("sfx_factory_complete"),"accepted upgrades play existing ElevenLabs completion audio")
	check(FrontierUniverse.validate_world(world()).is_empty(),"extended host state passes save validation")
	check(await app.session.close_session(),"host saves products upgrades and restoration")
	var restored:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not restored.is_empty() and FrontierEquipment.state(restored.crew.members[owner]).items[starter]=="miner_2" and FrontierProductionTier2.restoration_ready(FrontierExpeditionBusiness.site(restored)),"saved upgrade identity and restoration survive reload")
	print("TIER2_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
