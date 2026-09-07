extends "res://tests/check_facility_interactions.gd"
## Bounded rendered review of accepted mining, survey, weapon and cancellation.
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
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	app.close_menus();app.session.send_request("business_register",{})
	var id: String=app.session.latest.self_id
	if FrontierEquipment.state(app.session.latest.crew.members[id]).items.is_empty():app.session.send_request("equipment_craft",{"definition":"miner_1"})
	app.session.send_request("equipment_equip",{"item_id":"crafted:1","slot":0})
	await create_timer(.3).timeout
	var vein: Dictionary={}
	for row in FrontierExpeditionBusiness.veins(app.surface_world.body,app.camera.position):
		if row.resource!="iron":continue
		point=FrontierMineralWorld.point(app.surface_world.terrain.field,row)
		if not point.is_finite():continue
		var ground:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,point.x,point.z+3)
		if not ground.is_finite():continue
		vein=row;move_to(ground+Vector3.UP*.2);break
	if vein.is_empty():check(false,"reachable iron fixture");quit(1);return
	await create_timer(.5).timeout
	app.camera.look_at(point+Vector3.UP*.65);app.yaw=app.camera.rotation.y;app.pitch=app.camera.rotation.x
	await create_timer(.2).timeout
	await capture("idle")
	var before: int=int(FrontierExpeditionBusiness.site(app.session.authority.world).remaining.get(vein.id,vein.capacity))
	for cycle in 3:
		app.use_equipped()
		await create_timer(.28).timeout
		if cycle==1:
			check(app.feedback.intake_strength>.8 and app.feedback.recoil<.01,"braced extractor at speed without impact recoil")
			check(app.feedback.optics.flow.visible and app.feedback.audio.suction.playing,"intake geometry and ElevenLabs fan loop active")
			await capture("suction")
		await create_timer(.35).timeout
	check(int(FrontierExpeditionBusiness.site(app.session.authority.world).remaining.get(vein.id,vein.capacity))<before,"aimed mining consumes authoritative ore")
	check(not app.feedback.audio.last_played.has("sfx_mine_hit_metal"),"mining does not play pickaxe impact")
	app.test_scan=true
	check(await until(func():return float(app.session.latest.get("scan",{}).get("progress",0))>.35,12),"host survey progresses")
	await capture("survey")
	check((app.feedback.optics.scan_shell.visible or not app.feedback.optics.overlays.is_empty()) and app.feedback.audio.survey.playing,"survey optics and charging sound active")
	check(await until(func():return app.session.latest.get("scan",{}).get("known",false),12),"host confirms mineral survey")
	await process_frame;check(not app.feedback.optics.overlays.is_empty(),"completion keeps target surface illuminated");await capture("survey-complete");app.test_scan=false
	app.session.authority.world.business.bags[id]=FrontierExpeditionBusiness.inventory()
	app.session.authority.world.business.bags[id].iron=6
	app.session.authority.world.business.bags[id].copper=4
	app.session.send_request("equipment_craft",{"definition":"pulse_1"})
	app.session.send_request("equipment_equip",{"item_id":"crafted:2","slot":1})
	app.session.send_request("equipment_select",{"slot":1});await create_timer(.4).timeout
	var shots: int=app.feedback.effects.emitted.pulse
	app.use_equipped();await create_timer(.04).timeout
	check(app.feedback.effects.emitted.pulse==shots+1 and app.feedback.recoil>.1,"accepted pulse uses distinct spring recoil")
	await capture("pulse")
	app.session.send_request("equipment_select",{"slot":0});await create_timer(.3).timeout
	app.use_equipped();await create_timer(.2).timeout
	app.toggle_inventory();await create_timer(.1).timeout
	check(not app.feedback.handheld.visible and not app.feedback.optics.flow.visible and not app.feedback.audio.suction.playing,"menu immediately stops extractor")
	app.close_menus();await create_timer(.2).timeout
	check(not app.feedback.optics.flow.visible,"closing menu does not resume stale suction")
	check(await app.session.close_session(),"isolated world saved")
	print("FIELD_TOOL_FAILURES ",failures);quit(1 if failures else 0)
