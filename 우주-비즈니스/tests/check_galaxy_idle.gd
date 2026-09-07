extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--crew-folder="):DirAccess.make_dir_recursive_absolute(argument.trim_prefix("--crew-folder="))
 FrontierInput.apply({});root.size=Vector2i(960,640);root.content_scale_size=root.size
 var app: FrontierCrewExpedition=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 app.start_solo(true);await create_timer(1).timeout;app.onboarding.letter.hide();app.navigation_ui.open_galaxy();app.chart.focus_nearby()
 while FrontierStellarRoutes.built<FrontierStellarRoutes.points.size():await process_frame
 await create_timer(.4).timeout
 var measure:=Time.get_ticks_usec()
 for frame in 60:await process_frame
 print("STEADY NEARBY ms ",float(Time.get_ticks_usec()-measure)/60000.0," visible ",app.chart.displayed_systems.size()," viewport mode ",app.chart.scene_3d.viewport.render_target_update_mode)
 var okay: bool=app.chart.scene_3d.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and app.space_view.render_target_update_mode==SubViewport.UPDATE_DISABLED
 print("GALAXY IDLE ","PASS" if okay else "FAIL")
 await app.session.close_session();app.queue_free();await process_frame;quit(0 if okay else 1)
