extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800)
 var world:=FrontierUniverse.new_world(61739)
 var view:=FrontierCrewFlightView.new()
 view.state={"manifest":world.manifest};root.add_child(view)
 view.exterior=true;view.update_navigation(FrontierCrewNavigation.create(world))
 view.set_process(false)
 var folder:=ProjectSettings.globalize_path("res://../test-results/space-sky")
 var version:="after"
 for angle in [0,45,90]:
  view.camera.rotation_degrees=Vector3(0,angle,0)
  await create_timer(.4).timeout
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+"/"+version+"-"+str(angle)+".png")
 root.size=Vector2i(960,640)
 await create_timer(.4).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+version+"-small.png")
 print("SPACE SKY RENDER ",version," ",RenderingServer.get_video_adapter_name())
 view.queue_free();await process_frame;quit()
