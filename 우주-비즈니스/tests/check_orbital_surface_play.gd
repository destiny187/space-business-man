extends "res://tests/check_facility_interactions.gd"
var check_count:=0
func check(ok: bool,message: String) -> void:
	check_count+=1;super.check(ok,message)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder!="/tmp/orbital-surface-play" or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800)
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/production/media/orbital-terraforming/world.json"))
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.world_store.write(FrontierUniverse.new_world(71503));app.start_solo()
	if not await until(func():return app.flight!=null and not app.preparing_first_snapshot and not has_meta("startup_loader"),60):check(false,"startup");quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	var world: Dictionary=app.session.authority.world;var body:=FrontierUniverse.body_from_id(world.manifest,fixture.location)
	world.business=fixture.business.duplicate(true)
	var target:=FrontierUniverse.position(world.manifest,body.ordinal);var radius:=FrontierUniverse.radius(body)
	var offset:=(-target.normalized()+Vector3(0,.25,0)).normalized();var point:=target+offset*radius*3.1
	var nav: Dictionary=world.crew.navigation;nav.system=body.system_ordinal;nav.target=body.ordinal;nav.orbit_time=0.0;nav.speed=0.0;nav.mode="idle"
	nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array(-offset)
	world.location=body.id
	app.session._publish();await process_frame
	app.outside=true;app.exterior_view.show();app.if_flight_view();app.flight.scan_enabled=false
	await create_timer(1).timeout
	check(int(app.flight.planets[body.ordinal].node.material_override.get_shader_parameter("terraform_count"))>0,"app snapshot reaches actual exterior planet")
	var preferences:=FrontierClientSettings.ensure(self)
	var render_folder:=ProjectSettings.globalize_path("res://../docs/production/media/orbital-surfaces")
	var live: MeshInstance3D=app.flight.planets[body.ordinal].node
	check(live.material_override.get_shader_parameter("orbital_maps_enabled")==true,"actual exterior uses improved surface")
	app.flight.set_process(false)
	var screenshots: Array=[]
	for quality in [0,1,2]:
		preferences.set_quality("planet_surface",quality)
		await create_timer(.2).timeout;await RenderingServer.frame_post_draw
		var shot:=app.flight.get_viewport().get_texture().get_image()
		screenshots.append(shot.get_data());shot.save_png(render_folder+"/flight-"+str(quality)+".png")
		check(int(live.material_override.get_shader_parameter("terraform_count"))>0,"quality retains restored region "+str(quality))
	check(screenshots[0]!=screenshots[2],"live exterior quality changes rendered pixels")
	app.flight.set_process(true)
	app.toggle_navigation();app.navigation_ui.show_target(int(body.ordinal));await create_timer(1).timeout
	var preview_node: MeshInstance3D=app.navigation_ui.preview_body
	check(int(preview_node.material_override.get_shader_parameter("terraform_count"))>0,"actual navigation card includes restoration")
	check(preview_node.has_node("OrbitalCloudLayer") and preview_node.has_node("OrbitalAtmosphere"),"preview uses shared atmospheric layers")
	check(preview_node.material_override.get_shader_parameter("orbital_maps_enabled")==true,"navigation shares improved surface")
	var preview_material_id:=preview_node.material_override.get_instance_id()
	preferences.set_quality("planet_surface",0);preferences.set_quality("planet_surface",2)
	await create_timer(.3).timeout;await RenderingServer.frame_post_draw
	check(preview_node.material_override.get_instance_id()==preview_material_id,"live quality keeps preview model and recovery state")
	root.get_texture().get_image().save_png(render_folder+"/navigation.png")
	var material_id:=preview_node.material_override.get_instance_id()
	var previous_values: PackedVector4Array=preview_node.material_override.get_shader_parameter("terraform_values")
	world=app.session.authority.world
	var site: Dictionary=world.business.sites[body.id]
	for cell in site.free_terraform.cells.values():cell.environment.ecology=35.0
	site.free_terraform.revision+=1;app.session._publish();await create_timer(1.2).timeout
	check(preview_node.material_override.get_instance_id()==material_id,"open card updates material without recreating model")
	var values: PackedVector4Array=preview_node.material_override.get_shader_parameter("terraform_values")
	check(values[0].x<previous_values[0].x-.1,"open card receives changed host environment")
	for ordinal in [2,3]:
		app.navigation_ui.show_target(ordinal);await create_timer(.3).timeout
		var solar:=app.navigation_ui.preview_body as FrontierSolarPlanet
		check(solar!=null and solar.surfaces.all(func(n: Node3D):return n.material_override.get_shader_parameter("orbital_maps_enabled")==true),"solar preview uses mapped surfaces "+str(ordinal))
		check(solar.clouds.all(func(n: Node3D):return not n.visible),"solar preview replaces coarse authored cloud patches "+str(ordinal))
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(render_folder+"/navigation-solar-"+str(ordinal)+".png")
	root.size=Vector2i(960,640);await create_timer(.5).timeout;await capture("navigation-960")
	app.close_menus();check(app.navigation_ui.preview.render_target_update_mode==SubViewport.UPDATE_DISABLED,"closed preview suspends rendering")
	check(app.flight.vessel_sound.layers.size()>0,"existing vessel sound layers remain connected")
	await app.session.close_session();FileAccess.open(render_folder+"/play-verification.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":check_count,"failures":failures},"  "));print("ORBITAL_SURFACE_PLAY failures=",failures);quit(1 if failures else 0)
