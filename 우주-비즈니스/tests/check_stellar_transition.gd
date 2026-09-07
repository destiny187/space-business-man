extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800)
 var m:=FrontierUniverse.generate(61739)
 var target:=FrontierCrewNavigation.first_destination(m)
 var origin:=FrontierUniverse.entry_position(m,2,0)
 var facing: Vector3=-origin.normalized()
 var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
 var nav: Dictionary={"system":0,"target":target,"position":[origin.x,origin.y,origin.z],"direction":[facing.x,facing.y,facing.z],"speed":0.0,"mode":"idle","orbit_time":0.0,"jump_left":12.0,"transit":{"progress":0.0,"duration":12.0}}
 view.exterior=true;view.update_navigation(nav)
 await create_timer(.5).timeout
 var out:=ProjectSettings.globalize_path("res://../test-results/stellar-transition")
 DirAccess.make_dir_recursive_absolute(out)
 for percent in [0,12,24,36,46,50,56,68,82,94,100]:
  var p:=float(percent)/100.0
  nav.mode="jump";nav.transit.progress=p;nav.jump_left=12*(1-p)
  view.update_navigation(nav)
  await create_timer(.45).timeout
  assert(view.current_system==(0 if p<.5 else FrontierUniverse.system_index(m,target)))
  assert(view.camera.far>view.ship.position.length()+85000)
  if p==.5:assert(not view.system_art.visible)
  if p==.24 or p==.82:assert(view.system_art.visible)
  if "--capture" in OS.get_cmdline_user_args():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(out+"/phase-%03d.png"%percent)
 var end:=view._display_position(nav)
 assert(end.is_equal_approx(FrontierUniverse.entry_position(m,target,0)))
 nav.mode="idle";nav.system=FrontierUniverse.system_index(m,target)
 nav.position=[end.x,end.y,end.z]
 var direction: Vector3=(FrontierUniverse.entry_focus(m,target,0)-end).normalized()
 nav.direction=[direction.x,direction.y,direction.z]
 view.update_navigation(nav)
 assert(view._display_position(nav).is_equal_approx(end))
 for geometry in view.transit_geometry:assert(geometry.transparency==0)
 print("STELLAR TRANSITION PASS: departing and arriving visibility, hidden swap, far plane, final pose continuity")
 view.queue_free();await process_frame;quit()
