extends "res://tests/test_crew_surface.gd"
## Nine material changes, using the production streamed surface and sky.
func run() -> void:
	root.size=Vector2i(1280,800)
	var folder:="res://../docs/production/media/ink-life/surfaces"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("지표 표현 확인",0)
	check(core.start(FrontierUniverse.new_world(91723),owner,persist),"host starts")
	core.world.ecology=FrontierEcology.create()
	core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
	core.world.business=FrontierExpeditionBusiness.create()
	var m:Dictionary=core.world.manifest;var samples:Dictionary={}
	for i in range(8,500):
		var b:=FrontierUniverse.body(m,i)
		if FrontierUniverse.landable(b) and not samples.has(b.traits.id):samples[b.traits.id]=b
	var session:=FrontierCrewSession.new();session.hosting=true;session.active=true;session.authority=core;session.manifest=m
	session.latest={"crew":core.world.crew,"self_id":owner.character_id};root.add_child(session);session.set_process(false)
	var records:Dictionary={}
	for id in ["oxidized","continental","cratered","fractured","tundra","frozen","volcanic","salt","ochre"]:
		var b:Dictionary=samples[id]
		core.world.location=b.id;core.world.crew.landing={"body_id":b.id,"epoch":1}
		core.world.crew.members[owner.character_id].position=FrontierCrewSurface.config().ship_position.duplicate()
		FrontierEcology.ensure_planet(core.world.ecology,b);FrontierPlanetaryCycles.ensure_region(core.world,b)
		core.world.business=FrontierExpeditionBusiness.create()
		check(FrontierExpeditionBusiness.apply(core.world,owner.character_id,"business_register",{},core.peers).is_empty(),id+" site")
		var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
		var viewer:=Node3D.new();root.add_child(viewer);viewer.position=Vector3(-23,4,23)
		var camera:=Camera3D.new();viewer.add_child(camera);camera.current=true;camera.far=2000
		camera.look_at_from_position(Vector3(-25,4.2,29),Vector3(-29,2,8))
		var surface:=FrontierCrewSurfaceScene.new();root.add_child(surface);surface.configure(session,packet,viewer,camera)
		FrontierInkStyle.attach(surface)
		var deadline:=Time.get_ticks_msec()+20000
		while Time.get_ticks_msec()<deadline:
			await process_frame
			if surface.terrain.completed_jobs>=40 and surface.surface_details.tiles.size()>=6:break
		await create_timer(.25).timeout;await RenderingServer.frame_post_draw
		check(surface.terrain.completed_jobs>0,id+" production terrain")
		check(surface.surface_details.instance_total>0,id+" natural details")
		check(is_equal_approx(surface.terrain.field.height(0,0),2),id+" landing floor preserved")
		root.get_texture().get_image().save_png(folder+"/"+id+".png")
		records[id]={"seed":b.seed,"terrain_jobs":surface.terrain.completed_jobs,"detail_instances":surface.surface_details.instance_total}
		surface.queue_free();viewer.queue_free();await process_frame
	FileAccess.open(folder+"/verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"surfaces":records,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("INK_SURFACES_COMPLETE checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
