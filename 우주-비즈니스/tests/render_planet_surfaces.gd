extends "res://tests/test_crew_surface.gd"
func run() -> void:
	root.size=Vector2i(1280,800)
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("지표 다양성",0)
	check(core.start(FrontierUniverse.new_world(91723),owner,persist),"host")
	core.world.ecology=FrontierEcology.create()
	core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
	core.world.business=FrontierExpeditionBusiness.create()
	var m: Dictionary=core.world.manifest
	var samples: Dictionary={}
	for i in range(8,200):
		var b:=FrontierUniverse.body(m,i)
		if b.traits.id in ["volcanic","continental"]:samples[b.traits.id]=b
	var session:=FrontierCrewSession.new();session.hosting=true;session.authority=core;session.manifest=m;session.latest={};root.add_child(session);session.set_process(false)
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/planet-diversity")
	for id in ["volcanic","continental"]:
		var b: Dictionary=samples[id]
		core.world.location=b.id;core.world.crew.landing={"body_id":b.id,"epoch":1}
		core.world.crew.members[owner.character_id].position=FrontierCrewSurface.config().ship_position.duplicate()
		FrontierEcology.ensure_planet(core.world.ecology,b)
		core.world.business=FrontierExpeditionBusiness.create()
		check(FrontierExpeditionBusiness.apply(core.world,owner.character_id,"business_register",{},core.peers).is_empty(),"register "+id)
		var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
		var viewer:=Node3D.new();root.add_child(viewer);viewer.position=Vector3(20,8,30)
		var camera:=Camera3D.new();viewer.add_child(camera);camera.current=true;camera.far=10000;camera.look_at_from_position(Vector3(24,13,38),Vector3(15,1,-5))
		var surface:=FrontierCrewSurfaceScene.new();root.add_child(surface);surface.configure(session,packet,viewer,camera)
		for i in 150:
			await process_frame
			if surface.terrain.completed_jobs>60:break
		await create_timer(.4).timeout;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/surface-"+id+".png")
		if id=="volcanic":
			var site:=FrontierExpeditionBusiness.site(core.world);site.environment.temperature=60
			surface.business_view.accept(FrontierExpeditionBusiness.public_view(core.world,owner.character_id))
			await create_timer(.3).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/surface-cooled.png")
		surface.queue_free();viewer.queue_free();await process_frame
	print("SURFACE CHECK ",checks," failures ",failures);quit(0 if failures==0 else 1)
