extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/playtest-finch-takeoff"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var owner:=FrontierPlayerProfile.new_character("FINCH 단독 이륙 확인",0)
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(71503),owner,func(_world):return true),"isolated solo host")
 var world: Dictionary=core.world
 var body: Dictionary={}
 for ordinal in range(8,200):
  var candidate:=FrontierUniverse.body(world.manifest,ordinal)
  if FrontierUniverse.landable(candidate) and int(candidate.planet_tier)==1:body=candidate;break
 if body.is_empty():quit(1);return
 var actor: String=owner.character_id
 var nav: Dictionary=world.crew.navigation
 nav.system=body.system_ordinal;nav.target=body.ordinal;nav.mode="idle";nav.erase("solar_opening")
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(body.ordinal,world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+2))
 world.crew.members[actor].ready=true;core.phase="playing";world.crew.phase="playing"
 var reason:=FrontierCrewSurface.apply(world,actor,"land",{"ordinal":body.ordinal},{1:actor})
 check(reason.is_empty(),"landed fixture "+reason)
 var store:=FrontierWorldStore.new(folder+"/world.json")
 check(store.write(world),"save isolated landing "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"actual landed solo scene",90):quit(1);return
 app.onboarding.letter.hide();app.close_menus();app.session.response_received.connect(func(_seq,result):print("FINCH_REPLY ",result.get("ok")," ",result.get("error","")))
 core=app.session.authority;world=core.world
 world.crew.navigation.orbit_time=maxf(40,float(world.crew.navigation.orbit_time))
 var ship_point:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(25,0,15)
 ship_point.y=app.surface_world.terrain.field.height(ship_point.x,ship_point.z)
 var craft: Dictionary={"state":"docked","pad_slot":0,"progress":1.0,"factory_id":"fixture","system":int(world.crew.navigation.system),"location":world.location,"navigation_target":world.location,"navigation":world.crew.navigation.duplicate(true),"landing":world.crew.landing.duplicate(true),"cargo":{"iron":7},"cargo_equipment":{},"rock":0,"deployment":{"body_id":world.location,"position":FrontierExpeditionBusiness.array(ship_point),"yaw":.7,"time":float(world.crew.navigation.orbit_time)-20}}
 world.crew.shuttles={actor:craft}
 check(FrontierUniverse.validate_world(world).is_empty(),"sortie fixture validates: "+FrontierUniverse.validate_world(world))
 var standing:=ship_point+Vector3(3,0,0);standing.y=app.surface_world.terrain.field.height(standing.x,standing.z)+.1
 world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing);app.actors[actor].position=standing;app.session._publish()
 if not await until(func():return app.surface_world.refits.requested_hull.is_empty() and app.surface_world.shuttle_models.has(actor),"docked source and FINCH displayed",30):quit(1);return
 await capture("before-board")
 var mother: Dictionary=world.crew.navigation.duplicate(true)
 app.session.send_request("shuttle_board",{})
 if not await until(func():return app.arrival.active,"host accepts solo FINCH boarding",12):quit(1);return
 var entered_ascent:=false;var deadline:=Time.get_ticks_msec()+25000
 while app.arrival.active and Time.get_ticks_msec()<deadline:
  if app.arrival.phase=="ascent" and not entered_ascent:
   entered_ascent=true
   check(is_instance_valid(app.arrival.landing_camera),"ascent has a prepared camera")
   if not is_instance_valid(app.arrival.landing_camera):break
   check(app.arrival.ship_home.distance_to(ship_point)<2,"takeoff starts at deployed FINCH ground position")
   await capture("ascent")
  await process_frame
 check(entered_ascent and not app.arrival.active and app.surface_world==null and app.outside,"ascent hands control to actual orbital flight")
 check(core.world.crew.landing.get("body_id","")==body.id and int(core.world.crew.navigation.system)==int(mother.system),"mother ship remains on original planet")
 check(core.world.crew.shuttles[actor].cargo.get("iron")==7,"solo sortie keeps freight")
 if not app.arrival.active:await capture("orbit")
 check(await app.session.close_session(),"save closes after sortie")
 var loaded:=store.read_state()
 check(not loaded.is_empty() and FrontierShuttles.aboard(loaded,actor) and loaded.crew.shuttles[actor].cargo.get("iron")==7,"sortie and cargo reload")
 app.queue_free();await process_frame
 print("FINCH_TAKEOFF checks ",checks," failures ",failures);quit(1 if failures else 0)
