extends "res://tests/test_solo_entry.gd"
## Bounded UI verification using a copied world; dense discoveries/stocks are fixture data.
func visible_count(grid: GridContainer) -> int:
	var count:=0
	for child in grid.get_children():
		if child.visible:count+=1
	return count
func run() -> void:
	folder="/tmp/uiux-ux02"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/uiux-ux02" not in OS.get_cmdline_user_args():quit(1);return
	if not FileAccess.file_exists(folder+"/world.json") or not FileAccess.file_exists(folder+"/profile.json"):quit(1);return
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"isolated UX02 world",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":quit(1);return
	app.close_menus();app.onboarding.letter.hide();app.navigation_journal.path=folder+"/navigation.json"
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	var actor: String=app.session.latest.self_id
	var point:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	app.actors[actor].position=point;app.session.authority.update_position(1,point)
	var world: Dictionary=app.session.authority.world
	world.crew.survey={};world.crew.rock=40
	for ordinal in range(100,400):
		var id:=FrontierUniverse.body_id(world.manifest,ordinal)
		world.crew.survey[id+"/mineral/iron"]={"body_id":id,"resource":"iron","vein_id":"fixture","tier":1}
	var bio: Dictionary={}
	for ordinal in range(400,500):
		var body:=FrontierUniverse.body(world.manifest,ordinal)
		if not FrontierUniverse.landable(body):continue
		var record:=FrontierEcology.ensure_planet(world.ecology,body)
		for row in record.lineages:
			FrontierEcology.scan(world.ecology,body.id,row)
			if bio.is_empty():bio=world.ecology.observations[body.id+":"+row.form_id]
		if world.ecology.observations.size()>30:break
	var site: Dictionary=world.business.sites[world.location]
	for i in 3:
		var building: Dictionary=site.buildings.factory.duplicate(true);building.type="storage";building.id="ux02_storage_"+str(i);building.tier=1;building.position=[20+i*8,2,10];site.buildings[building.id]=building
	for resource in FrontierMinerals.all():site.inventory[resource]=100
	site.inventory.diamond=0;site.production_lease=true
	check(FrontierUniverse.validate_world(world).is_empty(),"dense fixture validates without changing player saves")
	app.session._publish();app.session._publish_surface();await create_timer(.4).timeout
	check(app.session.latest.crew.survey.size()==256 and world.crew.survey.size()==300,"full history kept with bounded movement snapshot")
	app.toggle_research();app.research_frame.tabs.current_tab=1;await capture("journal-960")
	var journal:=app.survey_journal
	journal.category.select(1);journal.refresh();await process_frame
	check(journal.grid.get_child_count()==24 and not journal.next.disabled,"all discoveries paginated beyond 24")
	var first_key: String=journal.selected_entry.key
	journal.next.pressed.emit();await process_frame
	check(journal.page_index==1 and journal.selected_entry.key!=first_key,"second page exposes older records")
	journal.search.text="존재하지않는광물";journal.refresh();await process_frame
	check(journal.selected_entry.is_empty() and not app.surface_panel.visible,"search empty state clears unrelated actions")
	journal.search.text="";journal.category.select(2);journal.page_index=0;journal.refresh();await process_frame
	check(not journal.selected_entry.is_empty() and journal.selected_entry.kind=="biology","biology from another planet remains in codex")
	var form:=FrontierEcologyCatalog.form(journal.selected_entry.row.form_id)
	await capture("biology-960")
	check(app.research_actions[0].is_visible_in_tree() and not app.research_actions[1].visible,"only current ecology action emphasized")
	app.research_actions[0].pressed.emit();await create_timer(.5).timeout
	check(app.session.authority.world.ecology.research.has(form.environment),"selected remote discovery analyzes through real host command")
	check(not app.research_actions[0].visible,"completed analysis advances displayed action")
	check(journal.detail_column.get_global_rect().end.x<=root.size.x and app.surface_panel.get_global_rect().end.y<=root.size.y,"codex and workflow fit 960x640")
	app.close_menus();point=Vector3(-32,2,-30);app.actors[actor].position=point;app.session.authority.update_position(1,point);app.session._publish();app.session._publish_surface();await create_timer(.3).timeout
	app.open_station("factory","factory");await capture("factory-960")
	var panel:=app.business_panel;var production:=panel.production_panel
	check(panel.factory_navigation.visible and not panel.tabs.tabs_visible,"factory uses two sections and crafting categories")
	production.search.text=FrontierProductionTier2.product("refined_iron").name;production.filter_products()
	check(visible_count(production.product_grid)==1,"product search")
	production.selected_product="refined_iron";production.refresh()
	check(not production.produce.disabled,"craftable product ready at actual factory")
	check(production.produce.get_global_rect().end.y<root.size.y and production.produce.get_global_rect().end.x<root.size.x,"fixed production action fits small window")
	production.produce.pressed.emit();await create_timer(.4).timeout
	check(not app.session.authority.world.business.sites[app.session.latest.location].buildings.factory.get("production",{}).is_empty(),"production request reaches host")
	production.craftable.button_pressed=true;production.filter_products()
	check(visible_count(production.product_grid)==0 and production.empty.visible,"busy factory updates craftable filter")
	production.search.text="";production.craftable.button_pressed=false;production.filter_products();await capture("production-960")
	panel.factory_category.select(4);panel._factory_page();await capture("engineering-960")
	check(not panel.research_project.visible and not panel.research_trial_button.visible,"engineering uses cards and stage-specific actions")
	app.close_menus()
	var records:=app.navigation_records
	records.journal.data={"version":1,"systems":{},"bodies":{},"favorites":{}}
	var ordinal:=56058;records.journal.mark(ordinal,"visited")
	var body:=FrontierUniverse.body(app.session.manifest,ordinal)
	var resources: Array=FrontierOrbitalSurvey.report(body).resources
	check(not resources.is_empty(),"navigation resource fixture exists")
	records.search.text=FrontierCatalog.entry("resources",resources[0]).name
	records.supply_sites=[];records.filter.select(0);records.refresh()
	check(records.pages.is_empty(),"unscanned procedural minerals are not searchable")
	records.journal.mark(ordinal,"scanned");records.refresh()
	check(records.pages.has(ordinal),"scanned minerals find planet records")
	records.popup_centered();await capture("navigation-search-960");records.hide()
	var dialog:=FrontierResourceListDialog.new();app.add_child(dialog);dialog.configure("거점 창고",app.session.surface.business.sites[app.session.latest.location].inventory);dialog.popup_centered(Vector2i(510,400));await capture("resources-960")
	var zero:=false
	for tile in dialog.grid.get_children():
		if tile.caption=="다이아몬드":zero=true
	check(not zero and dialog.grid.get_child_count()>4,"resource details show every owned type and no zero items")
	check(dialog.size.x<=root.size.x and dialog.size.y<=root.size.y,"all-resource popup fits small window")
	dialog.queue_free();await process_frame
	check(app.world_store.write(app.session.authority.world),"full discoveries saved")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(saved.crew.survey.size()==300,"older discoveries survive save/load")
	check(await app.session.close_session(),"isolated session closes")
	print("UIUX_DISCOVERY ",checks," FAILURES ",failures);quit(1 if failures else 0)
