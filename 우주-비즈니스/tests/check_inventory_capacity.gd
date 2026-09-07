extends "res://tests/check_facility_interactions.gd"
## Small actual-window check; no travel/terrain setup or user saves.
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(71491));app.start_solo()
	if not await until(func():return app.session.active,15):check(false,"session starts");quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	var id: String=app.session.latest.self_id
	move_to(FrontierCrewWorld.vector(FrontierCrewWorld.config().locker_position))
	app.session.authority.world.crew.rock=2000
	app.session._publish()
	app.toggle_inventory();await create_timer(.4).timeout
	var panel:=app.inventory_panel
	check(FrontierItemInventory.capacity(app.session.latest.crew.members[id])==8 and panel.owned.get_child_count()==8,"fresh character has exactly eight inventory tiles")
	check(panel.tabs.current_tab==0 and panel.owned.columns==4 and panel.hotbuttons.size()==5,"four by two inventory and five equipment shortcuts")
	await capture("inventory-eight-1280")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.3).timeout
	check(panel.detail.get_global_rect().end.x<=936 and panel.owned.get_child_count()==8 and panel.owned.columns==4 and panel.owned.get_child(7).get_global_rect().end.y<=panel.tabs.get_global_rect().end.y,"960px layout fits all eight slots")
	await capture("inventory-eight-960")
	app.session.send_request("withdraw",{"amount":699});await process_frame
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).stone)==699,"seven resource stacks plus starting equipment fit")
	app.session.send_request("withdraw",{"amount":1})
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).stone)==700,"full inventory accepts last unit of partial stack")
	var shared: int=app.session.authority.world.crew.rock
	app.session.send_request("withdraw",{"amount":1})
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).stone)==700 and int(app.session.authority.world.crew.rock)==shared,"ninth slot denied without consuming warehouse stock")
	# Simulate an old valid save: capacity field absent, nine full cargo stacks.
	app.session.authority.world.crew.members[id].loadout.erase("inventory_slots")
	app.session.authority.world.business.bags[id].stone=900
	app.session._publish();await create_timer(.2).timeout
	app.session.send_request("equipment_select",{"slot":0})
	check(app.world_store.read_state().business.bags[id].stone==900,"old over-capacity cargo still saves without loss")
	check(panel.owned.get_child_count()==10 and panel.capacity_text.text.contains("10 / 8"),"overflow shows every item and actual ten-of-eight count")
	await capture("inventory-legacy-overflow")
	app.session.send_request("withdraw",{"amount":1})
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).stone)==900,"overflow cannot gain more cargo")
	app.session.send_request("deposit",{"amount":900})
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).stone)==0,"legacy overflow can be returned to storage")
	# Future host-owned expansion field: no purchase route is introduced by this change.
	app.session.authority.world.crew.members[id].loadout.inventory_slots=16
	app.session.send_request("withdraw",{"amount":800});await create_timer(.2).timeout
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).stone)==800 and panel.owned.get_child_count()==16,"host capacity field controls transactions and UI together")
	var saved:=app.world_store.read_state()
	check(int(saved.crew.members[id].loadout.inventory_slots)==16,"expanded capacity persists in saved loadout")
	var malformed: Dictionary=saved.crew.members[id].loadout.duplicate(true);malformed.inventory_slots=8.5
	check(not FrontierEquipment.validate(malformed).is_empty(),"fractional capacity is rejected")
	check(await app.session.close_session(),"isolated inventory session closes and saves")
	print("INVENTORY_CAPACITY_FAILURES ",failures);quit(1 if failures else 0)
