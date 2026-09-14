extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/playtest-field-research"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"landed scene ready",90):quit(1);return
 app.onboarding.welcome_pending=false;app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var actor: String=app.session.latest.self_id
 app.session.authority.world.business.bags[actor].iron=10
 await until(func():return int(app.session.latest.get("inventory",{}).get("iron",0))==10,"isolated drop stock visible",15)
 var panel:=app.inventory_panel
 app.open_menu(panel);panel.tabs.current_tab=0;panel.last_key="";panel._process(.1)
 await process_frame
 var tile: FrontierItemTile=null
 for candidate in panel.owned.get_children():
  if candidate.get_meta("resource","")=="iron":tile=candidate;break
 check(tile!=null,"owned iron card available")
 if tile==null:quit(1);return
 var before: int=app.session.authority.world.business.bags[actor].iron
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true
 tile.gui_input.emit(event);await process_frame
 var modal: FrontierGameModal=null
 for child in panel.get_children():
  if child is FrontierGameModal:modal=child
 check(modal!=null and modal.visible,"right click opens quantity modal")
 if modal==null:quit(1);return
 var spin: SpinBox=modal.find_children("*","SpinBox",true,false)[0];spin.value=3
 await capture("drop-quantity")
 check(spin.get_global_rect().end.y<=modal.scroll.get_global_rect().end.y,"quantity is visible without scrolling")
 modal.accept()
 if not await until(func():return int(app.session.authority.world.business.bags[actor].iron)==before-3,"host commits selected drop count",20):quit(1);return
 var id: String=app.session.authority.world.business.crates.keys().back()
 app.close_menus()
 await until(func():return app.surface_world.business_view.nodes.has(id),"physical dropped crate appears",20)
 var node: Node3D=app.surface_world.business_view.nodes[id]
 app.camera.set_as_top_level(true);app.camera.global_position=node.global_position+Vector3(2,2,3);app.camera.look_at(node.global_position+Vector3.UP*.5)
 await capture("dropped-crate")
 app.session.send_request("equipment_pickup",{"crate_id":id})
 await until(func():return not app.session.authority.world.business.crates.has(id),"F pickup command removes crate",20)
 check(int(app.session.authority.world.business.bags[actor].iron)==before,"pickup restores exact resource count")
 var guide:=app.onboarding
 var previous: Dictionary=guide.progress.duplicate(true)
 guide.progress={"eligible":true,"guide_version":2,"inventory":true,"field_scan":true,"travel":true};guide.show();guide.card.show()
 guide.pending_actions[999001]="business_mine";guide._response(999001,{"ok":false,"gains":{"iron":1}})
 check(not guide.progress.get("mined",false),"failed action does not advance guide")
 guide.pending_actions[999002]="business_mine";guide._response(999002,{"ok":true,"gains":{"iron":1}});guide.progress.materials_review=true;guide.field_instruction()
 check(guide.step=="build" and guide.detail.text.contains("필요 재료"),"successful mining leads to first construction cost")
 await capture("guide-first-building")
 guide.pending_actions[999003]="business_build";guide._response(999003,{"ok":true});guide.field_instruction()
 check(guide.step=="terraform","successful construction leads to environmental map")
 guide.progress.terraform_view=true;guide.field_instruction();await create_timer(1).timeout;await capture("guide-restoration")
 check(guide.step=="restore" and guide.counter.text.contains("12"),"contextual restoration instruction available")
 guide.progress=previous;guide._save();guide.hide()
 check(await app.session.close_session(),"save and close isolated scene")
 app.queue_free();await process_frame;print("DROP_GUIDE ",checks," FAILURES ",failures);quit(1 if failures else 0)
