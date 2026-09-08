extends "res://tests/test_crew_surface.gd"
## Bounded production check: new geometry, persisted legacy rules, actual 9 surfaces.
func run() -> void:
	root.size=Vector2i(1280,800)
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/planet-coverage/ground")
	DirAccess.make_dir_recursive_absolute(folder)
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("자연물 제작 확인",0)
	check(core.start(FrontierUniverse.new_world(91723),owner,persist),"host starts")
	core.world.ecology=FrontierEcology.create()
	core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
	core.world.business=FrontierExpeditionBusiness.create()
	var m: Dictionary=core.world.manifest
	var samples: Dictionary={}
	for i in range(8,500):
		var b:=FrontierUniverse.body(m,i)
		if FrontierUniverse.landable(b) and not samples.has(b.traits.id):samples[b.traits.id]=b
	var results: Dictionary={"surfaces":{},"checks":0,"failures":0}
	var session:=FrontierCrewSession.new();session.hosting=true;session.authority=core;session.manifest=m;session.latest=core.world;root.add_child(session);session.set_process(false)
	var ids: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_details.json")).families.keys();ids.sort()
	for id in ids:
		var b: Dictionary=samples[id]
		core.world.location=b.id;core.world.crew.landing={"body_id":b.id,"epoch":1}
		core.world.crew.members[owner.character_id].position=FrontierCrewSurface.config().ship_position.duplicate()
		FrontierEcology.ensure_planet(core.world.ecology,b)
		core.world.business=FrontierExpeditionBusiness.create()
		check(FrontierExpeditionBusiness.apply(core.world,owner.character_id,"business_register",{},core.peers).is_empty(),id+" register")
		var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
		var viewer:=Node3D.new();root.add_child(viewer);viewer.position=Vector3(-23,4,23)
		var camera:=Camera3D.new();viewer.add_child(camera);camera.current=true;camera.far=2000
		camera.look_at_from_position(Vector3(-25,4.2,29),Vector3(-29,2,8))
		var surface:=FrontierCrewSurfaceScene.new();root.add_child(surface);surface.configure(session,packet,viewer,camera)
		FrontierInkStyle.attach(surface)
		var deadline:=Time.get_ticks_msec()+25000
		while Time.get_ticks_msec()<deadline:
			await process_frame
			if surface.terrain.completed_jobs>=60 and surface.surface_details.tiles.size()>=12:break
		await create_timer(.25).timeout
		check(surface.terrain.completed_jobs>0,id+" terrain rendered")
		results.surfaces[id]={"seed":b.seed,"ordinal":b.ordinal,"temperature":b.traits.temperature,"water":b.traits.water,"terrain_jobs":surface.terrain.completed_jobs,"decoration_instances":surface.surface_details.instance_total,"biome_style":surface.terrain.material.get_shader_parameter("biome_style")}
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/"+id+".png")
		surface.queue_free();viewer.queue_free();await process_frame
	results.checks=checks;results.failures=failures
	var file:=FileAccess.open(folder+"/verification.json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("SURFACE_COVERAGE ",JSON.stringify(results));quit(0 if failures==0 else 1)
