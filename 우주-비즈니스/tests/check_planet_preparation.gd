extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 if not ok:failures+=1;printerr("FAIL "+label)
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):DirAccess.make_dir_recursive_absolute(arg.trim_prefix("--crew-folder="))
 FrontierInput.apply({});root.size=Vector2i(960,640);root.content_scale_size=root.size
 var app: FrontierCrewExpedition=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 app.start_solo(true);await create_timer(.8).timeout;app.onboarding.letter.hide()
 var manifest: Dictionary=app.session.manifest
 var origin:=FrontierUniverse.map_position(manifest,0)
 var destination: int=-1
 for index in range(1,25000):
  if origin.distance_to(FrontierUniverse.map_position(manifest,index))<7.5:destination=index;break
 check(destination>=0,"nearby destination exists")
 if destination<0:quit(1);return
 app.navigation_ui.open_galaxy()
 app.navigation_ui.show_route(FrontierUniverse.first_ordinal(manifest,destination))
 app.navigation_ui.route.pressed.emit()
 await create_timer(2).timeout
 check(not app.navigation_frame.visible and app.outside and app.exterior_view.visible,"map departure shows exterior animation")
 check(app.space_view.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"flight renderer resumed")
 check(app.session.latest.crew.navigation.mode=="jump" and float(app.session.latest.crew.navigation.transit.progress)<1,"transit has not teleported to completion")
 await RenderingServer.frame_post_draw
 var frames:=ProjectSettings.globalize_path("res://../test-results/navigation-cache");DirAccess.make_dir_recursive_absolute(frames)
 root.get_texture().get_image().save_png(frames+"/flight-transition.png")
 check(app.flight.prepared_system==destination,"destination preparation active during transit")
 check(app.flight.prepared_planets.size()==FrontierUniverse.body_count(manifest,destination),"all destination planets prepared before switch")
 var identifiers: Dictionary={}
 for ordinal in app.flight.prepared_planets:
  var node: Node3D=app.flight.prepared_planets[ordinal].node
  identifiers[ordinal]=node.get_instance_id();check(not node.visible,"prepared planet hidden")
 await create_timer(11).timeout
 check(app.flight.current_system==destination,"selected system arrived")
 for ordinal in identifiers:check(app.flight.planets[ordinal].node.get_instance_id()==identifiers[ordinal],"prepared instance reused")
 check(app.flight.prepared_planets.is_empty(),"preparation cleared after adoption")
 await RenderingServer.frame_post_draw
 var folder:=ProjectSettings.globalize_path("res://../test-results/navigation-cache");DirAccess.make_dir_recursive_absolute(folder)
 root.get_texture().get_image().save_png(folder+"/arrival.png")
 check(await app.session.close_session(),"save unchanged")
 print("PLANET PREPARATION failures ",failures," reused ",app.flight.prepared_reused)
 app.queue_free();await process_frame;quit(1 if failures else 0)
