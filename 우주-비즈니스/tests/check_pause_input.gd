extends SceneTree
var calls:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
	if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	var app: FrontierCrewExpedition=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;app.start_solo()
	await create_timer(.5).timeout
	assert(app.surface_world!=null)
	app.session.request_started.connect(func(_sequence: int,_kind: String,_args: Dictionary):calls+=1)
	app.open_menu(app.navigation_ui.pause_frame)
	for code in [KEY_Q,KEY_F,KEY_C]:
		var event:=InputEventKey.new();event.pressed=true;event.physical_keycode=code;app._unhandled_input(event)
	var click:=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT;app._unhandled_input(click)
	assert(calls==0 and app.feedback.blocked(),"pause blocks background action keys and tool click")
	app.close_menus();assert(app._mouse_look_allowed())
	app.navigation_ui.show_target(int(app.session.latest.crew.navigation.target));app.toggle_navigation()
	assert(not app.field_hud.visible and not app.navigation_ui.context.visible,"menu hides field overlays immediately")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../test-results/navigation-interface/final-map.png"))
	print("PAUSE INPUT PASS: no actions behind menu; resume restores input")
	await app.session.close_session();app.queue_free();await process_frame;quit()
