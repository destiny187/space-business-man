extends "res://tests/test_crew_surface.gd"
## Bounded production check: new geometry, persisted legacy rules, actual 9 surfaces.
func run() -> void:
	root.size=Vector2i(1280,800)
	var folder:=ProjectSettings.globalize_path("res://../docs/production/media/surface-details")
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
	var session:=FrontierCrewSession.new();session.hosting=true;session.authority=core;session.manifest=m;session.latest={};root.add_child(session);session.set_process(false)
	var ids: Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_details.json")).families.keys();ids.sort()
	var only_oxidized: bool="--only-oxidized" in OS.get_cmdline_user_args()
	if only_oxidized:ids=["oxidized"]
	for id in ids:
		var b: Dictionary=samples[id]
		var field:=FrontierTerrainField.new();field.configure(int(b.streams.terrain),[],24,b.terrain_traits)
		var old_traits: Dictionary=b.terrain_traits.duplicate(true);old_traits.erase("terrain_layout")
		var old:=FrontierTerrainField.new();old.configure(int(b.streams.terrain),[],24,old_traits)
		var restored:=FrontierTerrainField.new();restored.configure(int(b.streams.terrain),[],24,JSON.parse_string(JSON.stringify(old_traits)))
		var flat:=0;var before:=0;var land:=0;var old_land:=0
		for x in range(-960,961,16):
			for z in range(-960,961,16):
				if Vector2(x,z).length()<240:continue
				var wet: bool=float(b.traits.water)>15 and float(b.traits.temperature)>0
				if not wet or field.height(x,z)>-4:
					land+=1
					if slope(field,x,z)<tan(deg_to_rad(5)):flat+=1
				if not wet or old.height(x,z)>-4:
					old_land+=1
					if slope(old,x,z)<tan(deg_to_rad(5)):before+=1
		check(is_equal_approx(old.height(317,283),restored.height(317,283)),id+" legacy serialized terrain")
		check(field.height(0,0)==2 and field.height(-30,-20)==2,id+" connected landing plain")
		check(float(flat)/land>float(before)/old_land,id+" more flat land")
		results.surfaces[id]={"flat_percent":snappedf(100.0*flat/land,.1),"previous_percent":snappedf(100.0*before/old_land,.1),"seed":b.seed}
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
		var details:=surface.surface_details
		check(details.instance_total>30,id+" actual streamed details")
		check(details.meshes.size()==4,id+" four Blender variants")
		results.surfaces[id].instances=details.instance_total
		results.surfaces[id].tiles=details.tiles.size()
		if id=="oxidized":
			var key:=Vector2i(-1,1);var rows:=details.candidates(key)
			check(str(rows)==str(details.candidates(key)),"tile regeneration stable")
			if not rows.is_empty():
				var p: Vector3=rows[0].transform.origin
				var mock: Dictionary=packet.business.duplicate(true)
				mock.sites[b.id].buildings["visual-check"]={"id":"visual-check","type":"solar","position":[p.x,p.y,p.z]}
				details.accept(mock)
				check(not has_id(details.candidates(key),rows[0].id),"confirmed building clears decorative footprint")
				details.accept(packet.business)
				check(has_id(details.candidates(key),rows[0].id),"removing building restores stable decoration")
				surface.terrain.dig(p,2.6)
				check(not has_id(details.candidates(key),rows[0].id),"excavation removes unsupported decoration")
				for i in 120:
					await process_frame
					if surface.terrain.batch.is_empty():break
			var at:=Vector3(-23,0,23);at.y=surface.terrain.field.height(at.x,at.z)
			check(FrontierExpeditionBusiness.ground(surface.terrain.field,at.x,at.z,2).is_finite(),"facility footprint fits landing plain")
			# Excavation invalidates cosmetic tiles; capture after their real rebuild.
			var settle_deadline:=Time.get_ticks_msec()+15000
			while Time.get_ticks_msec()<settle_deadline:
				await process_frame
				if not details.dirty and details.tiles.size()>=12:break
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder+"/surface-"+id+".png")
		if only_oxidized:
			camera.look_at_from_position(Vector3(-32,19,42),Vector3(-6,2,-9))
			await create_timer(.3).timeout;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/desert-geology/overview.png"))
		surface.queue_free();viewer.queue_free();await process_frame
	results.checks=checks;results.failures=failures
	var report_name: String="verification-oxidized.json" if only_oxidized else "verification.json"
	var file:=FileAccess.open(folder+"/"+report_name,FileAccess.WRITE);file.store_string(JSON.stringify(results,"\t"));file.close()
	print("SURFACE_DETAILS ",JSON.stringify(results));quit(0 if failures==0 else 1)
func slope(field: FrontierTerrainField,x: float,z: float) -> float:
	return Vector2(field.height(x+1,z)-field.height(x-1,z),field.height(x,z+1)-field.height(x,z-1)).length()/2
func has_id(rows: Array[Dictionary],id: String) -> bool:
	for row in rows:
		if row.id==id:return true
	return false
