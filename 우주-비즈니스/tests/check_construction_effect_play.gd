extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/construction-effect-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"landed design review",90):quit(1);return
 app.onboarding.welcome_pending=false;app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var actor: String=app.session.latest.self_id
 var world: Dictionary=app.session.authority.world
 var field:=app.surface_world.terrain.field
 world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 var cost: Dictionary=FrontierFacilityResearch.construction("solar").cost
 for resource in cost:world.business.bags[actor][resource]=cost[resource]
 var point:=Vector3.INF
 for x in range(-30,31,4):
  if point.is_finite():break
  for z in range(-30,31,4):
   var p:=FrontierExpeditionBusiness.ground(field,x,z,2.2)
   if not p.is_finite():continue
   var position_value:=p+Vector3(0,0,7);position_value.y=field.height(position_value.x,position_value.z)+.1
   world.crew.members[actor].position=FrontierExpeditionBusiness.array(position_value)
   if FrontierExpeditionBusiness.build_reason(world,actor,"solar",p,{1:actor}).is_empty():point=p;app.actors[actor].position=position_value;break
 check(point.is_finite(),"valid unchanged construction footprint")
 if not point.is_finite():quit(1);return
 app.session._publish()
 await until(func():return app.surface_world.ready_at(point),"placement terrain ready",45)
 app.camera.set_as_top_level(true);app.camera.position=point+Vector3(5,4,6);app.camera.look_at(point)
 check(app.surface_world.business_view.construction_effects.is_empty(),"loaded buildings do not replay construction")
 app.toggle_business();await create_timer(.5).timeout;await capture("build-cards")
 app.business_panel.building_cards.solar.pressed.emit();await physics_frame
 app._update_business_placement()
 check(app.placement_kind=="solar" and app.placement_ghost!=null and app.placement_valid,"B card opens valid new-model ghost")
 await capture("solar-ghost")
 var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;app._unhandled_input(wheel)
 check(app.placement_rotation==1,"new model keeps wheel rotation")
 app.feedback.handheld.hide()
 var unrelated:=app.surface_world.business_view.nodes.duplicate()
 var before: int=FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()
 var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;app._unhandled_input(click)
 if not await until(func():return FrontierExpeditionBusiness.site(app.session.authority.world).buildings.size()==before+1,"host installs rendered building",20):quit(1);return
 var site:=FrontierExpeditionBusiness.site(app.session.authority.world)
 var id: String=site.buildings.keys().back()
 await until(func():return app.surface_world.business_view.nodes.has(id),"placed Blender model arrives",20)
 var solar: Node3D=app.surface_world.business_view.nodes[id]
 check(is_equal_approx(solar.rotation.y,PI*.5),"installed rotation matches ghost")
 var fx: FrontierConstructionPresentation
 for child in solar.get_children():
  if child is FrontierConstructionPresentation:fx=child
 check(fx!=null,"accepted model owns construction effect")
 if fx==null:quit(1);return
 fx.set_process(false)
 check(app.feedback.audio.last_played.has("sfx_build_place"),"placement sound played")
 check(not fx.solid.is_empty() and fx.hologram!=null,"real model reveal and matching hologram")
 app.feedback.set_process(false);app.feedback.handheld.hide()
 for phase in [.05,.36,.65,.90]:
  fx.apply_frame(phase);await capture("assembly-"+str(int(phase*100)))
 check(unrelated.keys().all(func(key):return not app.surface_world.business_view.nodes.has(key) or app.surface_world.business_view.nodes[key]==unrelated[key]),"unrelated model identities retained")
 var same_count:=app.surface_world.business_view.construction_effects.size()
 app.feedback._surface(app.session.surface)
 check(app.surface_world.business_view.construction_effects.size()==same_count,"repeated surface packet does not replay")
 var revealed:=fx.solid.duplicate();fx.age=fx.duration-.1;fx.set_process(true)
 await create_timer(.3).timeout
 check(not solar.get_meta("constructing",false),"finite animation restores building")
 check(revealed.all(func(mesh):return float(mesh.get_instance_shader_parameter("construction_level"))>1e19),"per-instance clipping restored")
 check(app.feedback.audio.last_played.has("sfx_factory_complete"),"completion sound played")
 await capture("solar-installed")
 # The bag is empty after one successful build: an invalid request must not emit.
 var results: Array=[]
 app.session.response_received.connect(func(_sequence,value):results.append(value))
 var effects_before:=app.surface_world.business_view.construction_effects.size()
 app.session.send_request("business_build",{"building":"solar","position":FrontierExpeditionBusiness.array(point+Vector3(6,0,0))})
 await until(func():return not results.is_empty(),"rejection reply",20)
 check(not results.back().ok,"invalid placement rejected")
 check(app.surface_world.business_view.construction_effects.size()==effects_before,"rejected request emits no construction")
 check(cost.keys().all(func(resource):return int(app.session.authority.world.business.bags[actor][resource])==0),"original construction cost charged once")
 check(await app.session.close_session(),"placed building save closes")
 var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(saved.business.sites[world.location].buildings.has(id),"placed building survives reload")
 app.queue_free();await process_frame;print("CONSTRUCTION_EFFECT_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
