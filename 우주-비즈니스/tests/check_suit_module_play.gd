extends "res://tests/check_incident_play.gd"
func run() -> void:
 folder="/tmp/suit-module-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/suit-module-play" not in OS.get_cmdline_user_args():quit(1);return
 if "--ui-only" in OS.get_cmdline_user_args():await review_ui();return
 DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var owner:=FrontierPlayerProfile.new_character("모듈 현장 확인",0);incident_actor=owner.character_id
 var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,func(_w):return true),"start")
 core.world.crew.phase="playing"
 var world: Dictionary=core.world;var planet: Dictionary={};var destination:=0
 for i in range(8,1000000,997):
  var body:=FrontierUniverse.body(world.manifest,i)
  if FrontierUniverse.landable(body) and int(body.planet_tier)==3:planet=body;destination=i;break
 check(not planet.is_empty(),"natural T3 planet")
 if planet.is_empty():quit(1);return
 world.location=planet.id;world.navigation_target=planet.id;world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=destination
 world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
 world.crew.members[incident_actor].ready=true
 check(FrontierCrewSurface.apply(world,incident_actor,"land",{},{1:incident_actor}).is_empty(),"T3 land fixture")
 var m: Dictionary=world.crew.members[incident_actor]
 m.loadout.items["fixture:pulse"]="pulse_2";m.loadout.slots[2]="fixture:pulse"
 FrontierSuitModules.ensure(m)
 var supplied: Dictionary={}
 for seed_value in 200:
  var item:=FrontierSuitModules.roll(seed_value,3 if seed_value%3==0 else 2,"discovery")
  if not supplied.has(item.slot):
   m.modules.items["module:preview:"+str(seed_value)]=item;supplied[item.slot]=true
  if supplied.size()==6:break
 m.modules.items["module:starter"]={"slot":"defense","tier":1,"rarity":"common","affixes":{},"seed":0,"source":"starter"};m.modules.equipped.defense="module:starter";m.modules.starter=true
 var legendary_review:= "--legendary-review" in OS.get_cmdline_user_args()
 if legendary_review:
  for seed_value in 18000:
   var sample:=FrontierSuitModules.roll(seed_value,3,"discovery")
   if sample.get("legendary","")=="shield_breaker":
    m.modules.items["module:breaker"]=sample;m.modules.equipped[sample.slot]="module:breaker";break
 var row: Dictionary={};var f:=FrontierExplorationIncidents.field(planet)
 for x in range(-2,3):
  for z in range(-2,3):
   for candidate in FrontierExplorationIncidents.tile(planet,f,Vector2i(x,z)):
    if candidate.template=="illuti_dormant_combat_robot":
     row=candidate;break
   if not row.is_empty():break
  if not row.is_empty():break
 check(not row.is_empty(),"naturally seeded T3 robot")
 if row.is_empty():quit(1);return
 var id:=FrontierExplorationIncidents.key(row);world.incidents.records[id]=FrontierExplorationIncidents.create(row)
 if legendary_review:
  var near:=FrontierExplorationIncidents.point(row,Vector3(0,0,10));near.y=f.height(near.x,near.z)+1.2
  m.position=FrontierExplorationIncidents.array(near)
 var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(world),"save fixture "+store.last_error)
 var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"Forward+ landed",90):quit(1);return
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 app.session.authority.world.business.bags[incident_actor]=FrontierExpeditionBusiness.inventory()
 if not await visit(row,FrontierExplorationIncidents.point(row,Vector3(0,0,10)),FrontierExplorationIncidents.point(row,Vector3(0,1.5,0))):quit(1);return
 m=app.session.authority.world.crew.members[incident_actor];m.vitals.shield=30
 var health_before:=float(m.vitals.health)
 await until(func():return int(app.session.latest.crew.members[incident_actor].vitals.get("shield_serial",0))>0,"robot hits real shield",20)
 check(float(app.session.latest.crew.members[incident_actor].vitals.health)==health_before,"shield protects body health")
 await capture("shield-hit")
 if legendary_review:check(float(app.session.authority.world.incidents.records[id].get("shield",0))==60,"natural T3 robot shield")
 for i in 5:
  if app.session.authority.world.incidents.records[id].hp<=0:break
  await action(row,"robot",true,2)
  if i==0 and legendary_review:check(float(app.session.authority.world.incidents.records[id].shield)==0,"shield breaker consumes robot shield")
 await action(row,"cargo",false,2)
 if "--robot-art-review" in OS.get_cmdline_user_args():
  await capture("robot-destroyed")
  check(await app.session.close_session(),"robot appearance gameplay save")
  app.queue_free();await process_frame;await process_frame
  print("ROBOT_ART_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0);return
 var reward_id: String="module:"+id.sha256_text().substr(0,24)
 check(app.session.latest.crew.members[incident_actor].modules.items.has(reward_id),"real F cargo grants module")
 check(int(app.session.latest.crew.members[incident_actor].modules.items.get(reward_id,{}).get("tier",0))==3,"T3 reward tier")
 if legendary_review:
  reward_id="module:breaker"
  var live_rack: Dictionary=app.session.latest.crew.members[incident_actor].modules
  app.session.send_request("suit_module",{"action":"unequip","id":reward_id,"revision":int(live_rack.revision)})
  check(live_rack.items[reward_id].rarity=="legendary","seeded legendary comparison fixture")
 app.open_menu(app.inventory_panel)
 var panel: FrontierSuitModulePanel
 for child in app.inventory_panel.tabs.get_children():
  if child is FrontierSuitModulePanel:panel=child;app.inventory_panel.tabs.current_tab=child.get_index();break
 panel.selected=reward_id;panel.signature="";await capture("modules-1280")
 panel.equip.pressed.emit();await create_timer(.5).timeout
 var item: Dictionary=app.session.latest.crew.members[incident_actor].modules.items[reward_id]
 check(app.session.latest.crew.members[incident_actor].modules.equipped.get(item.slot)==reward_id,"UI equip host result")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("modules-960")
 app.close_menus();await create_timer(7).timeout;await capture("shield-hud-960")
 check(await app.session.close_session(),"module gameplay save")
 app.queue_free();await process_frame;await process_frame
 print("MODULE_PLAY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

func review_ui() -> void:
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"saved module world resumes",90):quit(1);return
 incident_actor=app.session.latest.self_id
 app.close_menus();app.onboarding.letter.hide();FrontierClientSettings.ensure(self).values.tutorial_mode=2;app.outside=false;app.exterior_view.hide();app.if_flight_view()
 app.open_menu(app.inventory_panel)
 var panel: FrontierSuitModulePanel
 for child in app.inventory_panel.tabs.get_children():
  if child is FrontierSuitModulePanel:panel=child;app.inventory_panel.tabs.current_tab=child.get_index();break
 var rack: Dictionary=app.session.latest.crew.members[incident_actor].modules
 for id in rack.items:
  if rack.items[id].slot=="work" and int(rack.items[id].tier)==3:panel.selected=id;panel.signature="";break
 await capture("modules-1280")
 panel.remove.pressed.emit();await create_timer(.3).timeout;panel.equip.pressed.emit();await create_timer(.5).timeout
 check(panel.status.text=="장비 적용 완료","committed UI feedback")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("modules-960")
 app.close_menus();await create_timer(2).timeout;await capture("shield-hud-960")
 check(FrontierSuitModules.shield_max(app.session.latest.crew.members[incident_actor])>0,"saved shield equipment")
 check(await app.session.close_session(),"review save")
 app.queue_free();await process_frame;await process_frame
 print("MODULE_UI_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
