extends SceneTree
var app: FrontierCrewExpedition
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
 if not value:failures+=1;printerr("FAIL "+message)
func capture(name_value: String) -> void:
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../test-results/galaxy-routes/"+name_value+".png"))
func run() -> void:
 if not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../test-results/galaxy-routes"))
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--crew-folder="):DirAccess.make_dir_recursive_absolute(argument.trim_prefix("--crew-folder="))
 FrontierInput.apply({});root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 app.start_solo(true);await create_timer(1).timeout;app.onboarding.letter.hide()
 app.navigation_ui.open_galaxy();await create_timer(3).timeout
 var world: Dictionary=app.session.authority.world
 var start:=FrontierUniverse.map_position(world.manifest,0)
 var near: int=-1;var far: int=-1
 for i in range(1,125000):
  var distance:=start.distance_to(FrontierUniverse.map_position(world.manifest,i))
  if distance>.1 and distance<7.9:near=i
  if distance>250:far=i
  if near>=0 and far>=0:break
 check(near>=0 and far>=0,"near and far candidates")
 app.chart.route_system=near;app.navigation_ui.show_route(FrontierUniverse.first_ordinal(world.manifest,near));await capture("galaxy-1280")
 check(not app.navigation_ui.route.disabled,"unvisited reachable route enabled")
 check(not app.navigation_ui.survey.visible,"unvisited details hidden")
 var draft: Dictionary=world.duplicate(true);draft.crew.navigation.target=FrontierUniverse.first_ordinal(world.manifest,far)
 check(FrontierCrewNavigation.apply(draft,draft.crew.pilot_id,"depart",{},{}).contains("항속거리"),"host rejects distant route")
 var upgraded: Dictionary=world.duplicate(true);upgraded.vessel={"hull":"swift"}
 check(FrontierVesselRefit.stellar_range(upgraded)>FrontierVesselRefit.stellar_range(world),"higher hull extends range")
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 await capture("galaxy-960")
 app.chart.focus_nearby();await capture("nearby-960")
 check(app.chart.nearby_only and app.chart.displayed_systems.size()<100,"local-only density")
 while FrontierStellarRoutes.built<FrontierStellarRoutes.points.size():await process_frame
 await create_timer(.3).timeout
 var measure:=Time.get_ticks_usec()
 for frame in 60:await process_frame
 print("NEARBY stationary average ms ",float(Time.get_ticks_usec()-measure)/60000.0," visible systems ",app.chart.displayed_systems.size())
 check(app.chart.scene_3d.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"static galaxy does not rerender")
 check(not app.chart.scene_3d.clouds[0].visible and not app.chart.scene_3d.clouds[1].visible and not app.chart.scene_3d.clouds[2].visible,"nearby culls global clouds")
 app.navigation_ui.route.pressed.emit();await create_timer(5).timeout
 check(app.session.latest.crew.navigation.mode=="jump","route starts actual transit")
 check(not app.navigation_frame.visible and app.outside and app.exterior_view.visible,"accepted transit returns exterior animation")
 await capture("transit")
 await create_timer(9).timeout
 check(int(app.session.latest.crew.navigation.system)==near,"arrived at selected unvisited star")
 check(not app.navigation_frame.visible,"arrival returns flight")
 await capture("directional-flight")
 check(app.navigation_ui.nearby_stars.markers.size()<=8,"directional marker cap")
 var overlay: Control=app.navigation_ui.nearby_stars
 check(not overlay.markers.is_empty(),"directional nearest stars available")
 if not overlay.markers.is_empty():
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;root.warp_mouse(overlay.markers[0].point)
  await create_timer(.3).timeout
  check(not overlay.hovered.is_empty(),"hover reveals direct flight action")
  await capture("directional-hover")
  if not overlay.hovered.is_empty():
   var next_index: int=overlay.hovered.index
   var event:=InputEventKey.new();event.physical_keycode=KEY_F;event.pressed=true;Input.parse_input_event(event)
   await create_timer(.5).timeout
   check(app.session.latest.crew.navigation.mode=="jump" and FrontierUniverse.system_index(world.manifest,int(app.session.latest.crew.navigation.target))==next_index,"F starts nearby route without map selection")
   await create_timer(13).timeout
 app.navigation_ui.open_galaxy();app.chart.focus_nearby();await capture("next-route")
 check(await app.session.close_session(),"save succeeds")
 print("GALAXY ROUTES failures ",failures)
 app.queue_free();await process_frame;quit(1 if failures else 0)
