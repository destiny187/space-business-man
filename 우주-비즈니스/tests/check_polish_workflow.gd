extends "res://tests/test_solo_entry.gd"
const Guide=preload("res://scripts/ui/work_guidance.gd")
var results: Array=[]
func world() -> Dictionary:return app.session.authority.world
func site() -> Dictionary:return FrontierExpeditionBusiness.site(world())
func move_to(p: Vector3) -> void:
	app.actors[app.session.latest.self_id].position=p;app.session.authority.update_position(1,p)
func run() -> void:
	var source:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
		if arg.begins_with("--source-folder="):source=arg.trim_prefix("--source-folder=")
	assert(not folder.is_empty() and not source.is_empty() and source!=folder)
	DirAccess.make_dir_recursive_absolute(folder)
	for file in ["world.json","profile.json"]:assert(DirAccess.copy_absolute(source+"/"+file,folder+"/"+file)==OK)
	var store:=FrontierWorldStore.new(folder+"/world.json");var initial:=store.read_state()
	var prepared: Dictionary=initial.business.sites[initial.location]
	var factory_id:="t3:play:2";var factory: Dictionary=prepared.buildings[factory_id]
	var region: Dictionary=prepared.regions[factory.region_id]
	region.inventory.iron=80
	FrontierExpeditionBusiness.transfer(region.inventory,FrontierProductionTier2.robot_recipe().cost,1)
	check(store.write(initial),"prepared materials in isolated saved site")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not app.preparing_first_snapshot and not app.arrival.active,"existing site ready",120):quit(1);return
	app.session.response_received.connect(func(_seq: int,result: Dictionary):results.append(result))
	move_to(FrontierCrewWorld.vector(factory.position)+Vector3(0,1,3));await create_timer(1.2).timeout
	Guide.navigate(app,{"kind":"factory","product":"refined_iron"})
	var production:=app.business_panel.production_panel
	check(app.business_panel.visible and app.business_panel.context_id==factory_id,"use link opens reachable physical factory")
	check(not production.produce.disabled and production.maximum.text.contains("최대"),"prepared recipe and safe maximum visible")
	if "--layout-only" in OS.get_cmdline_user_args():
		root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("production-ready-960")
		check(production.ingredients.get_global_rect().size.y>20 and production.ingredients.get_global_rect().end.y<640,"material counts remain visible in small window")
		check(production.preview.get_parent().get_parent().get_parent().size.y>50,"recipe detail has scrollable height")
		app.business_panel.confirm_settlement(false);await capture("settlement-960")
		await app.session.close_session();app.queue_free();await process_frame;print("POLISH_LAYOUT failures=",failures);quit(1 if failures else 0);return
	production.batches.value=2;production.produce.pressed.emit()
	check(not production.pending.is_empty() and production.produce.disabled,"submitted production waits for host confirmation")
	await until(func():return production.pending.is_empty(),"production transaction confirmed",12)
	check(not results.is_empty() and results.back().get("ok",false),"shared host eligibility accepts selected batch")
	await capture("production")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("production-960")
	check(production.produce.get_global_rect().end.y<640,"production action fits small window")
	await until(func():return site().buildings[factory_id].get("production",{}).is_empty(),"two actual batches finish",15)
	var local:=FrontierRegionalTerraform.facade(site(),factory.region_id)
	check(int(local.inventory.get("refined_iron",0))>=4,"confirmed output reaches local warehouse")
	var before_inventory: Dictionary=local.inventory.duplicate()
	var body: Dictionary=app.surface_world.body
	var max_batches:=FrontierProductionTier2.available_batches(local,factory_id,FrontierProductionTier2.product("refined_iron"),body)
	check(max_batches>0 and local.inventory==before_inventory,"maximum quote is read-only")
	var constrained:=local.duplicate(true);constrained.slot_capacity=0
	check(FrontierProductionTier2.available_batches(constrained,factory_id,FrontierProductionTier2.product("refined_iron"),body)==0,"maximum includes warehouse output space")
	constrained=local.duplicate(true);constrained.inventory.iron=0
	check(FrontierProductionTier2.recipe_reason(constrained,factory_id,FrontierProductionTier2.product("refined_iron"),body).contains("재료"),"missing local materials remain blocked")
	app.session.send_request("business_craft",{"building_id":factory_id})
	await until(func():return not site().jobs.is_empty(),"robot assembly reserved",10)
	await until(func():return not site().robots.is_empty(),"robot finishes actual assembly",45)
	if not site().robots.is_empty():
		var robot_id: String=site().robots.keys()[0];var robot: Dictionary=site().robots[robot_id]
		move_to(FrontierCrewWorld.vector(robot.position)+Vector3(0,1,3));await create_timer(.8).timeout
		app.open_station("robot",robot_id)
		check(not robot.get("auto_enabled",false),"new robot waits for explicit work")
		check(is_equal_approx(app.business_panel.robot_energy.value,float(robot.battery)),"robot gauge uses host battery")
		await capture("robot-960")
		app.session.send_request("business_robot_auto",{"robot_id":robot_id,"enabled":true,"resource":""})
		await until(func():return site().robots[robot_id].get("auto_enabled",false),"explicit robot auto selection confirmed",10)
		check(Guide.robot_action({"status":"창고 가득 참 · 하역 대기"}).kind=="warehouse","actual warehouse stall links to cargo")
		check(Guide.robot_action({"status":"전원이 켜진 충전기 필요"}).kind=="power","actual charger stall links to supply")
	app.close_menus();app.business_panel.set_context("ship");app.open_menu(app.business_panel)
	app.business_panel.update(app.session.surface.business,app.surface_world.body.id,app.session.latest.self_id,int(body.planet_tier),{}, {},body)
	app.business_panel.confirm_settlement(false);await capture("settlement-960")
	for child in app.business_panel.get_children():
		if child is ConfirmationDialog:check(child.dialog_text.contains("이미 받은") and child.dialog_text.contains("재고"),"settlement distinguishes paid amounts and actual assets");child.queue_free()
	app.close_menus();app.planet_map.modes.current_tab=1;app.open_menu(app.planet_map);app.planet_map.terraform.layer=1;app.planet_map.terraform.chosen=Vector2(site().buildings["t3:play:3"].position[0],site().buildings["t3:play:3"].position[2]);app.planet_map.refresh();await capture("environment-960")
	check(app.planet_map.terraform.facility_link.visible,"actual water plant linked to affected environment")
	var notification: Dictionary={"phase":"playing","business":{"credits":100,"sites":{"audit":{"regional_paid":{"stage:1":20},"settlement":{}}}}}
	app.feedback.cue_left=0;app.feedback._business_snapshot(notification)
	check(app.feedback.cue_left==0,"first receipt snapshot does not replay prior rewards")
	notification.business.sites.audit.regional_paid["stage:2"]=20;app.feedback._business_snapshot(notification)
	check(app.feedback.cue_left>0,"new confirmed stage produces one concise cue")
	app.feedback.cue_left=0;app.feedback._business_snapshot(notification);check(app.feedback.cue_left==0,"repeated snapshot does not replay stage")
	check(await app.session.close_session(),"modified workflow saves actual site")
	app.queue_free();await process_frame
	print("POLISH_WORKFLOW checks=",checks," failures=",failures);quit(1 if failures else 0)
