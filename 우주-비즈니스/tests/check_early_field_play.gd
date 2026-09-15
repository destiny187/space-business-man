extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/early-field-play"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(folder)
 for file in ["world.json","profile.json"]:DirAccess.copy_absolute("/tmp/playtest-field-research/"+file,folder+"/"+file)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"field ready",100):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 var a:=app.session.authority
 var actor: String=app.session.latest.self_id
 var surface:=app.surface_world
 var field:=surface.terrain.field
 var source: Dictionary={}
 for x in range(-3,4):
  for z in range(-3,4):
   for candidate in FrontierExplorationIncidents.tile(surface.body,field,Vector2i(x,z)):
    if not FrontierActiveMissions.enabled(candidate) and not candidate.has("native") and FrontierExplorationIncidents.definition(candidate.template).mode in ["wreck","ice","power"]:source=candidate;break
   if not source.is_empty():break
  if not source.is_empty():break
 check(not source.is_empty(),"cargo available")
 if source.is_empty():quit(1);return
 var row:=FrontierExplorationIncidents.create(source,int(app.session.manifest.seed));row.open=true;row.powered=true
 row.gun_reward_v2=FrontierWeaponLoot.roll("pulse_1","improved",71,"shock");row.gun_reward_v2.definition="pulse_1"
 var id:=FrontierExplorationIncidents.key(row)
 FrontierExplorationIncidents.ensure(a.world);a.world.incidents.records[id]=row
 var target:=Vector3.ZERO
 for part in FrontierExplorationIncidents.targets(row):
  if part.part=="cargo":target=part.point;break
 var at:=target+Vector3(0,0,2)-Vector3.UP*1.72
 a.world.crew.members[actor].position=FrontierExpeditionBusiness.array(at);a.world.crew.members[actor].aboard=false;a.world.crew.members[actor].area="surface"
 app.actors[actor].position=at
 app.camera.set_as_top_level(true);app.camera.position=at+Vector3.UP*1.72;app.camera.look_at(target)
 app.session._publish();await process_frame
 var args: Dictionary={"id":id,"part":"cargo","aim":FrontierExpeditionBusiness.array((target-app.camera.position).normalized())}
 surface.incidents.open_loot(args);await create_timer(.5).timeout
 var modal: FrontierGameModal
 for child in app.get_children():
  if child is FrontierGameModal and child.visible:modal=child
 check(modal!=null,"cargo inventory opens")
 if modal==null:quit(1);return
 await capture("cargo-before")
 var gun: FrontierItemTile
 for tile in modal.find_children("*","Button",true,false):
  if tile is FrontierItemTile and tile.cargo_payload.get("loot_key")=="gun":gun=tile
 check(gun!=null,"specific gun shown")
 var count: int=a.world.crew.members[actor].loadout.items.size()
 if gun!=null:gun.pressed.emit()
 await until(func():return a.world.crew.members[actor].loadout.items.size()>count,"only selected gun acquired",20)
 check(not a.world.incidents.records[id].claimed,"other cargo remains")
 await create_timer(.3).timeout;await capture("cargo-after");modal.cancel();await process_frame
 a.world.business.bags[actor].iron=50;app.session._publish()
 app.close_menus();app.open_menu(app.inventory_panel);await create_timer(.3).timeout
 var resource_tile: FrontierItemTile
 for tile in app.inventory_panel.owned.get_children():
  if tile is FrontierItemTile and not str(tile.get_meta("resource","")).is_empty():resource_tile=tile;break
 if resource_tile!=null:
  app.inventory_panel._drop_dialog(resource_tile);await create_timer(.3).timeout;await capture("drop-quantity")
  for child in app.inventory_panel.get_children():
   if child is FrontierGameModal:
    var quantity: SpinBox=child.find_children("*","SpinBox",true,false)[0]
    for button in child.find_children("*","Button",true,false):
     if button.text=="+10":button.pressed.emit();check(quantity.value==11,"drop +10 changes quantity")
    for button in child.find_children("*","Button",true,false):
     if button.text=="최대":button.pressed.emit();check(quantity.value==quantity.max_value,"drop maximum changes quantity")
    child.cancel()
 app.close_menus()
 check(not app.business_panel.vessel_terminal.cards.has("augmentation"),"ship terminal has no augmentation card")
 if "--ui-only" in OS.get_cmdline_user_args():
  print("EARLY_FIELD_UI ",checks," failures ",failures);await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0);return
 # Local visual excavation with unchanged observer: check mesh/collision swap and far reuse.
 at=Vector3(0,field.height(0,0)+.1,0)
 app.actors[actor].position=at;a.world.crew.members[actor].position=FrontierExpeditionBusiness.array(at)
 app.camera.position=at+Vector3(0,1.7,0);app.camera.look_at(at+Vector3(12,-5,0))
 app.session._publish();await create_timer(2).timeout
 await until(func():return surface.terrain.ready_for([at]) and surface.distant.task_id==-1,"terrain settled",60)
 var builds: int=surface.distant.build_count
 var point:=at+Vector3(8,-4,0)
 var unaffected: Dictionary=surface.terrain.chunks.duplicate()
 var result:=surface.terrain.dig(point,3.2)
 check(not result.is_empty(),"one excavation accepted")
 await until(func():return surface.terrain.batch.is_empty(),"mesh and collision commit",30)
 check(surface.distant.build_count==builds,"dig does not rebuild distant mountains")
 var retained:=0
 for key in unaffected:
  if surface.terrain.chunks.has(key) and is_same(unaffected[key].node,surface.terrain.chunks[key].node):retained+=1
 check(retained>0,"unaffected fine chunks retained")
 app.camera.position=point;app.camera.look_at(point+Vector3(8,1,0))
 await create_timer(.5).timeout;await capture("underground")
 print("EARLY_FIELD_PLAY ",checks," failures ",failures," far builds ",builds," retained ",retained)
 await app.session.close_session();app.queue_free();await process_frame;quit(1 if failures else 0)
