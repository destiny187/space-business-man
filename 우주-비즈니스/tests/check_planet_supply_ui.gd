extends "res://tests/test_solo_entry.gd"
func select_tab(title: String) -> void:
	for i in app.business_panel.tabs.get_tab_count():
		if app.business_panel.tabs.get_tab_title(i)==title:app.business_panel.tabs.current_tab=i;return
	check(false,"tab exists "+title)
func run() -> void:
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/planet-supply-20260908" not in OS.get_cmdline_user_args():
		printerr("격리된 공급망 UI 검수 폴더와 --crew-ui-test가 필요합니다.");quit(1);return
	folder="/tmp/planet-supply-20260908"
	# Fresh visual-check inputs in the isolated fixture; previous runs consume real stock.
	var store:=FrontierWorldStore.new(folder+"/world.json")
	var fixture:=store.read_state()
	var input_site:=FrontierExpeditionBusiness.site(fixture)
	input_site.inventory.lithium=18;input_site.inventory.ice=36;input_site.inventory.refined_copper=6
	input_site.buildings["fixture:factory"].production={}
	if not store.write(fixture):printerr(store.last_error);quit(1);return
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active and not app.outside,"saved supply world opens",60):quit(1);return
	var actor: String=app.session.latest.self_id
	var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	app.actors[actor].position=ship;app.session.authority.update_position(1,ship)
	await create_timer(.5).timeout
	app.open_station("ship");select_tab("생산 거점")
	check(app.business_panel.visible and app.business_panel.supply_panel.cards.get_child_count()==2,"two supply stock cards in actual ship terminal")
	await capture("supply-terminal")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await capture("supply-terminal-960")
	var scroll: ScrollContainer=app.business_panel.get_child(0)
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await capture("supply-stock-960")
	scroll.scroll_vertical=0
	app.close_menus()
	var s:=FrontierExpeditionBusiness.site(app.session.authority.world)
	var p:=FrontierCrewWorld.vector(s.buildings["fixture:factory"].position)
	app.actors[actor].position=p+Vector3(0,0,4);app.session.authority.update_position(1,app.actors[actor].position)
	await create_timer(.5).timeout
	app.open_station("factory","fixture:factory");select_tab("생산·개조")
	app.business_panel.production_panel.selected_product="cryo_cell";app.business_panel.production_panel.refresh()
	check(app.business_panel.visible and not app.business_panel.production_panel.produce.disabled,"leased factory allows native product through UI")
	await capture("supply-production-960")
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value);await capture("supply-actions-960")
	scroll.scroll_vertical=0
	app.close_menus()
	app.session.send_request("business_produce",{"building_id":"fixture:factory","product":"cryo_cell"})
	await create_timer(1.5).timeout
	check(app.feedback.audio.emitters.has("fixture:factory"),"existing ElevenLabs factory work loop connected")
	check(app.surface_world.business_view.nodes.has("fixture:factory") and app.surface_world.business_view.nodes["fixture:factory"].has_meta("tier3_visual"),"Mk.3 attachment in actual INK world")
	var eye:=p+Vector3(4,2.5,6)
	app.test_camera_position=eye;app.pitch=-.22;app.yaw=atan2(eye.x-p.x,eye.z-p.z)
	await capture("supply-factory-mk3")
	app.open_station("factory","fixture:factory")
	check(app.feedback.blocked(),"menu blocks field input and factory audio")
	app.close_menus();app.navigation_records.supply_sites=app.session.latest.supply_sites
	app.navigation_records.filter.select(3);app.navigation_records.refresh();app.navigation_records.popup_centered()
	check(app.navigation_records.entries.item_count==2,"supply destination records populated")
	await capture("supply-navigation-960")
	app.navigation_records.hide()
	check(await app.session.close_session(),"save and close supply session")
	print("SUPPLY_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
