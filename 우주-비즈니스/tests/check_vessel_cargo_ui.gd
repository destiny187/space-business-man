extends "res://tests/test_solo_entry.gd"
func tab(name_value: String) -> void:
	for i in app.business_panel.tabs.get_tab_count():
		if app.business_panel.tabs.get_tab_title(i)==name_value:app.business_panel.tabs.current_tab=i;return
func run() -> void:
	folder="/tmp/vessel-cargo-ui"
	if "--crew-folder=/tmp/vessel-cargo-ui" not in OS.get_cmdline_user_args():printerr("isolated --crew-folder=/tmp/vessel-cargo-ui required");quit(1);return
	DirAccess.make_dir_recursive_absolute(folder)
	var fixture:=FrontierWorldStore.new("/tmp/finch-sortie/world.json").read_state()
	var owner: String=fixture.crew.owner_id
	var craft: Dictionary=fixture.crew.shuttles.values()[0].duplicate(true)
	for member in fixture.crew.members.values():member.erase("shuttle_id")
	craft.state="docked";craft.pad_slot=0;craft.location=fixture.location;craft.navigation_target=fixture.location;craft.system=fixture.crew.navigation.system;craft.navigation=fixture.crew.navigation.duplicate(true);craft.landing=fixture.crew.landing.duplicate();craft.cargo={};craft.cargo_equipment={};craft.rock=0
	fixture.crew.shuttles={owner:craft}
	fixture.business.bags[owner]=FrontierExpeditionBusiness.inventory()
	fixture.business.bags[owner].merge({"iron":25,"copper":12,"reinforced_frame":2,"control_circuit":3},true)
	fixture.crew.cargo={"ice":10,"crystal":4};fixture.crew.rock=0
	var store:=FrontierWorldStore.new(folder+"/world.json")
	check(store.write(fixture),"prepare isolated docked craft: "+store.last_error)
	var profile_store:=FrontierPlayerProfile.new(folder+"/profile.json");profile_store.data={"version":1,"character":fixture.crew.members[owner].profile,"sessions":{}};profile_store.save()
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"opens actual supply site",60):quit(1);return
	var actor: String=app.session.latest.self_id
	app.session.authority.world.business.bags[actor].merge({"iron":25,"copper":12,"reinforced_frame":2,"control_circuit":3},true)
	app.session._publish();await create_timer(.2).timeout
	app.actors[actor].position=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	app.session.authority.update_position(1,app.actors[actor].position)
	app.open_station("ship")
	await capture("mother-terminal")
	check(app.business_panel.vessel_terminal.preview.model!=null,"mother terminal renders current hull")
	app.business_panel.vessel_terminal.cards.cargo.pressed.emit()
	await capture("mother-cargo")
	var ui:=app.inventory_panel
	check(ui.visible and ui.tabs.current_tab==2 and ui.using_ship() and ui.left.visible,"terminal opens shared inventory cargo layout")
	var tile:=find_tile(ui.storage_owned,"resource","iron")
	check(tile!=null,"cargo exposes resource slots")
	if tile!=null:
		tile.pressed.emit();await create_timer(.1).timeout
		ui.transfer_count.value=7;ui.transfer_button.pressed.emit()
		await create_timer(.3).timeout
		check(int(app.session.authority.world.crew.cargo.get("iron",0))==7,"selected amount reaches mother cargo through host")
	var gear:=str(ui.data.items.keys()[0])
	tile=find_tile(ui.storage_owned,"equipment_item",gear)
	if tile!=null:
		tile.pressed.emit();await create_timer(.1).timeout;ui.transfer_button.pressed.emit()
		await create_timer(.3).timeout
		check(not ui.data.items.has(gear),"equipment supports selected transfer button")
		tile=find_tile(ui.cargo,"equipment_item",gear)
		if tile!=null:ui.storage_owned.get_child(0)._drop_data(Vector2.ZERO,tile.cargo_payload)
		await create_timer(.3).timeout
		check(ui.data.items.has(gear),"drag from ship restores owned equipment")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	await capture("mother-cargo-960")
	check(ui.get_global_rect().end.x<=960 and ui.cargo.get_global_rect().end.x<=960,"cargo grids fit 960 width")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	# Separate saved sortie fixture: this check targets the two inventory interfaces, not flight.
	craft.state="sortie";fixture.crew.shuttles={owner:craft}
	fixture.crew.members[owner].shuttle_id=owner;fixture.crew.members[owner].aboard=false;fixture.crew.members[owner].area="surface"
	check(store.write(fixture),"prepare independent landed FINCH: "+store.last_error)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame
	app.start_solo()
	if not await until(func():return app.surface_world!=null and not app.arrival.active,"opens FINCH surface",60):quit(1);return
	ui=app.inventory_panel
	app.actors[actor].position=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	app.session.authority.update_position(1,app.actors[actor].position)
	app.open_station("ship");await capture("finch-terminal-960")
	check(not app.business_panel.vessel_terminal.cards.research.visible and app.business_panel.vessel_terminal.cards.rejoin.visible,"FINCH shows its own available functions")
	app.business_panel.vessel_terminal.cards.cargo.pressed.emit();await create_timer(.2).timeout
	tile=find_tile(ui.storage_owned,"resource","copper")
	if tile!=null:tile.pressed.emit();await create_timer(.1).timeout;ui.transfer_count.value=5;ui.transfer_button.pressed.emit()
	await create_timer(.3).timeout
	check(int(app.session.authority.world.crew.shuttles[actor].cargo.get("copper",0))==5 and int(app.session.authority.world.crew.cargo.get("copper",0))==0,"FINCH cargo transfer stays personal")
	await capture("finch-cargo-960")
	check(ui.title.text=="FINCH" and int(ui.storage_bars[1].max_value)==4,"FINCH model and four-slot capacity")
	check(app.feedback.blocked(),"cargo menu blocks field controls and work audio")
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	print("VESSEL_CARGO_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func find_tile(grid: GridContainer,key: String,value: String) -> FrontierItemTile:
	for tile in grid.get_children():
		if tile.cargo_payload.get(key,"")==value:return tile
	return null
