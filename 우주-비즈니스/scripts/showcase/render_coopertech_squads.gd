extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1100,1000)
 var scene: Node=load("res://scenes/showcase/ink_catalog.tscn").instantiate();root.add_child(scene);await process_frame
 for role in ["bastion","raptor"]:
  for i in scene.samples.size():
   if scene.samples[i].id!="coopertech_"+role:continue
   scene.select_sample(i);scene.canvas.hide();await create_timer(.4).timeout;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../docs/production/media/coopertech-squads/"+role+"-godot.png")
   var world: WorldEnvironment=scene.find_children("*","WorldEnvironment",true,false)[0];var old_mode:=world.environment.background_mode
   scene.contour.set_shader_parameter("transparent_background",true);world.environment.background_mode=Environment.BG_CLEAR_COLOR;RenderingServer.set_default_clear_color(Color.TRANSPARENT);scene.studio_ground.hide()
   var viewport:=SubViewport.new();viewport.size=Vector2i(480,400);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;root.add_child(viewport);scene.reparent(viewport,false);scene.camera.current=true
   await process_frame;await RenderingServer.frame_post_draw
   var icon:=viewport.get_texture().get_image();icon.save_png("res://assets/ui/discoveries/coopertech_"+role+".png")
   scene.contour.set_shader_parameter("transparent_background",false);scene.reparent(root,false);scene.camera.current=true;viewport.queue_free();world.environment.background_mode=old_mode;scene.studio_ground.show()
   var models:=scene.find_children("*","Skeleton3D",true,false);print("COOPERTECH_RENDER ",role," skeletons ",models.size());break
 quit()
