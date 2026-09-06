extends "res://tests/test_solo_entry.gd"
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event)
	await process_frame
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await process_frame
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	root.size=Vector2i(960,640);root.content_scale_size=root.size
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;app.start_solo()
	if not await until(func():return app.surface_world!=null,"resume isolated solo for shortcut checks",60):quit(1);return
	app.navigation_toggle.grab_focus();await key(KEY_TAB)
	check(app.navigation_frame.visible,"Tab opens navigation even with a focused button")
	await key(KEY_TAB);check(not app.navigation_frame.visible,"Tab closes navigation")
	await key(KEY_B);check(app.business_panel.visible and not app.navigation_frame.visible,"B opens business")
	await key(KEY_ESCAPE);check(not app.business_panel.visible and not app.navigation_frame.visible,"Esc clears panels")
	await key(KEY_J);check(app.research_frame.visible,"J opens research")
	await key(KEY_J);check(not app.research_frame.visible,"J closes research")
	check(await app.session.close_session(),"shortcuts leave a valid saved solo world")
	print("SOLO_SHORTCUT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
