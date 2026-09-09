extends "res://tests/check_space_polish.gd"
func run() -> void:
	root.size=Vector2i(1280,800)
	out=ProjectSettings.globalize_path("res://../docs/production/media/space-polish-v2")
	var manifest:=FrontierUniverse.generate(61739)
	var target: Dictionary={}
	for system in range(1,45):
		for i in FrontierUniverse.body_count(manifest,system):
			var ordinal:=FrontierUniverse.first_ordinal(manifest,system)+i
			var body:=FrontierUniverse.body(manifest,ordinal)
			if int(body.moons)>0:target={"system":system,"ordinal":ordinal,"body":body};break
		if not target.is_empty():break
	view=FrontierCrewFlightView.new();view.state={"manifest":manifest};root.add_child(view)
	var nav: Dictionary={"system":target.system,"target":target.ordinal,"position":[0,0,50000],"direction":[0,0,-1],"speed":0.0,"mode":"idle","orbit_time":0.0}
	view.update_navigation(nav);view.exterior=true;view.scan_enabled=false;view.transit_overlay.hide()
	await create_timer(.5).timeout;view.set_process(false)
	var planet: Node3D=view.planets[target.ordinal].node
	var center:=planet.global_position;var sunward:=(-center).normalized();var radius:=FrontierUniverse.radius(target.body)
	view.ship.global_position=center+(sunward+Vector3.UP*.3).normalized()*radius*3.6;view.ship.look_at(center)
	view.orbital_presentation.update(1,0);await capture("eclipse-before")
	var moon: Node3D
	for m in view.landmarks.moon_nodes:
		if m.body.ordinal==target.ordinal:moon=m.node;break
	# Deliberate alignment of an existing visual moon, no save or simulation changes.
	moon.global_position=center+sunward*radius*1.8
	view.orbital_presentation.update(1,0);await capture("eclipse-aligned")
	print("SPACE POLISH: existing planet and moon shadow alignment rendered")
	view.queue_free();await process_frame;quit()
