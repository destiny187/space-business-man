extends "res://tests/test_solo_entry.gd"
## Focused reproduction checks for the audited UI; uses a copied A06 fixture only.
func tile_for(grid: GridContainer,resource: String) -> FrontierItemTile:
	for tile in grid.get_children():
		if tile.get_meta("resource",tile.cargo_payload.get("resource",""))==resource:return tile
	return null
func visible_tiles(grid: GridContainer) -> int:
	var count:=0
	for tile in grid.get_children():
		if tile.visible:count+=1
	return count
func run() -> void:
	folder="/tmp/uiux-ux01"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/uiux-ux01" not in OS.get_cmdline_user_args():quit(1);return
	if not FileAccess.file_exists(folder+"/world.json") or not FileAccess.file_exists(folder+"/profile.json"):quit(1);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
	if not await until(func():return app.session.active and app.surface_world!=null and not has_meta("startup_loader") and not app.arrival.active,"isolated UX01 fixture",60):quit(1);return
	if not app.test_mode or app.world_store.path!=folder+"/world.json":quit(1);return
	app.close_menus();app.onboarding.letter.hide()
	var actor: String=app.session.latest.self_id
	var position:=Vector3(-4,2.1,4)
	app.actors[actor].position=position;app.session.authority.update_position(1,position)
	var world: Dictionary=app.session.authority.world
	world.crew.members[actor].loadout.inventory_slots=48
	var site: Dictionary=world.business.sites[world.location]
	for i in 3:
		var building: Dictionary=site.buildings.factory.duplicate(true);building.type="storage";building.id="audit_storage_"+str(i);building.tier=1;building.position=[20+i*8,2,10];site.buildings["audit_storage_"+str(i)]=building
	for resource in FrontierMinerals.all():world.business.bags[actor][resource]=12;site.inventory[resource]=12
	for resource in FrontierProductionTier2.config().products:site.inventory[resource]=12
	world.business.bags[actor].diamond=0;site.inventory.diamond=0
	check(FrontierExpeditionBusiness.validate(world.business,world.manifest).is_empty(),"fixture conforms to business save schema")
	app.session._publish();app.session._publish_surface();await create_timer(.5).timeout
	app.toggle_inventory();await capture("items-1280")
	if not app.session.active:printerr(app.world_store.error);quit(1);return
	var panel:=app.inventory_panel
	check(tile_for(panel.owned,"diamond")==null,"zero-stock item absent")
	panel.browsers["아이템"].category.select(2);panel._filter_items()
	check(visible_tiles(panel.owned)==3,"gem filter excludes equipment and zero diamond")
	panel.browsers["아이템"].search.text="사파이어";panel._filter_items()
	check(visible_tiles(panel.owned)==1,"Korean item search")
	tile_for(panel.owned,"sapphire").pressed.emit();await capture("gem-use")
	check(panel.title.text=="사파이어" and panel.stats.get_child_count()>4,"selected gem exposes known uses")
	panel._open_use({"name":"기동 증강","model":"crew/surveyor_suit","cost":{"sapphire":3},"where":"우주선 증강 장치 · F","target":"body","id":"mobility"});await capture("use-detail")
	check(panel.usage_dialog.visible,"usage opens a read-only model/recipe detail")
	panel.usage_dialog.hide()
	panel.browsers["아이템"].search.text="";panel.browsers["아이템"].category.select(0);panel._filter_items()
	panel.tabs.current_tab=2;panel.warehouse_choice.select(0);panel.last_key="";await create_timer(.5).timeout
	panel.cargo_browser.search.text="사파이어"
	tile_for(panel.storage_owned,"sapphire").pressed.emit();await create_timer(.3).timeout
	check(panel.cargo_summary.text.contains("사파이어") and panel.cargo_summary.text.contains("내 배낭 → 행성 창고"),"planet cargo retains name and direction")
	panel.quantity_buttons[2].pressed.emit()
	check(int(panel.transfer_count.value)==12,"maximum uses source stock and destination room")
	panel.transfer_button.pressed.emit();await create_timer(.5).timeout
	check(int(app.session.latest.inventory.sapphire)==0 and int(panel.depot.sapphire)==24,"real host transfer moves exact remaining quantity")
	check(tile_for(panel.storage_owned,"sapphire")==null and panel.storage_selection.is_empty(),"last stack disappears without a stale selection")
	tile_for(panel.cargo,"sapphire").pressed.emit();panel.transfer_count.value=1;panel.transfer_button.pressed.emit();await create_timer(.5).timeout
	check(int(app.session.latest.inventory.sapphire)==1,"reverse transfer from warehouse")
	panel.cargo_browser.search.text="";panel._filter_items();await capture("cargo-1280")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("cargo-960")
	check(not panel.hotbar.visible and panel.get_global_rect().end.y<=root.size.y,"cargo hides equipment hotbar and uses available height")
	check(panel.cargo.get_parent().size.y>=206 and panel.transfer_button.get_global_rect().end.x<root.size.x,"two cargo rows and transfer controls fit small window")
	check(panel.get_global_rect().end.x<=root.size.x and panel.cargo.get_parent().get_global_rect().end.x<=root.size.x,"cargo columns shrink within viewport width")
	panel.tabs.current_tab=0;await capture("items-960")
	check(panel.get_global_rect().end.y<panel.hotbar.get_global_rect().position.y,"item footer no longer overlaps hotbar")
	check(panel.action.get_global_rect().end.y<=panel.get_global_rect().end.y,"primary action fits without scrolling the whole page")
	check(panel.get_global_rect().end.x<=root.size.x and panel.detail_shell.get_global_rect().end.x<=root.size.x,"item details and close button remain on screen")
	var edits: int=app.session.surface.edits.size();app.use_equipped();await process_frame
	check(app.session.surface.edits.size()==edits,"menu blocks world equipment action")
	app.close_menus();app.toggle_business();await capture("build-960")
	check(not app.business_panel.stock.value.contains("12") and not app.business_panel.stock.value.contains(" 0"),"construction no longer enumerates inventory")
	check(app.business_panel.get_global_rect().end.x<=root.size.x,"construction fits small window")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(int(saved.business.bags[actor].get("sapphire",0))==1,"transfer recorded in persisted world")
	check(await app.session.close_session(),"isolated session closes and saves")
	print("UIUX_INVENTORY ",checks," FAILURES ",failures);quit(1 if failures else 0)
