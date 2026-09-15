extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/followup-stellar-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 var store:=FrontierWorldStore.new(folder+"/world.json")
 check(store.write(FrontierUniverse.new_world(61739)),"fresh isolated route fixture")
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 app.session.set_physics_process(false);app.set_physics_process(false)
 if not await until(func():return app.flight!=null and not app.preparing_first_snapshot,"flight prepared",90):quit(1);return
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var a:=app.session.authority
 FrontierSolarOpening.step(a.world,30);app.session._publish();app.onboarding.letter.hide()
 app.onboarding.progress.solar_move=true;app.onboarding.progress.solar_boost=true;app.onboarding.progress.solar_scan=true
 var m: Dictionary=a.world.manifest
 var destination:=-1
 for i in 10000:
  if i==0 or FrontierUniverse.map_position(m,0).distance_to(FrontierUniverse.map_position(m,i))>FrontierVesselRefit.stellar_range(a.world):continue
  var ordinal:=FrontierUniverse.first_ordinal(m,i)
  if FrontierVesselAccess.departure_reason(a.world,ordinal).is_empty():destination=ordinal;break
 check(destination>=0,"stock ship route available")
 app.session.set_physics_process(true)
 app.navigation_ui.start_route(destination)
 if not await until(func():return a.world.crew.navigation.mode=="jump","actual route departure",20):quit(1);return
 check(float(a.world.crew.navigation.transit.duration)>=18,"extended departure and arrival time")
 for fraction in [.12,.25,.72,.9,.97]:
  await until(func():return float(app.session.latest.crew.navigation.get("transit",{}).get("progress",1))>=fraction,"transit phase "+str(fraction),30)
  await capture("transit-"+str(int(fraction*100)))
 await until(func():return a.world.crew.navigation.mode!="jump","arrival reaches destination",30)
 await create_timer(1).timeout;await capture("arrival-planet")
 check(int(a.world.crew.navigation.system)==FrontierUniverse.system_index(m,destination),"correct target system")
 check(await app.session.close_session(),"close route fixture")
 print("FOLLOWUP_TRAVEL ",checks," failures ",failures);app.queue_free();await process_frame;quit(1 if failures else 0)
