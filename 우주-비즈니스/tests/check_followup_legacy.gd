extends "res://tests/test_presentation.gd"
## Focused real legacy scene review for assets still used by this entry path.
func run() -> void:
	root.size=Vector2i(1280,800)
	destination=ProjectSettings.globalize_path("res://../docs/production/media/ink-followups")
	app=load("res://scenes/app/main.tscn").instantiate();root.add_child(app)
	app.smoke_mode=true;app.campaign.persistence_enabled=false
	app._smoke_setup()
	var p: Dictionary=app.campaign.planet
	for tech in ["advanced","combat","ancient"]:
		if tech not in app.campaign.profile.technologies:app.campaign.profile.technologies.append(tech)
	p.inventory.iron=2000;p.inventory.copper=800;p.inventory.crystal=100
	check(app.campaign.build("reactor",Vector2(-15,-12)).is_empty(),"reactor built through campaign")
	for kind in ["surveyor","guardian"]:
		check(app.campaign.craft(kind).is_empty(),kind+" accepted production")
		for i in range(260):app.simulation.step(app.campaign,.1)
	p=app.campaign.planet
	p.environment.ecology=80.0
	app.world.rebuild(p);app._close_menu();app.world.toggle_camera()
	app.world.orbital_camera.position=Vector3(28,22,32)
	app.world.orbital_camera.look_at(Vector3(0,1,-3))
	await create_timer(.8).timeout
	check(app.world.foliage.any(func(t:Node3D):return t.visible),"new trees appear with ecology")
	for event in p.events:
		check(app.world.visual_nodes.has(event.id),event.kind+" actual discovery model loaded")
	await capture("legacy-settlement")
	var survey: Dictionary={};var guard: Dictionary={}
	for robot in p.robots:
		if robot.model=="surveyor":survey=robot
		if robot.model=="guardian":guard=robot
	check(not survey.is_empty() and not guard.is_empty(),"both replacement robots manufactured")
	if survey.is_empty() or guard.is_empty():quit(1);return
	var object:Node3D=app.world.robot_nodes[survey.id]
	var wheel:Node3D=object.find_child("Anim_Wheel*",true,false)
	check(wheel!=null,"surveyor wheel rig loaded")
	var axle:Vector3=wheel.basis.y.normalized()
	# Freeze simulation only; the real planet_view animation continues.
	app.set_process(false)
	survey.position=[object.position.x+4,object.position.z]
	await create_timer(.15).timeout
	check(absf(wheel.basis.y.normalized().dot(axle))>.999,"wheel spins around its own axle")
	var rotor:Node3D=object.find_child("ToolRotor",true,false)
	var drill_axis:Vector3=rotor.basis.y.normalized()
	survey.status="채광 중";survey.target=p.nodes[0].id
	app.world.orbital_camera.position=object.position+Vector3(5,3,6)
	app.world.orbital_camera.look_at(object.position+Vector3.UP)
	await create_timer(.15).timeout
	check(absf(rotor.basis.y.normalized().dot(drill_axis))>.999,"drill spins around its own shaft")
	await capture("legacy-surveyor-working")
	app.set_process(true)
	var civ:Dictionary=p.events[3]
	p.player.position=civ.position.duplicate();app.campaign.discover(civ.id)
	check(app.campaign.choose_event(civ.id,"destroy").is_empty(),"guardian operation accepted")
	p=app.campaign.planet
	guard=FrontierCampaign.find_by_id(p.robots,guard.id)
	guard.position=[civ.position[0]+7,civ.position[1]]
	app.world.rebuild(p);app._close_menu();app.world.toggle_camera()
	app.world.orbital_camera.position=Vector3(civ.position[0]+13,7,civ.position[1]+10)
	app.world.orbital_camera.look_at(Vector3(civ.position[0]+5,1,civ.position[1]))
	var pulses:int=app.world.effects.emitted.pulse
	await create_timer(1.1).timeout
	check(app.world.effects.emitted.pulse>pulses,"new guardian aims and fires actual effects")
	check(app.world.robot_nodes[guard.id].has_meta("turret"),"turret and barrels attached to aiming rig")
	await capture("legacy-guardian-operation")
	print("FOLLOWUP_LEGACY checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
