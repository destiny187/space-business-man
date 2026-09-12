extends "res://tests/test_solo_entry.gd"
var metrics: Dictionary={}
func ids(grid: Node) -> Array:
 return grid.get_children().map(func(n):return n.get_instance_id())
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not has_meta("startup_loader"),"surface loaded",100):quit(1);return
 app.onboarding.letter.hide();app.close_menus();app.set_physics_process(false)
 app.session.set_process(false);app.session.authority.resolve_autonomous(true);app.session._drain_completed_requests()
 var panel:=app.inventory_panel;panel.set_process(false)
 panel.show();panel._process(.1)
 app.session.latest.inventory.stone=5;panel._process(.01)
 var before_grids: Array=[ids(panel.owned),ids(panel.recipes),ids(panel.cargo),ids(panel.storage_owned)]
 panel.hide()
 var inventory: Dictionary=app.session.latest.inventory
 inventory.stone=int(inventory.get("stone",0))+1
 var began:=Time.get_ticks_usec();panel._process(.01);metrics.hidden_ms=(Time.get_ticks_usec()-began)/1000.0
 metrics.hidden_grids_preserved=before_grids==[ids(panel.owned),ids(panel.recipes),ids(panel.cargo),ids(panel.storage_owned)]
 check(metrics.hidden_grids_preserved,"closed inventory preserves every grid")
 app.session.latest.crew.members[app.session.latest.self_id].loadout.selected=1;panel._process(.01)
 check(panel.hotbuttons[1].selected,"hidden panel still updates active tool hotbar")
 panel.show();panel._process(.01)
 var recipe_ids:=ids(panel.recipes);var cargo_ids:=ids(panel.cargo);var owned_ids:=ids(panel.owned)
 inventory.stone+=1;panel._process(.01)
 metrics.inactive_tabs_preserved=recipe_ids==ids(panel.recipes) and cargo_ids==ids(panel.cargo)
 check(metrics.inactive_tabs_preserved,"inventory change preserves inactive tabs")
 check(owned_ids==ids(panel.owned),"one quantity change retains inventory cards")
 var stone: FrontierItemTile=panel.owned.get_meta("tile_cache")["resource:stone:0"]
 check(stone.amount==str(inventory.stone),"retained inventory card shows new quantity")
 panel.tabs.current_tab=1;panel._process(.01);recipe_ids=ids(panel.recipes)
 inventory.stone+=1;panel._process(.01)
 metrics.recipe_nodes_preserved=recipe_ids==ids(panel.recipes)
 check(metrics.recipe_nodes_preserved,"craft availability updates without replacing recipe cards")
 for tile in panel.recipes.get_children():
  var id: String=tile.get_meta("definition");var def: Dictionary=FrontierEquipment.config().items[id]
  check(tile.unavailable==(int(panel.data.kit)<=0 if id=="miner_1" else not FrontierExpeditionBusiness.affordable(panel.bag,def.cost)),"recipe availability matches current materials: "+id)
 metrics.recipe_count=panel.recipes.get_child_count()
 await capture("crafting")
 panel.tabs.current_tab=2;panel._process(.01)
 var prior_key:=panel.last_key
 app.session.surface.business.sites[app.surface_world.body.id]["audit_unrelated"]={"region":Array(range(10000))}
 panel._process(.01)
 check(panel.last_key==prior_key,"unrelated site data does not enter cargo refresh key")
 var storage_ids:=ids(panel.storage_owned);cargo_ids=ids(panel.cargo)
 inventory.stone+=1;panel._process(.01)
 check(storage_ids==ids(panel.storage_owned) and cargo_ids==ids(panel.cargo),"cargo quantity changes retain both sides of storage")
 var cargo_stone: FrontierItemTile=panel.storage_owned.get_meta("tile_cache")["resource:stone:0"]
 cargo_stone.pressed.emit()
 check(int(panel.storage_selection.amount)==inventory.stone,"retained cargo button uses latest transfer payload")
 inventory.stone=FrontierItemInventory.stack_size("stone")+1;panel._process(.01)
 check(is_same(cargo_stone,panel.storage_owned.get_meta("tile_cache")["resource:stone:0"]) and panel.storage_owned.get_meta("tile_cache").has("resource:stone:1"),"new stack adds only its own card")
 inventory.stone=1;panel._process(.01)
 check(is_same(cargo_stone,panel.storage_owned.get_meta("tile_cache")["resource:stone:0"]) and not panel.storage_owned.get_meta("tile_cache").has("resource:stone:1"),"consumed stack removes only its own card")
 await capture("cargo")
 panel.hide()
 var serial:=app.session.snapshot_serial
 app.session.send_request("business_build",{"building":"invalid","position":[0,0,0]})
 metrics.rejected_snapshot_count=app.session.snapshot_serial-serial
 check(metrics.rejected_snapshot_count==0,"unchanged rejection emits no world snapshot")
 var body:=app.surface_world.body
 var times: Array=[]
 for i in 3:
  began=Time.get_ticks_usec()
  var rows:=FrontierExpeditionBusiness.clearance_veins(body,Vector3(40+i,0,40))
  times.append((Time.get_ticks_usec()-began)/1000.0);metrics.clearance_rows=rows.size()
 metrics.clearance_ms=times
 print("ACTION_SCOPE ",JSON.stringify(metrics))
 var file:=FileAccess.open(folder+"/metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
 check(await app.session.close_session(),"session closes")
 app.queue_free();await process_frame;quit(1 if failures else 0)
