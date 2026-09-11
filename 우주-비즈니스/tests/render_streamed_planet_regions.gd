extends "res://tests/test_crew_surface.gd"
## Focused visual check on the real streamed surface, with fixed comparison lighting.
var folder: String="res://../output/planet-variety-20260911/g03-play"
func capture(id: String) -> void:
	await create_timer(.25).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+id+".png")
func sample_frames(material: ShaderMaterial,enabled: bool) -> Dictionary:
	material.set_shader_parameter("regional_enabled",enabled)
	for i in 20:await process_frame
	var values: Array[float]=[];var last:=Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now:=Time.get_ticks_usec();values.append((now-last)/1000.0);last=now
	values.sort()
	return {"regions":enabled,"frames":values.size(),"median_ms":values[values.size()/2],"p95_ms":values[floori(values.size()*.95)],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"gpu_ms":null}
func run() -> void:
	root.size=Vector2i(1280,800);root.content_scale_size=root.size;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var preferences:=FrontierClientSettings.ensure(self);preferences.values=FrontierClientSettings.DEFAULTS.duplicate()
	for group in preferences.graphics_groups():preferences._merge_quality(group,2 if group=="anti_aliasing" else 1)
	preferences.values.fps=0;preferences.values.vsync=false;preferences.apply_all()
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("지표 재질 검수",0)
	check(core.start(FrontierUniverse.new_world(91723),owner,persist),"host starts")
	core.world.ecology=FrontierEcology.create();core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings);core.world.business=FrontierExpeditionBusiness.create()
	var m: Dictionary=core.world.manifest;var samples: Dictionary={}
	for i in range(8,900):
		var b:=FrontierUniverse.body(m,i)
		if FrontierUniverse.landable(b) and not samples.has(b.traits.id):samples[b.traits.id]=b
	check(samples.size()==12,"twelve landable families generated")
	var session:=FrontierCrewSession.new();session.hosting=true;session.active=true;session.authority=core;session.manifest=m;session.latest={"crew":core.world.crew,"self_id":owner.character_id};root.add_child(session);session.set_process(false)
	var rows: Dictionary={}
	var ids: Array=["oxidized","volcanic"]
	var requested:=OS.get_cmdline_user_args()
	for arg in requested:
		if arg.begins_with("--families="):ids=arg.trim_prefix("--families=").split(",")
	for id in ids:
		var b: Dictionary=samples[id];core.world.location=b.id;core.world.crew.landing={"body_id":b.id,"epoch":1};core.world.crew.members[owner.character_id].position=FrontierCrewSurface.config().ship_position.duplicate()
		FrontierEcology.ensure_planet(core.world.ecology,b);FrontierPlanetaryCycles.ensure_region(core.world,b)
		core.world.business=FrontierExpeditionBusiness.create();FrontierExpeditionBusiness.ensure_site(core.world)
		var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
		var viewer:=Node3D.new();root.add_child(viewer);viewer.position=Vector3(650,4,650)
		var camera:=Camera3D.new();viewer.add_child(camera);camera.current=true;camera.far=2000;camera.look_at_from_position(Vector3(-25,4.2,29),Vector3(-29,2,8))
		var surface:=FrontierCrewSurfaceScene.new();root.add_child(surface);surface.configure(session,packet,viewer,camera);FrontierInkStyle.attach(surface)
		var field:=surface.terrain.field;var rules:=preload("res://scripts/world/surface_regions.gd").definition(b.traits);var phase:=FrontierSurfaceGeology.phase(b.traits)
		var best:=INF
		for z in range(220,1200,30):
			for x in range(220,1200,30):
				var p:=Vector3(x,field.height(x,z),z);var zone:=preload("res://scripts/world/surface_regions.gd").weights(p,rules,phase)
				if id=="volcanic" and zone.z<.3:continue
				var slope:=absf(field.height(x+2,z)-field.height(x-2,z))+absf(field.height(x,z+2)-field.height(x,z-2))
				var score:=absf(zone.y-.5)*10+slope
				if score<best:best=score;viewer.position=p+Vector3.UP*2
		camera.look_at_from_position(viewer.position+Vector3(0,4,10),viewer.position+Vector3(0,-1,-10))
		root.size=Vector2i(1280,800);root.content_scale_size=root.size

		core.world.crew.members[owner.character_id].position=[viewer.position.x,viewer.position.y,viewer.position.z]
		surface._update_interest()
		var deadline:=Time.get_ticks_msec()+90000
		while Time.get_ticks_msec()<deadline:
			await process_frame
			if surface.terrain.ready_for([viewer.position]) and surface.surface_details.presentation_ready() and surface.distant.build_count>0 and surface.distant.task_id==-1 and surface.distant.fallback_task==-1:break
		check(surface.terrain.ready_for([viewer.position]) and surface.distant.build_count>0 and surface.distant.task_id==-1,id+" near and distant ready")
		surface.set_process(false);surface.lamp.light_energy=0;surface.atmosphere.sun.rotation_degrees=Vector3(-42,-32,0);surface.atmosphere.sun.light_energy=1.5;surface.atmosphere.sun.light_color=Color("ffedda")
		surface.environment.fog_enabled=false;surface.environment.background_mode=Environment.BG_COLOR;surface.environment.background_color=Color("819194");surface.environment.ambient_light_energy=.55;surface.environment.ambient_light_color=Color("aebcc4")
		var mat: ShaderMaterial=surface.terrain.material
		var fallback:=surface.distant.get_node_or_null("StreamingFallback") as MeshInstance3D
		check(fallback==null or fallback.material_override==mat,id+" fallback shares surface material")
		check(mat.get_shader_parameter("surface_textures") is Texture2DArray,id+" packed material bound")
		check(surface.terrain.completed_jobs>0 and surface.surface_details.instance_total>0,id+" terrain and Blender scatter")
		check(is_equal_approx(surface.terrain.field.height(0,0),2),id+" landing collision height")
		check(mat.get_shader_parameter("regional_enabled")==true,id+" regional shader enabled")
		await capture("ground-"+id)
		surface.process_mode=Node.PROCESS_MODE_DISABLED
		var timings: Array=[]
		for enabled in [false,true,true,false]:timings.append(await sample_frames(mat,enabled))
		mat.set_shader_parameter("regional_enabled",true)
		rows[id]={"seed":b.seed,"profile":b.traits.id,"geology":b.mineral_profile.id,"terrain_jobs":surface.terrain.completed_jobs,"scatter":surface.surface_details.instance_total,"position":[viewer.position.x,viewer.position.y,viewer.position.z],"timings":timings,"distant_builds":surface.distant.build_count,"distant_tiles":surface.distant.tiles.size()}
		surface.queue_free();viewer.queue_free();await process_frame
	FileAccess.open(folder+"/surface-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"profiles":rows,"lighting":"fixed review daylight; actual streamed scene, settled static shader comparison","settings":"Medium; 1280x800; uncapped; off/on/on/off, 120 frames each; not gameplay FPS","renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("SURFACE_MATERIAL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
