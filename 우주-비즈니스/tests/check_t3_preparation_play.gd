extends "res://tests/test_solo_entry.gd"
func run() -> void:
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
 if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not has_meta("startup_loader"),"isolated saved T3 site loaded",90):quit(1);return
 app.onboarding.letter.hide();app.close_menus();app.outside=false;app.exterior_view.hide();app.if_flight_view()
 app.toggle_navigation();app.planet_map.modes.current_tab=1;app.planet_map.refresh()
 var panel: FrontierTerraformPanel=app.planet_map.terraform
 panel.layer=4;panel.supply_mode.select(1);panel.refresh()
 var prep: FrontierT3PreparationPanel=panel.preparation
 var before:=FrontierUniverse.fingerprint(app.session.surface)
 prep.starting.select(2);prep.signature="";prep.refresh()
 check(before==FrontierUniverse.fingerprint(app.session.surface),"preparation quote is read-only")
 await create_timer(.5).timeout;await capture("preparation-1280")
 check(prep.is_visible_in_tree() and not panel.supply_rows.visible,"preparation mode opens with material cards")
 root.size=Vector2i(960,640);root.content_scale_size=root.size;await create_timer(.5).timeout;await capture("preparation-960")
 check(prep.target.get_global_rect().end.x<=960 and panel.info.get_global_rect().end.y<=640,"selectors and footer fit 960 window")
 panel.supply_scroll.scroll_vertical=10000;await create_timer(.4).timeout;await capture("preparation-route-960")
 check(panel.supply_scroll.get_v_scroll_bar().value>0,"long recipe route scrolls")
 for i in prep.target.item_count:
  if prep.target.get_item_metadata(i)=="facility_source_control_mk3":prep.target.select(i)
 panel.supply_scroll.scroll_vertical=0;prep.signature="";prep.refresh();await create_timer(.3).timeout
 check(prep.starting.disabled and prep.content.get_child_count()>3,"source control uses new-build quote")
 prep.target.select(0);prep.starting.select(0)
 prep.update_context({},FrontierUniverse.body(app.session.manifest,11),Vector2.ZERO)
 var import_hint:=false
 for text in prep.content.find_children("*","Label",true,false):
  if text.text=="직접 반입 · Lotus 보급":import_hint=true
 check(import_hint,"seeded missing basic mineral is marked for import or Lotus")
 panel.supply_mode.select(0);panel.refresh()
 check(panel.supply_rows.is_visible_in_tree() and not prep.visible,"running supply plan remains reachable")
 await app.session.close_session();app.queue_free();await process_frame
 print("T3_PREPARATION_PLAY ",checks," / ",failures);quit(1 if failures else 0)
