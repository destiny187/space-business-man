extends "res://tests/check_facility_interactions.gd"
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
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create();world.business.bags[id]=FrontierExpeditionBusiness.inventory();world.business.bags[id].iron=120
	world.crew.rock=0;app.session._publish()
	app.toggle_inventory();app.inventory_panel.tabs.current_tab=2;await create_timer(.4).timeout
	var panel:=app.inventory_panel
	check(panel.storage_owned.get_child_count()==8 and panel.cargo.get_child_count()==10,"eight personal and ten shared ship slots")
	var source: FrontierItemTile=panel.storage_owned.get_child(1)
	var target: FrontierItemTile=panel.cargo.get_child(0)
	var payload: Dictionary=source.cargo_payload
	check(target._can_drop_data(Vector2.ZERO,payload),"resource drag accepted by opposite grid")
	var from:=source.get_global_rect().get_center();var to:=target.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=from;motion.global_position=from;Input.parse_input_event(motion);await process_frame
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=from;press.global_position=from;Input.parse_input_event(press);await process_frame
	for step in range(1,7):
		motion=InputEventMouseMotion.new();motion.position=from.lerp(to,float(step)/6);motion.global_position=motion.position;motion.relative=(to-from)/6;motion.button_mask=MOUSE_BUTTON_MASK_LEFT;Input.parse_input_event(motion);await process_frame
	press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=false;press.position=to;press.global_position=to;Input.parse_input_event(press);await process_frame
	check(app.feedback.audio.last_played.has("sfx_pickup_resource"),"approved ship transfer plays existing ElevenLabs pickup sound")
	check(int(app.session.authority.world.crew.cargo.iron)==100 and int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).iron)==20,"drag deposits only selected stack")
	await create_timer(.2).timeout
	panel._transfer_cargo({"equipment_item":panel.data.items.keys()[0],"source":"bag"});await create_timer(.2).timeout
	check(app.session.authority.world.crew.cargo_equipment.size()==1 and panel.data.items.is_empty(),"equipment stored and unequipped without losing identity")
	var stored: Dictionary=app.session.authority.world.crew.cargo_equipment.values()[0]
	panel._transfer_cargo({"equipment_item":stored.item_id,"source":"warehouse"});await create_timer(.2).timeout
	check(panel.data.items.has(stored.item_id),"equipment owner recovers original item")
	# New quick UI path: Shift-click one stack, then selected quantity withdrawal.
	var quick_tile: FrontierItemTile=null
	for tile in panel.storage_owned.get_children():
		if tile.cargo_payload.get("resource")=="iron":quick_tile=tile;break
	var shift:=InputEventKey.new();shift.physical_keycode=KEY_SHIFT;shift.pressed=true;Input.parse_input_event(shift);await process_frame
	quick_tile.pressed.emit();shift.pressed=false;Input.parse_input_event(shift);await create_timer(.2).timeout
	check(int(app.session.authority.world.crew.cargo.iron)==120,"Shift click transfers remaining stack")
	for tile in panel.cargo.get_children():
		if tile.cargo_payload.get("resource")=="iron":tile.pressed.emit();break
	panel.transfer_count.value=20;panel.transfer_button.pressed.emit();await create_timer(.2).timeout
	check(int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).iron)==20,"selected quantity button withdraws to backpack")
	app.session.authority.world.business.bags[id].copper=15;app.session._publish()
	app.session.send_request("deposit",{"all_resources":true});await create_timer(.2).timeout
	check(int(app.session.authority.world.crew.cargo.copper)==15 and panel.data.items.has(stored.item_id),"bulk deposits resources and preserves equipment")
	app.session.send_request("withdraw",{"resource":"iron","amount":20});await create_timer(.2).timeout
	app.session.authority.world.crew.cargo.erase("copper");app.session._publish()
	await capture("ship-storage-1280")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await create_timer(.3).timeout
	check(panel.cargo.get_child(9).get_global_rect().end.x<936 and panel.cargo.get_child(9).get_global_rect().end.y<panel.tabs.get_global_rect().end.y,"ten slots fit small window")
	await capture("ship-storage-960")
	world=app.session.authority.world;world.crew.cargo.iron=1000;app.session._publish()
	app.session.send_request("deposit",{"resource":"iron","amount":1})
	check(int(app.session.authority.world.crew.cargo.iron)==1000,"full ship refuses extra resource")
	check(app.feedback.audio.last_played.has("sfx_build_invalid"),"rejected ship transfer plays failure sound")
	app.session.send_request("withdraw",{"resource":"iron","amount":100})
	check(int(app.session.authority.world.crew.cargo.iron)==900,"full ship permits withdrawal")
	app.close_menus();app.outside=false
	var before:=app.yaw
	app._mouse_look(Vector2(100,0),.0025,false)
	check(is_equal_approx(app.yaw,before-.25) and is_equal_approx(app.camera.rotation.y,app.yaw),"FPS look updates camera immediately without smoothing")
	app._mouse_look(Vector2(0,100000),.0025,false)
	check(is_equal_approx(app.pitch,deg_to_rad(-89)),"FPS pitch clamp")
	app.pitch=0
	if "--warehouse-cabin-only" in OS.get_cmdline_user_args():
		check(await app.session.close_session(),"final cabin session saved")
		print("WAREHOUSE_CABIN_FAILURES ",failures);quit(1 if failures else 0);return
	world=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;app.travel_action("land")
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"landing");quit(1);return
	var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
	move_to(FrontierCrewWorld.vector(site.center)+Vector3(0,0,3))
	app.open_station("base");await create_timer(.3).timeout
	check(panel.visible and panel.tabs.current_tab==2 and not panel.using_ship() and panel.cargo.get_child_count()==10,"landing warehouse opens ten-slot drag UI")
	panel._transfer_cargo({"resource":"iron","amount":100,"source":"bag"});await create_timer(.3).timeout
	site=FrontierExpeditionBusiness.site(app.session.authority.world)
	check(int(site.inventory.iron)==100,"planet storage has its own inventory")
	await capture("planet-storage-960")
	check(app.surface_world.business_view.nodes.has("business-base"),"landing warehouse Blender model exists in live world")
	var fixture: Dictionary=site.duplicate(true);fixture.inventory.iron=1000
	check(not FrontierItemInventory.warehouse_fits(fixture,{"copper":1}),"planet ten-slot capacity applies across item types")
	fixture.buildings.extra={"type":"storage"}
	check(FrontierItemInventory.warehouse_capacity(fixture)==20,"built warehouse adds ten slots")
	app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	app.session.send_request("ready",{"value":true});app.session.send_request("launch",{});await process_frame
	check(not FrontierCrewSurface.landed(app.session.authority.world),"launch permits personal bag cargo")
	check(int(app.session.authority.world.business.sites[body.id].inventory.iron)==100 and int(app.session.authority.world.crew.cargo.iron)==900 and int(FrontierExpeditionBusiness.bag(app.session.authority.world,id).iron)==20,"departure leaves planet stock and carries only bag and ship cargo")
	var saved:=app.world_store.read_state()
	check(int(saved.crew.cargo.iron)==900 and int(saved.business.sites[body.id].inventory.iron)==100,"separate cargo locations persist")
	check(await app.session.close_session(),"isolated session saved")
	print("WAREHOUSE_FAILURES ",failures);quit(1 if failures else 0)
