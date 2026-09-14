extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var scene: Node=load("res://scenes/showcase/ink_catalog.tscn").instantiate();root.add_child(scene);await process_frame
 scene.samples=[]
 for id in FrontierActiveMissions.config().templates:
  if "--rock-materials" in OS.get_cmdline_user_args() and id not in ["aerial_sensor_recovery","vent_field_extraction"]:continue
  var d:=FrontierExplorationIncidents.definition(id)
  scene.samples.append({"id":id,"name":d.name,"title":"현장 미션","group":"incidents","model":"res://assets/models/"+d.model+".glb","view_direction":[1.2,.84,1.7] if id in ["coopertech_relay_raid","vent_field_extraction"] else [1.2,.84,-1.7]})
 for i in scene.samples.size():
  scene.select_sample(i);scene.canvas.hide();await create_timer(.2).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../output/active-missions/"+scene.samples[i].id+"-godot.png")
  var world: WorldEnvironment=scene.find_children("*","WorldEnvironment",true,false)[0];var old_mode:=world.environment.background_mode
  scene.contour.set_shader_parameter("transparent_background",true);world.environment.background_mode=Environment.BG_CLEAR_COLOR;RenderingServer.set_default_clear_color(Color.TRANSPARENT);scene.studio_ground.hide()
  var viewport:=SubViewport.new();viewport.size=Vector2i(480,400);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;root.add_child(viewport);scene.reparent(viewport,false);scene.camera.current=true
  await process_frame;await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png("res://assets/ui/discoveries/"+scene.samples[i].id+".png")
  scene.contour.set_shader_parameter("transparent_background",false);scene.reparent(root,false);scene.camera.current=true;viewport.queue_free();world.environment.background_mode=old_mode;scene.studio_ground.show()
 print("ACTIVE_MISSION_FORWARD_PLUS_RENDERS ",scene.samples.size());scene.queue_free();await process_frame;quit()
