extends SceneTree
var checks:=0
var failures:=0
var app: FrontierCrewExpedition
var folder: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
	else:print("PASS ",label)
func until(condition: Callable,label: String,seconds: float=60) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if condition.call():check(true,label);return true
		await create_timer(.1).timeout
	check(false,label);return false
func capture(name_value: String) -> void:
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	root.size=Vector2i(1280,800)
	var title: Node=load("res://scenes/app/main.tscn").instantiate();root.add_child(title);current_scene=title
	await process_frame
	var solo: Button=title.find_child("SoloStart",true,false)
	check(solo!=null and title.find_child("MultiplayerStart",true,false)!=null,"clear solo and multiplayer entry")
	var legacy_visible:=false
	for button in title.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and (button.text.contains("1.2") or button.text in ["사업 이어하기","단독 탐험 기록"]):legacy_visible=true
	check(not legacy_visible,"legacy entry removed from title")
	await capture("title")
	solo.pressed.emit()
	if not await until(func():return current_scene is FrontierCrewExpedition,"solo click opens expedition",30):quit(1);return
	app=current_scene
	if not await until(func():return app.session.active,"solo opens without lobby or connection setup",30):quit(1);return
	check(app.session.offline and app.session.enet==null and app.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"solo opens no UDP listener")
	check(not app.lobby.is_visible_in_tree() and not app.ready_button.is_visible_in_tree(),"solo hides lobby and redundant readiness")
	check(app.outside and app.exterior_view.visible,"solo starts with actual 3D ship exterior")
	check(app.address.text=="16" and app.panel.get_node("Land").disabled,"default destination and honest arrival gate")
	await capture("solo-orbit")
	app.panel.get_node("Depart").pressed.emit()
	check(app.session.latest.crew.navigation.mode!="idle","one click chooses route and departs")
	if not await until(func():return app.session.latest.crew.navigation.mode=="idle" and not app.panel.get_node("Land").disabled,"real flight reaches landing range",90):quit(1);return
	app.panel.get_node("Land").pressed.emit()
	if not await until(func():return app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"one click lands and streams collision",90):quit(1);return
	check(not app.navigation_frame.visible and not app.research_frame.visible and not app.business_panel.visible and not app.shipyard_panel.visible,"landing closes every large panel")
	check(app.surface_tools.visible and app.navigation_toggle.visible,"small field toolbar remains reachable")
	await create_timer(1).timeout
	check(not app.navigation_frame.visible,"repeated snapshots do not reopen panel")
	await capture("landed")
	var before: Vector3=app.actors[app.session.latest.self_id].position
	app.test_direction=Vector2(1,0);await create_timer(.65).timeout;app.test_direction=Vector2.ZERO
	check(app.actors[app.session.latest.self_id].position.distance_to(before)>1,"movement available after landing")
	var edits: int=app.session.surface.edits.size()
	app.pitch=-1.35;await create_timer(.3).timeout
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=root.get_visible_rect().size/2
	Input.parse_input_event(event);await process_frame;event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await until(func():return app.session.surface.edits.size()>edits,"unobstructed viewport click excavates actual terrain",8)
	app.pitch=0
	app.toggle_business();check(app.business_panel.visible and not app.navigation_frame.visible,"B business opens without navigation overlap")
	app.business_panel.register_button.pressed.emit()
	check(app.session.authority.world.has("business"),"new solo player can register first business")
	app.toggle_business();app.toggle_research();check(app.research_frame.visible,"research remains available on demand")
	app.toggle_navigation();check(app.navigation_frame.visible and not app.research_frame.visible,"navigation can be explicitly reopened")
	app.toggle_navigation()
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640);await capture("landed-960")
	var toolbar:=app.navigation_toggle.get_parent() as Control
	check(toolbar.get_global_rect().end.x<=root.get_visible_rect().size.x and toolbar.get_global_rect().end.y<=root.get_visible_rect().size.y,"field toolbar fits 960x640")
	app.toggle_business();await capture("business-960");app.toggle_business()
	check(await app.session.close_session(),"solo saves and closes cleanly")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(saved.has("business") and FrontierCrewSurface.landed(saved),"solo progress persists")
	app.queue_free();await process_frame
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;app.start_solo()
	await until(func():return app.surface_world!=null,"solo resumes landed world",60)
	check(not app.navigation_frame.visible and app.session.offline,"resumed landing also hides lobby and navigation")
	check(await app.session.close_session(),"resumed solo closes")
	print("SOLO_ENTRY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
