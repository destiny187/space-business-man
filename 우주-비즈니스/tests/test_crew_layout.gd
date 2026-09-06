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
	check(await app.session.close_session(),"normal close stores small-screen world")
	app.queue_free();await process_frame
	for path in ["user://test_crew_layout_profile.json","user://test_crew_layout_world.json"]:
		for suffix in ["",".bak",".tmp"]:DirAccess.remove_absolute(path+suffix)
	print("CREW_LAYOUT_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
