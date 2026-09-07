extends SceneTree
var app: FrontierCrewExpedition
var failures:=0
var folder:="/tmp/navigation-ui-check"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func capture(label: String) -> void:
	await create_timer(.2).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label+".png")
func run() -> void:
	if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	# The normal title installs input bindings before opening the expedition.
	FrontierInput.apply({})
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	app.start_solo(true);await create_timer(.6).timeout;app.onboarding.letter.hide()
	check(app.session.active,"isolated solo starts")
	app.test_mode=false;DisplayServer.window_move_to_foreground();await create_timer(.2).timeout
	app._sync_mouse_capture();check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"actual game window captures mouse")
	await key(KEY_ESCAPE);check(app.navigation_ui.pause_frame.visible and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Esc opens continue/settings/exit menu and releases mouse")
	await capture("pause")
	FrontierClientSettings.ensure(self).open();await key(KEY_ESCAPE)
	check(not FrontierClientSettings.ensure(self).is_open() and app.navigation_ui.pause_frame.visible,"Esc from settings returns to menu")
	await key(KEY_ESCAPE);check(not app.any_menu_open() and not app.cursor_released and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"resume captures mouse immediately")
	app.navigation_toggle.grab_focus();await key(KEY_TAB)
	check(app.navigation_frame.visible,"Tab works with focused button")
	await capture("map-solar")
	app.navigation_ui.route.grab_focus();await key(KEY_I)
	check(app.inventory_panel.visible and not app.navigation_frame.visible,"focused map to inventory")
	await key(KEY_TAB);check(app.navigation_frame.visible and not app.inventory_panel.visible,"inventory to map")
	await key(KEY_K);check(app.shipyard_panel.visible and not app.navigation_frame.visible,"map to shipyard")
	await key(KEY_I);check(app.inventory_panel.visible and not app.shipyard_panel.visible,"shipyard to inventory")
	await key(KEY_I);check(not app.any_menu_open() and app._mouse_look_allowed() and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"same key closes and restores actual mouse capture")
	# Set up a genuinely close manual arrival, leaving the previous location/target elsewhere.
	app.test_mode=true
	app.navigation_ui.start_route(FrontierUniverse.first_ordinal(app.session.manifest,23))
	await create_timer(.3).timeout
	check(app.navigation_ui.pending_route<0 and app.session.latest.crew.navigation.mode!="idle","map route waits for accepted snapshot then starts travel")
	var world: Dictionary=app.session.authority.world
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	var nav: Dictionary=world.crew.navigation
	nav.system=23;nav.target=ordinal;nav.mode="idle";nav.manual=true;nav.speed=0.0;nav.orbit_time=0.0
	var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.navigation_radius(body)+float(world.manifest.settings.flight.arrival_clearance)-20)
	nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1]
	app.session._publish();await create_timer(.3).timeout
	var rejected:=world.duplicate(true)
	var pilot: String=rejected.crew.pilot_id
	var saved_target: int=rejected.crew.navigation.target
	rejected.crew.navigation.position=[0.0,0.0,0.0]
	check(not FrontierCrewSurface.apply(rejected,pilot,"land",{"ordinal":ordinal},{1:pilot}).is_empty() and rejected.crew.navigation.target==saved_target,"host rejects distant landing without changing selection")
	check(app.navigation_ui.context.visible and app.navigation_ui.context_kind=="land" and app.navigation_ui.context_ready,"manual proximity offers landing without previous location match")
	check(app.navigation_ui.mini.visible and not app.navigation_frame.visible,"space minimap appears without panel")
	app.flight.transit_overlay.arrival_age=100
	await capture("near-planet")
	await key(KEY_TAB);app.navigation_ui.show_target(ordinal)
	app.flight.scanned[body.id]=true;app.navigation_ui.show_target(ordinal)
	await capture("map-planet")
	await capture("map-meters")
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("map-960")
	check(app.chart.size.x>=280 and app.navigation_frame.get_global_rect().end.x<=960,"map fits small window")
	await key(KEY_ESCAPE)
	await key(KEY_F)
	check(app.arrival.active,"proximity F starts host-approved landing")
	var deadline:=Time.get_ticks_msec()+90000
	while app.arrival.active and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.arrival.active and app.surface_world!=null,"landing completes")
	await key(KEY_B);check(app.business_panel.visible,"ground business opens")
	await key(KEY_I);check(app.inventory_panel.visible and not app.business_panel.visible,"business to inventory")
	await key(KEY_J);check(app.research_frame.visible and not app.inventory_panel.visible,"inventory to research")
	await key(KEY_I);await key(KEY_ESCAPE)
	check(not app.any_menu_open() and app._mouse_look_allowed(),"Esc from inventory restores ground look")
	var yaw:=app.yaw;app._mouse_look(Vector2(16,0),.0025,false);check(app.yaw!=yaw,"ground look responds after transitions")
	await capture("ground")
	check(await app.session.close_session(),"save after landing succeeds")
	app.queue_free();await process_frame
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;app.start_solo()
	await create_timer(.5).timeout
	check(app.surface_world!=null and not app.any_menu_open() and not app.arrival.active,"saved landing resumes without panels or repeated arrival")
	await app.session.close_session()
	print("NAVIGATION INTERFACE failures ",failures)
	app.queue_free();await process_frame;quit(1 if failures else 0)
