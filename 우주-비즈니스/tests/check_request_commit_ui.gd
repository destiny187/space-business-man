extends "res://tests/test_solo_entry.gd"
var replies: Array=[]
func run() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
 await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not has_meta("startup_loader"),"surface loaded",100):quit(1);return
 app.onboarding.letter.hide();app.close_menus()
 app.set_physics_process(false);app.session.set_physics_process(false)
 var a:=app.session.authority;a.resolve_autonomous(true);app.session._drain_completed_requests()
 app.session.response_received.connect(func(seq: int,result: Dictionary):replies.append({"sequence":seq,"result":result}))
 var actor: String=app.session.latest.self_id
 var old_slot:=int(a.world.crew.members[actor].loadout.selected);var slot:=(old_slot+1)%4
 var poll:=a.poll_autonomous;a.poll_autonomous=func():return 0
 var writes: Array=[0];var persist:=a.save_world
 a.save_world=func(value):writes[0]+=1;return persist.call(value)
 var start:=Time.get_ticks_usec();app.inventory_panel.hotbuttons[slot].pressed.emit()
 var submit_ms:=(Time.get_ticks_usec()-start)/1000.0
 check(a.autonomous_pending() and replies.is_empty(),"hotbar click submits without premature success")
 check(int(app.session.latest.crew.members[actor].loadout.selected)==old_slot,"UI retains confirmed slot while save is pending")
 var frames:=0
 for i in 4:await process_frame;frames+=1
 check(frames==4 and a.autonomous_pending() and replies.is_empty(),"render and UI frames continue during delayed disk completion")
 a.poll_autonomous=poll
 if not await until(func():return not replies.is_empty(),"session delivers completed transaction",5):quit(1);return
 await process_frame
 check(replies.size()==1 and replies[0].result.ok and app.inventory_panel.hotbuttons[slot].selected,"one durable reply updates selected hotbar slot")
 check(writes[0]==0,"ordinary hotbar input calls no synchronous save")
 var saved:=app.session.store.read_state()
 check(int(saved.crew.members[actor].loadout.selected)==slot,"visible selection is already durable")
 # Paid crafting checks cost/ownership atomicity through the same real session.
 var stock:=FrontierExpeditionBusiness.bag(a.world,actor);stock.iron=10;stock.copper=10
 var item_count: int=a.world.crew.members[actor].loadout.items.size()
 a.poll_autonomous=func():return 0
 app.session.send_request("equipment_craft",{"definition":"pulse_1"})
 var replay: Dictionary=a.pending_request.envelope.duplicate(true)
 check(a.autonomous_pending() and stock.iron==10 and stock.copper==10,"pending crafting spends no live materials")
 a.poll_autonomous=poll
 if not await until(func():return replies.size()==2,"paid crafting completes",5):quit(1);return
 var confirmed:=FrontierExpeditionBusiness.bag(a.world,actor)
 check(replies.back().result.ok and confirmed.iron==4 and confirmed.copper==6 and a.world.crew.members[actor].loadout.items.size()==item_count+1,"crafting confirms exactly one item and one cost")
 var committed: Dictionary=a.world.duplicate(true)
 check(a.request(1,replay).get("ok",false) and a.world==committed and not a.autonomous_pending(),"crafting replay duplicates neither payment nor item")
 saved=app.session.store.read_state()
 check(saved.business.bags[actor].iron==4 and saved.crew.members[actor].loadout.items.size()==item_count+1,"crafted item and payment are durable together")
 app.session.send_request("ready",{"value":false})
 check(a.autonomous_pending(),"ordinary full-draft command also uses async commit")
 if not await until(func():return replies.size()==3,"full-draft command completes",5):quit(1);return
 check(replies.back().result.ok and writes[0]==0,"all three ordinary commands avoid synchronous saves")
 await capture("selected-tool")
 var metrics: Dictionary={"submit_ms":submit_ms,"pending_render_frames":frames,"synchronous_writes":writes[0],"failures":failures}
 print("REQUEST_COMMIT_UI ",JSON.stringify(metrics))
 var file:=FileAccess.open(folder+"/metrics.json",FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
 a.save_world=persist
 check(await app.session.close_session(),"session closes with ordered final save")
 app.queue_free();await process_frame;quit(1 if failures else 0)
