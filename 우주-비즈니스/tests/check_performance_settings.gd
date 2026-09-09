extends SceneTree
var failures:=0
var checks:=0
const OUT="/tmp/optimization-settings-20260909"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1
 print("PASS " if ok else "FAIL ",label)
func run() -> void:
 if "--crew-folder="+OUT not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1280,800)
 var settings:=FrontierClientSettings.ensure(self)
 settings.values=FrontierClientSettings.DEFAULTS.duplicate();settings.apply_all();settings._sync()
 check(settings.quality_controls.size()==4 and not settings.controls.has("ssao") and not settings.controls.has("shadow_filter"),"four understandable graphics groups replace technical controls")
 settings._preset(0)
 check(settings.quality_preset()==0 and not settings.values.ssao and not settings.values.local_shadows and root.msaa_3d==0,"low preset applies real rendering options")
 settings._preset(1)
 check(settings.quality_preset()==1 and settings.values.shadow_distance==120 and root.msaa_3d==1,"medium preset has bounded shadow distance and 2x AA")
 settings.set_quality("effects",0)
 check(settings.values.preset==3 and not settings.values.ssao and not settings.values.glow,"one group changes quality to custom")
 settings.controls.scale.value=75
 check(is_equal_approx(root.scaling_3d_scale,.75),"75 percent changes actual render scale")
 settings.set_option("fog",.7);settings.set_option("taa",true)
 settings.load_settings();settings._sync()
 check(settings.values.fog==.7 and settings.values.taa and settings.quality_level("effects")==-1,"legacy custom values remain readable and are labelled honestly")
 var viewport:=SubViewport.new();root.add_child(viewport)
 var world:=WorldEnvironment.new();world.environment=Environment.new();root.add_child(world)
 var sun:=DirectionalLight3D.new();sun.shadow_enabled=true;root.add_child(sun)
 await process_frame;await process_frame
 check(is_equal_approx(viewport.scaling_3d_scale,.75) and viewport.use_taa and not world.environment.ssao_enabled,"new scene inherits saved presentation options")
 settings._preset(2)
 check(sun.directional_shadow_max_distance==220 and world.environment.ssil_enabled,"high group applies to existing scene")
 # Inventory once, then cover immediate add/show/hide/reparent/free semantics.
 FrontierCursorPolicy.modal_open(self)
 var holder:=Node.new();root.add_child(holder)
 var popup:=Window.new();popup.visible=false;holder.add_child(popup)
 check(not FrontierCursorPolicy.modal_open(self),"hidden new window does not block")
 popup.show();check(FrontierCursorPolicy.modal_open(self),"new popup blocks in same frame")
 popup.hide();check(not FrontierCursorPolicy.modal_open(self),"hidden popup releases in same frame")
 popup.show();popup.reparent(root)
 check(FrontierCursorPolicy.modal_open(self),"reparented visible popup stays registered")
 popup.free();check(not FrontierCursorPolicy.modal_open(self),"freed popup releases without a stale frame")
 holder.free()
 settings._preset(1);settings.set_option("scale",1.0);settings.open()
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"/settings-1280.png")
 root.size=Vector2i(960,640)
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"/settings-960.png")
 check(settings.controls.scale.get_global_rect().end.y<640 and settings.quality_controls.anti_aliasing.is_visible_in_tree(),"graphics controls fit the small window")
 settings.tabs.current_tab=1
 settings.set_option("resolution",1)
 check(not settings.display_previous.is_empty(),"resolution retains reversible display confirmation")
 settings.display_deadline=Time.get_ticks_msec()-1
 await process_frame;await process_frame
 check(settings.display_previous.is_empty() and settings.values.resolution==0,"unconfirmed display rolls back")
 settings.close();viewport.queue_free();world.queue_free();sun.queue_free()
 # Cache must preserve generated heights and discard fallback coverage after loading/digging.
 var field:=FrontierTerrainField.new();field.configure(71491)
 var distant:=FrontierDistantTerrain.new();root.add_child(distant)
 var samples: Dictionary={}
 var arrays:=FrontierDistantTerrain._arrays(field,Vector3i.ZERO,2,600,samples)
 var reused:=FrontierDistantTerrain._arrays(field,Vector3i(1,0,0),2,600,samples)
 var fresh:=FrontierDistantTerrain._arrays(field,Vector3i(1,0,0),2,600)
 check(reused[Mesh.ARRAY_VERTEX]==fresh[Mesh.ARRAY_VERTEX] and reused[Mesh.ARRAY_NORMAL]==fresh[Mesh.ARRAY_NORMAL],"reused world samples preserve exact terrain geometry")
 distant.rebuild_fallback(field,Vector3i.ZERO,2,{})
 var mesh: Mesh=distant.get_node("StreamingFallback").mesh
 distant.rebuild_fallback(field,Vector3i.ZERO,2,{})
 check(mesh!=null and mesh==distant.get_node("StreamingFallback").mesh,"unchanged fallback keeps existing mesh")
 field.add_edit({"center":[2,2,2],"radius":5.0})
 distant.rebuild_fallback(field,Vector3i.ZERO,2,{})
 check(distant.get_node("StreamingFallback").mesh!=mesh,"dig invalidates cached fallback")
 var loaded: Dictionary={}
 for x in range(-3,4):
  for y in range(-8,8):
   for z in range(-3,4):loaded[Vector3i(x,y,z)]=true
 distant.rebuild_fallback(field,Vector3i.ZERO,2,loaded)
 check(distant.get_node("StreamingFallback").mesh==null,"loaded collision chunks remove fallback")
 distant.queue_free()
 # Atomic dig installs across frames, with a real mesher and collider.
 var stream:=FrontierTerrainStreamer.new();stream.configure(71491,[],StandardMaterial3D.new());root.add_child(stream)
 stream.config.active_radius=0;stream.config.vertical_radius=0;stream.update_interests([Vector3(0,2,0)])
 var deadline:=Time.get_ticks_msec()+15000
 while not stream.chunks.has(Vector3i.ZERO) and Time.get_ticks_msec()<deadline:await process_frame
 check(stream.chunks.has(Vector3i.ZERO),"budgeted streamer installs real terrain")
 stream.dig(Vector3(2,1,2),3)
 deadline=Time.get_ticks_msec()+15000
 while not stream.batch.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
 check(stream.batch.is_empty() and stream.prepared.is_empty() and stream.chunks[Vector3i.ZERO].revision==1,"dig mesh and collision commit together after preparation")
 stream.queue_free();await process_frame
 FileAccess.open(OUT+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("OPTIMIZATION_SETTINGS ",checks," FAILURES ",failures)
 quit(1 if failures else 0)
