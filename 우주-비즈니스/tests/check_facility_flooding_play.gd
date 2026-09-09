extends "res://tests/test_solo_entry.gd"
func fill(world: Dictionary,p: Vector3,level: float) -> void:
 var water:=FrontierSurfaceWater.create();water.serial=1
 for x in range(floori(p.x)-8,ceili(p.x)+9):
  for z in range(floori(p.z)-8,ceili(p.z)+9):
   for y in range(floori(p.y),ceili(level)):
    water.cells[FrontierSurfaceWater.key(Vector3i(x,y,z))]=[minf(1,level-y),0.0]
 world.surface_water={world.location:water}
func run() -> void:
 if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder=/tmp/facility-flooding-play-20260909" not in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1280,800)
 app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app;await process_frame;app.start_solo()
 if not await until(func():return app.surface_world!=null,"resume dedicated facility fixture",55):quit(1);return
 app.onboarding.letter.hide();app.close_menus();FrontierClientSettings.ensure(self).values.tutorial_mode=2
 var a:=app.session.authority;var s:=app.surface_world;var actor: String=app.session.latest.self_id
 var p:=Vector3(0,s.terrain.field.height(0,0),0)
 var site:=FrontierExpeditionBusiness.site(a.world);site.state="active";a.world.business.active=a.world.location
 site.buildings["facility:1"]={"id":"facility:1","type":"factory","position":[p.x,p.y,p.z],"yaw":0.0,"tier":2,"enabled":true,"active":true,"working":false,"status":"가동 중","work":0.0,"production":{"product":"refined_iron","progress":0.0}}
 site.buildings["facility:2"]={"id":"facility:2","type":"solar","position":[12,s.terrain.field.height(12,0),0],"yaw":0.0,"enabled":true,"active":true,"status":"발전 중","work":0.0}
 a.world.business.counter=maxi(int(a.world.business.counter),2)
 # Controlled water levels isolate the usability boundary; fluid transport is tested separately.
 a.water_solvers.clear();a.water_timer=1000000
 check(FrontierUniverse.validate_world(a.world).is_empty(),"controlled facility fixture validates: "+FrontierUniverse.validate_world(a.world))
 FrontierExpeditionIndustry.power(a.world,site);app.session._publish_surface()
 if not await until(func():return s.business_view.nodes.has("facility:1"),"existing Blender factory loads",25):printerr("HOST ",a.error," active ",app.session.active);quit(1);return
 var node: Node3D=s.business_view.nodes["facility:1"]
 var top:=p.y+FrontierFacilityFlooding.bounds(site.buildings["facility:1"]).end.y
 fill(a.world,p,top-.1);FrontierExpeditionIndustry.power(a.world,FrontierExpeditionBusiness.site(a.world));app.session._publish_surface()
 check(not FrontierExpeditionBusiness.site(a.world).buildings["facility:1"].submerged,"partially submerged rendered factory remains enabled")
 var base_top:=float(site.center[1])+FrontierFacilityFlooding.bounds({"type":"storage"}).end.y
 fill(a.world,p,maxf(top,base_top)+.25);FrontierExpeditionIndustry.power(a.world,FrontierExpeditionBusiness.site(a.world));app.session._publish_surface()
 if not await until(func():return not node.get_meta("working",true) and s.physical_water.visual.mesh!=null,"full immersion stops work with actual water mesh",15):quit(1);return
 check("침수" in node.get_meta("label").text,"visible facility label identifies submerged lockout")
 app.open_station("base");check(not app.inventory_panel.visible,"submerged default warehouse refuses access")
 var parts: Array=node.get_meta("parts");var transforms: Array=[]
 for part in parts:transforms.append(part.transform)
 await create_timer(.3).timeout
 var stopped:=true
 for i in parts.size():
  if parts[i].transform!=transforms[i]:stopped=false
 check(stopped,"Blender mechanism stops during immersion")
 check(not app.feedback.audio.emitters.has("facility:1"),"immersed facility loses its positional work loop")
 app.open_station("factory","facility:1");check(not app.business_panel.visible,"underwater facility refuses its use panel")
 var camera:=Camera3D.new();app.add_child(camera);camera.position=p+Vector3(4,2,4);camera.look_at(p+Vector3.UP*1.7);camera.make_current();app.feedback.handheld.visible=false
 var light:=OmniLight3D.new();camera.add_child(light);light.omni_range=15;light.light_energy=3
 await create_timer(.4).timeout;await RenderingServer.frame_post_draw
 var out:=ProjectSettings.globalize_path("res://../docs/production/media/facility-flooding");DirAccess.make_dir_recursive_absolute(out)
 root.get_texture().get_image().save_png(out+"/submerged-factory.png")
 a.world.surface_water.clear();FrontierExpeditionIndustry.power(a.world,FrontierExpeditionBusiness.site(a.world));app.session._publish_surface()
 if not await until(func():return node.get_meta("working",false),"drained factory resumes work",10):quit(1);return
 app.open_station("factory","facility:1");check(app.business_panel.visible and app.status.value!=FrontierFacilityFlooding.STATUS,"use panel reopens and clears old flood message after drainage");app.close_menus()
 await create_timer(.3).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/drained-factory.png")
 check(await app.session.close_session(),"facility state checkpoints cleanly")
 FileAccess.open(out+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"One Forward+ host with controlled water levels: existing factory model, mechanism, sound loop, use panel, drainage, checkpoint."},"  "))
 app.queue_free();await process_frame;print("FACILITY_FLOOD_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)
