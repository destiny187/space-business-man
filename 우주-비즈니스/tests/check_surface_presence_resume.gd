extends "res://tests/test_solo_entry.gd"
func run() -> void:
 if "--crew-folder=/tmp/surface-recovery-20260909" not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(960,640)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null and app.surface_world.presence.assets_ready,"saved surface presentation resumes",60):quit(1);return
 var s:=app.surface_world;var p:=s.presence
 check(p.region.state==FrontierSurfaceRecovery.region(s.body,s.business_view.ledger).state,"saved regional values reconstruct the same conditions")
 check(s.environment.ssao_light_affect>.3,"contact shading contributes under direct light")
 p._sample_shelter();check(p.shelter>=0 and p.shelter<=1,"terrain and collider shelter sample valid")
 var ids: Array=[]
 for row in p.patches:ids.append([row.point.x,row.point.z])
 var child_count:=p.get_child_count()
 p.accept(s.business_view.ledger);p.accept(s.business_view.ledger)
 check(p.get_child_count()==child_count,"repeated snapshots keep existing vegetation nodes")
 var bus_name: String=p.sounds.bus_name
 check(await app.session.close_session(),"resumed isolated save closes")
 app.queue_free();await process_frame;await process_frame
 check(AudioServer.get_bus_index(bus_name)<0,"surface audio bus released on exit")
 print("SURFACE_RESUME CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
