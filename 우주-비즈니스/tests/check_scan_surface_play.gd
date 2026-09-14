extends "res://tests/test_solo_entry.gd"
func run() -> void:
 folder="/tmp/playtest-field-research"
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and not app.arrival.active and not has_meta("startup_loader"),"isolated landed scene",90):quit(1);return
 app.onboarding.letter.hide();app.onboarding.set_process(false);app.onboarding.hide();app.close_menus();app.set_physics_process(false);app.set_process(false)
 root.size=Vector2i(960,640);root.content_scale_size=root.size
 var surface:=app.surface_world
 var body: Dictionary=surface.body
 var actor: String=app.session.latest.self_id
 var position_value: Vector3=app.actors[actor].position
 var veins:=FrontierExpeditionBusiness.veins(body,position_value)
 if not await until(func():return veins.any(func(row):return surface.business_view.nodes.has(row.id)),"ore model streaming completes",30):quit(1);return
 var subject: Node3D=null
 var vein: Dictionary={}
 for row in veins:
  if surface.business_view.nodes.has(row.id):subject=surface.business_view.nodes[row.id];vein=row;break
 check(subject!=null,"visible vein model available")
 if subject==null:quit(1);return
 var point: Vector3=subject.global_position+Vector3.UP
 app.camera.global_position=point+Vector3(0,1,5);app.camera.look_at(point)
 app.feedback.set_process(false)
 app.feedback.optics.survey(point,.55,false,1.25,subject)
 check(not app.feedback.optics.overlays.is_empty() and not app.feedback.optics.scan_shell.visible,"mineral scanner overlays mesh with no fallback sphere")
 await capture("scan-surface-960")
 app.feedback.optics.stop_survey()
 check(subject.find_children("*","MeshInstance3D",true,false).all(func(mesh):return mesh.material_overlay==null),"ending scan restores original material overlays")
 var info: Dictionary={"kind":"mineral","id":vein.id,"point":[point.x,point.y,point.z],"name":"현장 광맥","icon":vein.resource,"subtitle":"지표 분광 분석 · 기록 완료","notes":[{"icon":"inventory","text":"잔량 %d / 총 %d개"%[int(vein.capacity),int(vein.capacity)]}],"condition":"동일 행성의 광물 기록 공유","action":""}
 var card:=FrontierSurveyCard.new();app.add_child(card);card.configure(app);card.set_process(false);card.present(info);card.show();await process_frame
 card.position=Vector2(520,190);card.anchor=Vector2(-40,130);card.queue_redraw();await capture("scan-result-960")
 check(card.get_global_rect().end.x<=960 and card.get_global_rect().end.y<=640,"connected scan result fits 960 window")
 card.queue_free();check(await app.session.close_session(),"close isolated surface scene")
 app.queue_free();await process_frame;print("SCAN_SURFACE ",checks," FAILURES ",failures);quit(1 if failures else 0)
