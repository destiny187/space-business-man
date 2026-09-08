extends "res://tests/test_crew_surface.gd"
## Focused visual check on the real streamed surface, with fixed comparison lighting.
var folder: String="res://../docs/production/media/planet-surfaces-v2"
func capture(id: String) -> void:
	await create_timer(.25).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+id+".png")
func run() -> void:
	root.size=Vector2i(1280,800);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
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
	var ids: Array=FrontierSurfaceMaterialLibrary.config().profiles.keys()
	var requested:=OS.get_cmdline_user_args()
	for arg in requested:
		if arg.begins_with("--families="):ids=arg.trim_prefix("--families=").split(",")
	for id in ids:
		var b: Dictionary=samples[id];core.world.location=b.id;core.world.crew.landing={"body_id":b.id,"epoch":1};core.world.crew.members[owner.character_id].position=FrontierCrewSurface.config().ship_position.duplicate()
		FrontierEcology.ensure_planet(core.world.ecology,b);FrontierPlanetaryCycles.ensure_region(core.world,b)
		core.world.business=FrontierExpeditionBusiness.create();FrontierExpeditionBusiness.ensure_site(core.world)
		var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
		var viewer:=Node3D.new();root.add_child(viewer);viewer.position=Vector3(-23,4,23)
		var camera:=Camera3D.new();viewer.add_child(camera);camera.current=true;camera.far=2000;camera.look_at_from_position(Vector3(-25,4.2,29),Vector3(-29,2,8))
		var surface:=FrontierCrewSurfaceScene.new();root.add_child(surface);surface.configure(session,packet,viewer,camera);FrontierInkStyle.attach(surface)
		var deadline:=Time.get_ticks_msec()+20000
		while Time.get_ticks_msec()<deadline:
			await process_frame
			if surface.terrain.completed_jobs>=40 and surface.surface_details.tiles.size()>=6:break
		surface.set_process(false);surface.lamp.light_energy=0;surface.atmosphere.sun.rotation_degrees=Vector3(-42,-32,0);surface.atmosphere.sun.light_energy=1.5;surface.atmosphere.sun.light_color=Color("ffedda")
		surface.environment.fog_enabled=false;surface.environment.background_mode=Environment.BG_COLOR;surface.environment.background_color=Color("819194");surface.environment.ambient_light_energy=.55;surface.environment.ambient_light_color=Color("aebcc4")
		var mat: ShaderMaterial=surface.terrain.material
		var fallback:=surface.distant.get_node_or_null("StreamingFallback") as MeshInstance3D
		check(fallback==null or fallback.material_override==mat,id+" fallback shares surface material")
		check(mat.get_shader_parameter("surface_textures") is Texture2DArray,id+" packed material bound")
		check(surface.terrain.completed_jobs>0 and surface.surface_details.instance_total>0,id+" terrain and Blender scatter")
		check(is_equal_approx(surface.terrain.field.height(0,0),2),id+" landing collision height")
		await capture("ground-"+id)
		if id in ["oxidized","tundra"]:
			var shader:=mat.shader;var dust: Variant=mat.get_shader_parameter("dust_color");mat.set_shader_parameter("dust_color",Color(b.traits.dust));var before:=Shader.new();before.code=FileAccess.get_file_as_string("res://tests/fixtures/terrain-before-materials.gdshader");mat.shader=before;await capture("before-"+id);mat.shader=shader;mat.set_shader_parameter("dust_color",dust);FrontierSurfaceMaterialLibrary.configure(mat,b)
			# Close view, unchanged camera/geometry across the material comparison.
			camera.look_at_from_position(Vector3(-25,3.6,25),Vector3(-26,2,21));await capture("close-"+id)
		if id=="tundra":
			surface.business_view.set_process(false);mat.set_shader_parameter("local_temperature",18.0);await capture("tundra-thawed")
		if id in ["crystalline","sedimentary","alkaline"]:
			camera.look_at_from_position(Vector3(-25,3.4,25),Vector3(-27,2,19));await capture("close-"+id)
		rows[id]={"seed":b.seed,"profile":b.traits.id,"geology":b.mineral_profile.id,"terrain_jobs":surface.terrain.completed_jobs,"scatter":surface.surface_details.instance_total}
		surface.queue_free();viewer.queue_free();await process_frame
	FileAccess.open(folder+"/surface-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"profiles":rows,"lighting":"fixed review daylight; real streamed scene","renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("SURFACE_MATERIAL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
