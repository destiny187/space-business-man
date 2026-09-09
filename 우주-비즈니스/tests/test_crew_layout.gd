extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func run() -> void:
	if "--crew-ui-test" not in OS.get_cmdline_user_args():quit(1);return
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	var app: FrontierCrewExpedition=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	app.profile=FrontierPlayerProfile.new("user://test_crew_layout_profile.json");app.world_store=FrontierWorldStore.new("user://test_crew_layout_world.json")
	for path in [app.profile.path,app.world_store.path]:
		for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	app.connection_options.selector.select(1)
	app.port_input.value=49152+Time.get_ticks_msec()%15000;app.host_world()
	await create_timer(.7).timeout
	check(app.session.active,"small viewport host opens")
	var column: VBoxContainer=app.panel.get_parent();var scroll: ScrollContainer=column.get_parent();var frame: Control=scroll.get_parent()
	check(frame.get_global_rect().end.y<=640 and frame.get_global_rect().position.x>=0,"panel stays inside 960x640")
	app.roster.custom_minimum_size.y=200
	await process_frame;await process_frame
	scroll.ensure_control_visible(column.get_child(column.get_child_count()-1))
	await process_frame
	check(scroll.scroll_vertical>0,"last action remains reachable by scrolling")
	app.show_equipment();await process_frame
	var popup: AcceptDialog
	for child in app.get_children():
		if child is AcceptDialog:popup=child
	check(popup!=null and popup.visible and popup.theme.default_font!=null,"equipment popup opens with Korean font")
	var before: float=app.session.authority.now
	await create_timer(.3).timeout
	check(app.session.authority.now>before,"personal popup does not pause world")
	popup.queue_free()
	app.session.send_request("navigate",{"ordinal":15});app.session.send_request("ready",{"value":true});app.session.send_request("depart",{})
	for step in 3000:
		FrontierCrewNavigation.step(app.session.authority.world,.05)
		if app.session.authority.world.crew.navigation.mode=="idle":break
	app.session._publish()
	app.session.send_request("ready",{"value":true});app.session.send_request("land",{})
	var deadline:=Time.get_ticks_msec()+45000
	while Time.get_ticks_msec()<deadline:
		if app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position):break
		await process_frame
	check(app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"solo host lands in actual shared surface at 960x640")
	check(app.surface_panel.visible and app.reticle.visible and not app.address.visible,"surface tools replace unavailable orbital controls")
	await create_timer(1).timeout
	scroll.ensure_control_visible(app.surface_status);await process_frame
	check(frame.get_global_rect().end.y<=640 and app.surface_status.get_global_rect().position.x>=0,"surface information stays inside small screen")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/locus-crew-surface-small.png")
	app.session.send_request("business_register",{})
	await create_timer(.7).timeout
	app.toggle_business();await process_frame;await process_frame
	check(app.business_panel.visible and app.business_panel.get_global_rect().end.x<=960 and app.business_panel.get_global_rect().end.y<=640,"business terminal fits small screen")
	check(app.business_panel.register_button.disabled,"registered site cannot offer duplicate registration")
	var business_scroll: ScrollContainer=app.business_panel.get_child(0)
	var business_column: VBoxContainer=business_scroll.get_child(0)
	business_scroll.ensure_control_visible(business_column.get_child(business_column.get_child_count()-1));await process_frame
	check(business_scroll.scroll_vertical>0,"business controls remain reachable by scrolling")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/locus-business-small.png")
	check(await app.session.close_session(),"normal close stores small-screen world")
	app.queue_free();await process_frame
	for path in ["user://test_crew_layout_profile.json","user://test_crew_layout_world.json"]:
		for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	print("CREW_LAYOUT_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
