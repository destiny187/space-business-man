extends "res://tests/check_wildlife_combat.gd"
func run() -> void:
 folder="/tmp/flight-jetpack-play";fixture_construction="avian"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/flight-jetpack-play" not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 check(fixture(),"natural aggressive surface-air home")
 if chosen.is_empty():quit(1);return
 core.world.business.bags[actor_id]=FrontierExpeditionBusiness.inventory()
 for id in FrontierEquipment.config().items.jetpack_2.cost:core.world.business.bags[actor_id][id]=10
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"flight play fixture saved "+store.last_error)
 if failures:quit(1);return
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"flight field Forward+ ready",100):quit(1);return
 core=app.session.authority;app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 var at:=home+Vector3(0,0,8);at.y=field.height(at.x,at.z)+.2;place(at)
 var ecology: FrontierSurfaceEcology=app.surface_world.ecology
 if not await until(func():return ecology.actors.has(chosen.id) and ecology.actors[chosen.id].models.size()==2,"natural flying rig loaded",60):quit(1);return
 animal=ecology.actors[chosen.id]
 # Rejoining releases the old session bag into a recovery crate. Seed crafting
 # materials only after this normal reconnect transition has completed.
 core.world.business.bags[actor_id]=FrontierExpeditionBusiness.inventory()
 for id in FrontierEquipment.config().items.jetpack_2.cost:core.world.business.bags[actor_id][id]=int(FrontierEquipment.config().items.jetpack_2.cost[id])
 core.world.crew.members[actor_id].vitals.protection=10.;app.session._publish()
 app.session.response_received.connect(func(_sequence,result):print("FLIGHT_REQUEST ",{"ok":result.get("ok"),"error":result.get("error",""),"sequence":result.get("sequence")}))
 app.session.notice.connect(func(message):print("FLIGHT_NOTICE ",message," store=",app.session.store.last_error," core=",core.error))
 app.toggle_inventory();await process_frame
 var panel: FrontierEquipmentPanel=app.inventory_panel
 panel.tabs.current_tab=1;panel.selected_definition="jetpack_2";panel._refresh_details();panel._action()
 if not await until(func():return core.world.crew.members[actor_id].loadout.items.values().has("jetpack_2"),"craft through actual inventory request",15):quit(1);return
 var member: Dictionary=core.world.crew.members[actor_id];var item_id: String=""
 for id in member.loadout.items:
  if member.loadout.items[id]=="jetpack_2":item_id=id
 panel.tabs.current_tab=0;panel.selected_item=item_id;panel.selected_definition="jetpack_2";panel._refresh_details();panel._action()
 if not await until(func():return FrontierEquipment.jetpack(core.world.crew.members[actor_id]),"back equipment confirmed by host",15):quit(1);return
 await capture("inventory-jetpack")
 app.close_menus();await create_timer(.3).timeout
 if not await until(func():return app._locomotion_enabled(),"campaign movement input ready",15):
  print("CONTROL_GATE ",{"menus":app.any_menu_open(),"blocked":app.feedback.blocked(),"outside":app.outside,"letter":app.onboarding.letter.visible,"focus":str(app.get_viewport().gui_get_focus_owner()),"ready":app.surface_world.ready_at(app.actors[actor_id].position),"position":app.actors[actor_id].position,"observer":app.observer.input_blocked(),"settings":FrontierClientSettings.ensure(self).is_open()})
  for node in root.find_children("*","Window",true,false):
   if node.visible:print("OPEN_WINDOW ",node.get_path())
  await capture("blocked-input");quit(1);return
 var recording:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recording);recording.set_recording_active(true)
 if not await until(func():return core.motions.get(actor_id,{}).get("grounded",false),"player grounded before jump",8):
  print("JET_MOTION_DEBUG ",core.motions.get(actor_id,{})," enabled ",app._locomotion_enabled());quit(1);return
 app.test_jump=true
 if not await until(func():return not core.motions.get(actor_id,{}).get("grounded",true) and int(core.motions.get(actor_id,{}).get("jump_serial",0))>0,"normal jump leaves terrain",5):
  print("JET_MOTION_DEBUG ",core.motions.get(actor_id,{})," enabled ",app._locomotion_enabled());quit(1);return
 check(not core.motions.get(actor_id,{}).get("jet_active",false),"initial held Space remains a normal jump in campaign")
 app.test_jump=false;await create_timer(.1).timeout
 var height: float=app.actors[actor_id].position.y
 app.test_jump=true
 if not await until(func():return core.motions.get(actor_id,{}).get("jet_active",false),"second held Space engages host thrust",5):
  print("JET_MOTION_DEBUG ",core.motions.get(actor_id,{})," inputs ",core.inputs," enabled ",app._locomotion_enabled());quit(1);return
 await create_timer(.8).timeout;aim();await capture("jetpack-ascent")
 check(app.actors[actor_id].position.y>height+1,"real campaign player gains height")
 check(app.visuals[actor_id].jetpack.speaker.playing,"confirmed jet thrust plays existing ElevenLabs SFX")
 # Inspect the actual worn mesh in a temporary review camera, without changing player controls.
 app.test_jump=false;await create_timer(.15).timeout
 check(not core.motions[actor_id].jet_active,"release stops campaign thrust")
 app.set_process(false)
 var camera_transform: Transform3D=app.camera.transform
 app.visuals[actor_id].model.visible=true;app.visuals[actor_id].jetpack.pack.visible=true
 var center: Vector3=app.actors[actor_id].position+Vector3.UP
 app.camera.position=center+Vector3(3,1,3);app.camera.look_at(center)
 await capture("worn-jetpack")
 app.camera.transform=camera_transform;app.set_process(true)
 core.world.crew.members[actor_id].vitals.protection=0
 var saw_attack:=false;var shots:=0;var deadline:=Time.get_ticks_msec()+30000
 while Time.get_ticks_msec()<deadline and shots<28 and int(core.world.crew.get("combat",{}).get(key,1))>0:
  aim()
  if core.stopped:
   print("FLIGHT_STOPPED ",app.session.store.last_error," crew ",FrontierCrewWorld.validate(core.world.crew));break
  var live:=FrontierWildlifeCombat.state(core.world.crew,body.id,chosen)
  if not live.is_empty() and live.phase=="attack" and not saw_attack:saw_attack=true;await capture("aerial-attack")
  if shots<2 or saw_attack:app.firearm.shoot();shots+=1
  await create_timer(.24).timeout
 check(saw_attack,"natural flight AI attacks in actual campaign")
 check(int(core.world.crew.get("combat",{}).get(key,1))==0,"equipped firearm defeats moving flier")
 if int(core.world.crew.get("combat",{}).get(key,1))==0:
  await create_timer(2.).timeout;await capture("aerial-down")
  check(core.world.crew.wildlife_stops.has(key),"downed flying native stores its final position")
 recording.set_recording_active(false);recording.get_recording().save_to_wav(folder+"/flight-runtime.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 check(await app.session.close_session(),"flight and equipment save closes")
 var loaded:=store.read_state()
 check(not loaded.is_empty() and FrontierEquipment.jetpack(loaded.crew.members[actor_id]) and int(loaded.crew.get("combat",{}).get(key,1))==0,"backpack and downed flier reload")
 app.queue_free();await process_frame
 print("FLIGHT_JETPACK_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
