extends SceneTree
func _initialize() -> void:run.call_deferred()
func persist(world: Dictionary) -> bool:return FrontierUniverse.validate_world(world).is_empty()
func run() -> void:
 root.size=Vector2i(1280,800)
 var core:=FrontierCrewAuthority.new()
 assert(core.start(FrontierUniverse.new_world(61739),FrontierPlayerProfile.new_character("전방 출발"),persist))
 var world: Dictionary=core.world
 var owner: String=world.crew.owner_id
 var m: Dictionary=world.manifest
 var nav: Dictionary=world.crew.navigation
 var view:=FrontierCrewFlightView.new();view.state={"manifest":m};root.add_child(view)
 view.exterior=true;view.update_navigation(nav)
 await create_timer(.5).timeout
 var origin:=FrontierCrewWorld.vector(nav.position)
 var initial:=FrontierCrewWorld.vector(nav.direction)
 world.crew.members[owner].ready=true
 assert(FrontierCrewNavigation.apply(world,owner,"tutorial_depart",{},{1:owner}).is_empty())
 var direction:=FrontierCrewWorld.vector(nav.transit.departure_direction)
 assert(direction.dot(initial)<.99,"Earth blocks the original forward direction")
 assert(direction.dot(initial)>0,"a clear forward-side corridor is preferred over reversing")
 assert(FrontierCrewNavigation.validate(nav).is_empty())
 var restored: Dictionary=JSON.parse_string(JSON.stringify(world))
 assert(FrontierCrewWorld.vector(restored.crew.navigation.transit.departure_direction).is_equal_approx(direction))
 view.update_navigation(nav)
 var folder:=ProjectSettings.globalize_path("res://../test-results/forward-departure")
 DirAccess.make_dir_recursive_absolute(folder)
 var aligned:=false;var previous:=origin
 for frame in 360:
  FrontierCrewNavigation.step(world,1.0/60.0)
  view.update_navigation(nav)
  await process_frame
  var progress: float=nav.transit.progress
  var point:=view._display_position(nav)
  if progress<=.2:assert(point.is_equal_approx(origin),"no thrust translation before alignment")
  if progress>.23 and progress<.49:
   var movement:=point-previous
   assert(movement.length_squared()>0)
   assert(movement.normalized().dot(-view.ship.basis.z)>.99,"translation follows ship nose")
   assert((-view.camera.global_basis.z).dot(direction)>.90,"camera follows forward flight")
   # Check actual moving planet envelopes against the displayed route, independently of the chooser.
   for i in FrontierUniverse.body_count(m,0):
    var body:=FrontierUniverse.body(m,i)
    assert(point.distance_to(FrontierUniverse.position(m,i,float(nav.orbit_time)))>FrontierUniverse.navigation_radius(body)+100)
   aligned=true
  if frame in [90,155,240]:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/frame-%03d.png"%frame)
  previous=point
 assert(aligned)
 print("FORWARD DEPARTURE PASS: clear forward corridor, turn before motion, forward camera, moving-body clearance, persisted route")
 view.queue_free();await process_frame;quit()
