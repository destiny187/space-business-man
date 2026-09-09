extends "res://tests/check_suit_augmentation.gd"
func run() -> void:
	folder="/tmp/suit-dye-play"
	if "--crew-folder=/tmp/suit-dye-play" not in OS.get_cmdline_user_args() or "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var owner:=FrontierPlayerProfile.new_character("염색 탐험가",0)
	FrontierWorldStore.new(folder+"/world.json").write(FrontierUniverse.new_world(71491))
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.flight!=null and not has_meta("startup_loader"),"ship scene",60):quit(1);return
	app.outside=false;app.exterior_view.hide();app.if_flight_view();app.close_menus();app.onboarding.letter.hide()
	var world: Dictionary=app.session.authority.world
	world.business=FrontierExpeditionBusiness.create()
	world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();world.business.bags[owner.character_id]["sapphire"]=1;world.business.bags[owner.character_id]["diamond"]=1
	for key in FrontierCrewAugmentation.config().fields:world.crew.members[owner.character_id].augmentation.levels[key]=5
	app.session._publish();app.toggle_inventory();app.inventory_panel.tabs.current_tab=4;await process_frame
	var ui: FrontierSuitDyePanel=app.inventory_panel.dye_panel
	await create_timer(.2).timeout
	ui.select_part("chest");ui.pickers.primary.color_changed.emit(Color("597ac9"));ui.pickers.secondary.color_changed.emit(Color("293951"))
	check(not world.crew.members[owner.character_id].has("suit_dyes") and world.business.bags[owner.character_id]["diamond"]==1,"preview is free and local")
	await capture("preview")
	ui.action.pressed.emit();await create_timer(.5).timeout;print("DYE_RESULT ",ui.message.text)
	world=app.session.authority.world
	check(world.crew.members[owner.character_id].suit_dyes.chest=={"primary":"597ac9","secondary":"293951"} and world.business.bags[owner.character_id]["diamond"]==0,"two channels cost one gem through host")
	check(app.visuals[owner.character_id].appearance.paints["DYE::chest::primary"].get_shader_parameter("base_color").is_equal_approx(Color("597ac9")),"confirmed actor color matches preview")
	ui.action.pressed.emit();await process_frame;check(app.session.authority.world.business.bags[owner.character_id]["diamond"]==0,"unchanged apply does not charge")
	ui.select_part("helmet");ui.pickers.primary.color_changed.emit(Color("d97839"));ui.submit(false);await create_timer(.5).timeout
	ui.select_part("legs");ui.pickers.primary.color_changed.emit(Color("d9af52"));ui.submit(false);await create_timer(.4).timeout
	check(ui.message.text=="재료가 부족합니다." and not app.session.authority.world.crew.members[owner.character_id].suit_dyes.has("legs"),"insufficient gems reject without mutation")
	ui.select_part("helmet");ui.reset.pressed.emit();await create_timer(.5).timeout
	check(not app.session.authority.world.crew.members[owner.character_id].suit_dyes.has("helmet") and app.session.authority.world.business.bags[owner.character_id]["sapphire"]==0,"default restoration is free without gems")
	ui.select_part("chest");await capture("applied-1280")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("applied-960")
	check(ui.action.get_global_rect().end.y<640 and ui.message.get_global_rect().end.x<=960,"dye controls fit small viewport")
	ui.pickers.primary.get_popup().popup_centered();await capture("picker-960")
	check(ui.pickers.primary.get_popup().size.y<=640,"color picker fits small viewport")
	ui.pickers.primary.get_popup().hide()
	check(await app.session.close_session(),"save and close")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(saved.crew.members[owner.character_id].suit_dyes.chest.primary=="597ac9" and FrontierCrewWorld.validate(saved.crew).is_empty(),"persisted colors validate and reload")
	app.queue_free();await process_frame;await process_frame
	print("SUIT_DYE_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
