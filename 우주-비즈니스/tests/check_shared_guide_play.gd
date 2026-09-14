extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/shared-guide-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"landed shared guide review",90):quit(1);return
 app.set_process(false);app.set_physics_process(false);app.close_menus()
 var guide:=app.onboarding
 guide.set_process(false);guide.welcome_pending=false;guide.letter.hide()
 var core:=app.session.authority
 core.resolve_autonomous(true)
 app.session.set_process(false);app.session.set_physics_process(false)
 core.save_request=Callable()
 var guest:=FrontierPlayerProfile.new_character("현장 건설 동료",1)
 var admission:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
 check(admission.ok and core.acknowledge(2,core.session_id).ok,"guest joins actual expedition authority")
 if not admission.ok:quit(1);return
 var actor: String=guest.character_id
 var world: Dictionary=core.world
 var member: Dictionary=world.crew.members[actor];member.area="surface";member.aboard=false
 var cost: Dictionary=FrontierFacilityResearch.construction("solar").cost
 world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 for resource in cost:world.business.bags[actor][resource]=cost[resource]
 var field:=app.surface_world.terrain.field
 var point:=Vector3.INF
 for x in range(-40,41,4):
  if point.is_finite():break
  for z in range(-40,41,4):
   var p:=FrontierExpeditionBusiness.ground(field,x,z,2.2)
   if not p.is_finite():continue
   member.position=FrontierExpeditionBusiness.array(p+Vector3(0,.1,5))
   if FrontierExpeditionBusiness.build_reason(world,actor,"solar",p,core.peers).is_empty():point=p;break
 check(point.is_finite(),"guest valid building location")
 if not point.is_finite():quit(1);return
 var host: String=world.crew.owner_id
 world.crew.members[host].position=FrontierExpeditionBusiness.array(point+Vector3(0,.1,7));app.actors[host].position=point+Vector3(0,.1,7)
 publish_host()
 await until(func():return app.surface_world.ready_at(point),"construction terrain ready",45)
 guide.progress={"eligible":true,"travel":true,"inventory":true,"field_scan":true,"mined":true,"materials_review":true}
 guide.card.position=Vector2(28,170);guide.card.show();guide.field_instruction()
 check(guide.step=="build","host waits at shared construction step")
 app.camera.set_as_top_level(true);app.camera.position=point+Vector3(5,4,6);app.camera.look_at(point)
 await capture("before-guest-build")
 core.resolve_autonomous(true)
 for resource in cost:core.world.business.bags[actor][resource]=cost[resource]
 core.world.crew.members[actor].position=FrontierExpeditionBusiness.array(point+Vector3(0,.1,5))
 var before: int=FrontierExpeditionBusiness.site(core.world).buildings.size()
 var recorder:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("SFX");AudioServer.add_bus_effect(bus,recorder);recorder.set_recording_active(true)
 var result:=core.request(2,{"session_id":core.session_id,"sequence":1,"revision":core.world.crew.revision,"kind":"business_build","args":{"building":"solar","position":FrontierExpeditionBusiness.array(point),"yaw":PI*.5}})
 publish_host()
 check(result.get("ok",false) or result.get("pending",false),"guest build enters normal commit")
 if not await until(func():return FrontierExpeditionBusiness.site(core.world).buildings.size()==before+1,"guest building committed",20):quit(1);return
 guide.field_instruction()
 check(guide.progress.get("built",false) and guide.step=="terraform","host advances when guest alone builds")
 check(core.snapshot(2).crew.play_guide.get("built",false),"guest receives same completion")
 var id: String=FrontierExpeditionBusiness.site(core.world).buildings.keys().back()
 await until(func():return app.surface_world.business_view.nodes.has(id),"guest model reaches scene",10)
 var node: Node3D=app.surface_world.business_view.nodes[id]
 check(node.get_meta("constructing",false),"guest build starts shared observer animation")
 for i in 4:
  await create_timer(.25).timeout;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder+"/live-assembly-"+str(i)+".png")
 await until(func():return not node.get_meta("constructing",false),"live animation completes without pausing",5)
 recorder.set_recording_active(false);var recording:=recorder.get_recording();recording.save_to_wav(folder+"/construction-sfx.wav");AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
 check(recording.data.size()>0,"construction audio produces recorded SFX samples")
 await capture("shared-after")
 # Same UI consumer with an empty local history for a newly observed character.
 var late:=core.snapshot(2);guide.player_key="";guide.new_player=true
 guide.update_snapshot(late)
 check(guide.progress.get("built",false),"empty local guide inherits expedition completion")
 check(await app.session.close_session(),"shared progression saved")
 var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(saved.crew.play_guide.built,"saved shared build milestone remains")
 app.queue_free();await process_frame;print("SHARED_GUIDE_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

func publish_host() -> void:
 # UI fixture has logical admitted peers, no remote sockets; render only its local packet.
 var members: Dictionary=app.session.authority.peers
 app.session.authority.peers={1:members[1]}
 app.session._publish();app.session._publish_surface()
 app.session.authority.peers=members
