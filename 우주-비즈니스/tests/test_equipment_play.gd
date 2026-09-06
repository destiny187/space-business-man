extends "res://tests/test_solo_entry.gd"
## One isolated rendered smoke flow for inventory/crafting/equipment. No user save touched.
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(112052220))
	app.start_solo(true)
	if not await until(func():return app.session.active,"isolated solo opens",15):quit(1);return
	app.travel_action("land")
	if not await until(func():return app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"earth landing streams",60):quit(1);return
	var id: String=app.session.latest.self_id
	app.session.send_request("business_register",{})
	check(app.session.authority.world.has("business"),"field ledger available")
	app.toggle_inventory();await capture("inventory-new")
	app.session.send_request("equipment_craft",{"definition":"miner_1"})
	app.session.send_request("equipment_equip",{"item_id":"crafted:1","slot":0})
	app.inventory_panel.hide();await create_timer(.3).timeout
	check(FrontierEquipment.active(app.session.latest.crew.members[id]).get("kind")=="miner" and app.feedback.handheld.visible,"crafted miner equipped and rendered")
	var world: Dictionary=app.session.authority.world
	# Small recipe fixture isolates material spending from the existing industry loop.
	world.business.bags[id]={"iron":24,"copper":16,"stone":5,"ice":0,"crystal":4}
	var before:=FrontierExpeditionBusiness.total(world.business.bags[id])
	app.session.send_request("equipment_craft",{"definition":"terrain_1"})
	check(FrontierExpeditionBusiness.total(app.session.authority.world.business.bags[id])==before-7,"craft consumes exact carried recipe")
	app.session.send_request("equipment_equip",{"item_id":"crafted:2","slot":2})
	app.session.send_request("equipment_craft",{"definition":"pulse_1"})
	app.session.send_request("equipment_equip",{"item_id":"crafted:3","slot":1})
	app.session.send_request("equipment_craft",{"definition":"miner_2"})
	app.session.send_request("equipment_equip",{"item_id":"crafted:4","slot":3})
	app.session.send_request("equipment_select",{"slot":2});await create_timer(.35).timeout
	check(app.feedback.equipped_model=="equipment/terrain_shaper","terrain model separate")
	app.pitch=-1.2;await create_timer(.2).timeout
	var edits: int=app.session.surface.edits.size();app.surface_action("surface_dig")
	check(app.session.surface.edits.size()==edits+1,"equipped terrain tool changes actual terrain")
	check(app.feedback.audio.last_played.has("sfx_combat_pulse"),"confirmed action plays ElevenLabs source")
	await capture("terrain-action")
	app.pitch=0;app.session.send_request("equipment_select",{"slot":1});await create_timer(.4).timeout
	check(app.feedback.equipped_model=="equipment/pulse_carbine","attack model separate")
	app.use_equipped()
	check(app.feedback.effects.emitted.pulse>0,"equipped pulse fires through host transaction")
	await capture("pulse-equipped")
	# Real vein gate against the authoritative current planet, with position fixture.
	var vein: Dictionary={}
	for row in FrontierExpeditionBusiness.veins(app.surface_world.body):
		if row.resource=="crystal" and FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(app.session.authority.world),row.position[0],row.position[2]).is_finite():vein=row;break
	if vein.is_empty():check(false,"fixture needs a reachable crystal vein");quit(1);return
	var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(app.session.authority.world),vein.position[0],vein.position[2])
	app.actors[id].position=p+Vector3(0,.25,0);app.session.authority.update_position(1,app.actors[id].position)
	app.session.send_request("equipment_select",{"slot":0})
	var remaining: int=int(FrontierExpeditionBusiness.site(app.session.authority.world).remaining[vein.id])
	app.session.send_request("business_mine",{"vein_id":vein.id})
	check(int(FrontierExpeditionBusiness.site(app.session.authority.world).remaining[vein.id])==remaining,"low grade cannot mine crystal")
	app.session.send_request("equipment_select",{"slot":3})
	app.session.send_request("business_mine",{"vein_id":vein.id})
	check(int(FrontierExpeditionBusiness.site(app.session.authority.world).remaining[vein.id])==remaining-4,"grade two mines four actual crystals: "+app.status.value)
	app.actors[id].position=Vector3(0,3,0);app.session.authority.update_position(1,app.actors[id].position)
	app.toggle_inventory();app.inventory_panel.tabs.current_tab=1
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await capture("inventory-960")
	check(app.inventory_panel.get_global_rect().end.x<=960 and app.inventory_panel.hotbar.get_global_rect().end.x<=960,"inventory and five slots fit small viewport")
	edits=app.session.surface.edits.size();app.surface_action("surface_dig")
	check(app.session.surface.edits.size()==edits and not app.feedback.handheld.visible,"inventory blocks field action and model")
	app.inventory_panel.tabs.current_tab=0;await capture("owned-960")
	var retained:=FrontierEquipment.state(app.session.latest.crew.members[id]).duplicate(true)
	check(await app.session.close_session(),"equipment world saved")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and saved.crew.members[id].loadout.items==retained.items and saved.crew.members[id].loadout.slots==retained.slots and int(saved.crew.members[id].loadout.selected)==int(retained.selected) and int(saved.crew.members[id].loadout.kit)==int(retained.kit),"items and slots survive save reload")

	var resumed:=FrontierCrewAuthority.new()
	check(resumed.start(saved,saved.crew.members[id].profile,func(_value: Dictionary):return true) and FrontierEquipment.active(resumed.world.crew.members[id]).get("tier")==2,"host restart retains selected crafted grade")
	print("EQUIPMENT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
