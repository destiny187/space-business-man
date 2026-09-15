extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/field-manufacturing-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 for file in ["world.json","profile.json"]:DirAccess.copy_absolute("/tmp/playtest-field-research/"+file,folder+"/"+file)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"isolated field prepared",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var a:=app.session.authority
 var actor: String=app.session.latest.self_id
 var field:=app.surface_world.terrain.field
 var ids: Dictionary={}
 for kind in ["storage","solar","field_canopy","metalworks","equipment_workbench"]:
  var world: Dictionary=a.world
  var def:=FrontierFacilityResearch.construction(kind)
  for resource in def.cost:world.business.bags[actor][resource]=int(world.business.bags[actor].get(resource,0))+int(def.cost[resource])
  var at:=Vector3.INF
  for x in range(-36,37,4):
   if at.is_finite():break
   for z in range(-36,37,4):
    var p:=FrontierExpeditionBusiness.ground(field,x,z,float(def.radius))
    if not p.is_finite():continue
    var standing:=p+Vector3(0,0,6);standing.y=field.height(standing.x,standing.z)+.1
    world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing)
    if FrontierExpeditionBusiness.build_reason(world,actor,kind,p,{1:actor}).is_empty():at=p;app.actors[actor].position=standing;break
  if not at.is_finite():check(false,"valid placement "+kind);quit(1);return
  app.session._publish()
  app.camera.set_as_top_level(true);app.camera.position=at+Vector3(5,4,-7);app.camera.look_at(at+Vector3.UP)
  app.toggle_business();await process_frame
  check(app.business_panel.building_cards.has(kind) and app.business_panel.building_cards[kind].visible,"B contains "+kind+" card")
  await capture("cards-"+kind)
  app.close_menus()
  var count: int=FrontierExpeditionBusiness.site(a.world).buildings.size()
  app.session.send_request("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(at),"yaw":0.0})
  if not await until(func():return FrontierExpeditionBusiness.site(a.world).buildings.size()>count,"host builds "+kind,20):quit(1);return
  var id: String=FrontierExpeditionBusiness.site(a.world).buildings.keys().back();ids[kind]=id
  await until(func():return app.surface_world.business_view.nodes.has(id),"game model "+kind,20)
  await create_timer(2.).timeout;await capture("placed-"+kind)
 a.world.business.bags[actor].iron=30;a.world.business.bags[actor].copper=30
 app.session._publish();app.open_station("equipment_workbench",ids.equipment_workbench)
 await create_timer(.4).timeout
 check(app.inventory_panel.tabs.current_tab==1 and not app.inventory_panel.tabs.is_tab_hidden(1),"F workbench opens equipment recipes")
 app.inventory_panel.selected_definition="pulse_1";app.inventory_panel.last_key=""
 await create_timer(.4).timeout;await capture("workbench-recipes")
 var before: int=a.world.crew.members[actor].loadout.items.size()
 app.inventory_panel.action.pressed.emit()
 check(await until(func():return a.world.crew.members[actor].loadout.items.size()>before,"workbench button crafts weapon",20),"actual craft confirmation")
 app.close_menus();app.open_menu(app.inventory_panel);await process_frame
 check(app.inventory_panel.tabs.is_tab_hidden(1),"I inventory hides remote equipment production")
 app.close_menus()
 var factory: Dictionary=FrontierExpeditionBusiness.site(a.world).buildings[ids.metalworks]
 var p:=FrontierCrewWorld.vector(factory.position)+Vector3(0,0,6);p.y=field.height(p.x,p.z)+.1
 a.world.crew.members[actor].position=FrontierExpeditionBusiness.array(p);app.actors[actor].position=p
 var local: Dictionary=a.world
 FrontierExpeditionBusiness.site(local).inventory.iron=20
 app.session._publish();app.open_station("metalworks",ids.metalworks);await create_timer(.4).timeout
 var production:=app.business_panel.production_panel
 production.selected_product="refined_iron";production.refresh()
 check(production.produce.visible and production.product_cards.refined_iron.visible and not production.product_cards.control_circuit.visible,"metal factory shows its dedicated products")
 await capture("metalworks-production")
 production.produce.pressed.emit()
 await until(func():return not FrontierExpeditionBusiness.site(a.world).buildings[ids.metalworks].get("production",{}).is_empty(),"factory queues actual refinement",20)
 app.close_menus();app.camera.position=FrontierCrewWorld.vector(factory.position)+Vector3(5,5,-7);app.camera.look_at(FrontierCrewWorld.vector(factory.position)+Vector3.UP*1.5)
 var visual: Node3D=app.surface_world.business_view.nodes[ids.metalworks]
 var piston: Node3D=visual.find_child("Anim_Piston_Press",true,false)
 var pose:=piston.transform;await create_timer(.4).timeout
 check(piston.transform!=pose,"powered metal press animates in actual field")
 await capture("metalworks-working")
 await until(func():return FrontierExpeditionBusiness.site(a.world).buildings[ids.metalworks].get("production",{}).is_empty(),"refinement completes",20)
 await check_scan_and_guide()
 check(await app.session.close_session(),"normal save closes")
 var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
 check(not saved.is_empty() and saved.business.sites[a.world.location].buildings.has(ids.equipment_workbench),"new buildings survive reload")
 app.queue_free();await process_frame;print("FIELD_MANUFACTURING_PLAY ",checks," failures ",failures);quit(1 if failures else 0)
func check_scan_and_guide() -> void:
 var a:=app.session.authority
 var actor: String=app.session.latest.self_id
 var body: Dictionary=app.surface_world.body
 var terrain:=app.surface_world.terrain.field
 var selected: Dictionary={};var aim:=Vector3.FORWARD
 for vein in FrontierExpeditionBusiness.veins(body,app.actors[actor].position):
  if vein.get("underground",false):continue
  var ground:=FrontierExpeditionBusiness.ground(terrain,vein.position[0],vein.position[2])
  if not ground.is_finite():continue
  var standing:=ground+Vector3(0,0,4);standing.y=terrain.height(standing.x,standing.z)+.1
  a.world.crew.members[actor].position=FrontierExpeditionBusiness.array(standing)
  aim=(ground+Vector3.UP-standing-Vector3.UP*1.72).normalized()
  selected=FrontierSurfaceSurvey.target(a.world,actor,aim)
  if selected.get("kind","")=="mineral":
   app.actors[actor].position=standing;app.camera.position=standing+Vector3.UP*1.72;app.camera.look_at(ground+Vector3.UP);break
 if selected.get("kind","")!="mineral":check(false,"mineral scan target available");return
 app.session._publish()
 var completed:=false
 for tick in 100:
  app.session.send_input(Vector2.ZERO,aim,true)
  await create_timer(.1).timeout
  if app.session.latest.get("scan",{}).get("known",false):completed=true;break
 check(completed,"actual scan input produces host result")
 app.session.send_input(Vector2.ZERO,aim,false)
 await create_timer(.2).timeout
 var card: FrontierSurveyCard=null
 for child in app.find_children("*","PanelContainer",true,false):
  if child is FrontierSurveyCard:card=child;break
 check(card!=null and card.visible,"result remains after scan release")
 if card==null:return
 app.camera.look_at(app.camera.position+aim*-10)
 await create_timer(.2).timeout;await capture("scan-result-after-turn-960")
 check(card.visible and card.get_global_rect().end.x<=960 and card.get_global_rect().end.y<=640,"offscreen scan result remains readable at 960")
 app.onboarding.progress={"eligible":true,"field_scan":false,"inventory":false}
 app.onboarding.field_instruction();check(app.onboarding.step=="field_scan","guide skips collector equip")
 for key in ["field_scan","mined","materials_review","built","terraform_view","complete"]:app.onboarding.progress[key]=true
 app.onboarding.field_instruction();app.onboarding.show();card.set_process(false);card.hide();await capture("guide-final-supply-960")
 check(app.onboarding.step=="supply","final guide requests Lotus supply")
 app.onboarding.hide()
