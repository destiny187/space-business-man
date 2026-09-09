extends "res://tests/check_space_polish.gd"
func run() -> void:
	root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	out=ProjectSettings.globalize_path("res://../docs/production/media/space-polish-v2")
	var manifest:=FrontierUniverse.generate(61739)
	view=FrontierCrewFlightView.new();view.state={"manifest":manifest};root.add_child(view)
	var nav: Dictionary={"system":0,"target":5,"position":[0,0,50000],"direction":[0,0,-1],"speed":0.0,"mode":"idle","orbit_time":0.0}
	view.update_navigation(nav);view.exterior=true;view.scan_enabled=false;view.transit_overlay.hide()
	await create_timer(.4).timeout;view.set_process(false)
	var saturn:=FrontierUniverse.position(manifest,5)
	var ring: Dictionary={}
	for r in view.orbital_presentation.rings:
		if r.planet==view.planets[5].node:ring=r;break
	var ring_basis: Basis=ring.node.global_basis.orthonormalized()
	view.ship.global_position=saturn+ring_basis*Vector3(ring.radius*2.32,110,0)
	view.ship.look_at(saturn+ring_basis*Vector3(ring.radius*1.65,0,0));view.orbital_presentation.update(1,0)
	await capture("ring-near")
	print("RING DETAIL visible instances ",view.orbital_debris.fields[1].multimesh.visible_instance_count)
	var cloudy: Dictionary={};var belt_index: int=-1
	for system in range(1,45):
		if belt_index<0 and FrontierUniverse.system_layout(manifest,system).belt_radius>0:belt_index=system
		for i in FrontierUniverse.body_count(manifest,system):
			var ordinal:=FrontierUniverse.first_ordinal(manifest,system)+i;var body:=FrontierUniverse.body(manifest,ordinal)
			if cloudy.is_empty() and FrontierUniverse.landable(body) and float(body.traits.cloud)>.4:cloudy={"body":body,"ordinal":ordinal,"system":system}
		if belt_index>=0 and not cloudy.is_empty():break
	nav.system=cloudy.system;nav.target=cloudy.ordinal;view.update_navigation(nav);view.transit_overlay.hide()
	var planet: Node3D=view.planets[cloudy.ordinal].node;var radius:=FrontierUniverse.radius(cloudy.body)
	var sunward:=(-planet.position).normalized();view.ship.position=planet.position+(sunward*.55+sunward.cross(Vector3.UP)+Vector3.UP*.2).normalized()*radius*3.4
	view.ship.look_at(planet.global_position);view.orbital_presentation.update(1,8)
	await capture("cloudy-world")
	# Show the same world later; independent shell motion and shadows use shared epoch.
	view.update_orbits(110);view.orbital_presentation.update(1,110);view.ship.look_at(planet.global_position)
	await capture("cloudy-world-motion")
	nav.system=belt_index;nav.target=FrontierUniverse.first_ordinal(manifest,belt_index);view.update_navigation(nav);view.transit_overlay.hide()
	var belt_radius: float=FrontierUniverse.system_layout(manifest,belt_index).belt_radius
	view.ship.position=Vector3(belt_radius,80,0);view.ship.look_at(Vector3(belt_radius,0,-1000));view.orbital_presentation.update(1,0)
	await capture("asteroid-near")
	print("BELT DETAIL visible instances ",view.orbital_debris.fields[0].multimesh.visible_instance_count)
	view.refits.update_loadout({"hull":"finch"});await create_timer(1).timeout
	view.drive.set_thrust(.75,true);view.drive.set_motion(Vector2(.6,.3),0,false)
	view.camera.position=Vector3(6,7,12);view.camera.look_at(view.ship.global_position+Vector3.UP*2);view.orbital_presentation.update(1,0)
	await create_timer(.6).timeout;await capture("finch-drive-detail")
	# Isolated new asset renders use the actual game shader and contour.
	view.queue_free();await process_frame
	for id in ["attitude_nozzle","orbital_rock","orbital_ice"]:
		var scene:=Node3D.new();root.add_child(scene)
		var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("1b2630");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("d2dce5");e.ambient_light_energy=.3;env.environment=e;scene.add_child(env)
		var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-30,0);light.light_energy=1.5;scene.add_child(light)
		var model: Node3D=load("res://assets/models/space/"+id+".glb").instantiate();FrontierInkStyle.apply(model,{});scene.add_child(model)
		var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.3 if id=="attitude_nozzle" else 4.0;camera.position=Vector3(2,2,4);camera.look_at(Vector3.ZERO)
		FrontierInkStyle.attach(scene,true);await capture(id+"-ink")
		scene.queue_free();await process_frame
	print("SPACE POLISH DETAILS: near rings, belt, cloud motion, FINCH and INK assets rendered")
	quit()
