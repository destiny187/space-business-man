extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,800)
 var world:=FrontierUniverse.new_world(61739)
 var nav:=FrontierCrewNavigation.create(world)
 var m: Dictionary=world.manifest
 assert(FrontierUniverse.ordinal_of(m,world.location)==2 and nav.system==0 and nav.mode=="idle")
 var earth:=FrontierUniverse.position(m,2)
 var point:=FrontierCrewWorld.vector(nav.position)
 assert(is_equal_approx(point.distance_to(earth)-FrontierUniverse.navigation_radius(FrontierUniverse.body(m,2)),float(m.settings.flight.arrival_clearance)))
 assert(point.length()<FrontierUniverse.orbit_radius(m,0,7))
 var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
 view.exterior=true;view.update_navigation(nav)
 assert(view.ship.position.is_equal_approx(point))
 assert(view.transit_overlay.arrival_name.is_empty() and view.soundscape.pending_tier==-1)
 await create_timer(.8).timeout
 assert(not view.soundscape.arrival.playing)
 assert((-view.ship.basis.z).dot((earth-point).normalized())>.99)
 await RenderingServer.frame_post_draw
 var folder:=ProjectSettings.globalize_path("res://../test-results/solar-start")
 DirAccess.make_dir_recursive_absolute(folder);root.get_texture().get_image().save_png(folder+"/earth-start.png")
 var target:=FrontierCrewNavigation.first_destination(m)
 nav.mode="jump";nav.target=target;nav.transit={"progress":.7,"duration":12.0};nav.jump_left=3.6
 view.update_navigation(nav)
 assert(view._display_position(nav).distance_to(FrontierUniverse.entry_position(m,target,0))>10000)
 nav.mode="idle";nav.system=FrontierUniverse.system_index(m,target)
 var entry:=FrontierUniverse.entry_position(m,target,0)
 nav.position=[entry.x,entry.y,entry.z];view.update_navigation(nav)
 assert(not view.transit_overlay.arrival_name.is_empty() and view.soundscape.pending_tier>=0)
 print("SOLAR START PASS: Earth orbit, immediate pose, no initial arrival effects, later interstellar effects preserved")
 view.queue_free();await process_frame;quit()
