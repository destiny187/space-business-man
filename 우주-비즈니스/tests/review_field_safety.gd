extends "res://tests/check_ground_combat.gd"
func run() -> void:
	folder="/tmp/field-safety-play-20260915"
	if "--crew-ui-test" not in OS.get_cmdline_user_args() or "--crew-folder="+folder not in OS.get_cmdline_user_args():quit(2);return
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	var member: Dictionary=core.world.crew.members[actor_id]
	member.position=[0,4,0]
	for id in ["miner_1","miner_2","terrain_1","terrain_2"]:member.loadout.items["fixture:"+id]=id
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var store:=FrontierWorldStore.new(folder+"/world.json");check(store.write(core.world),"landed fixture saved")
	var profile:=FrontierPlayerProfile.new(folder+"/profile.json");profile.data={"version":1,"character":owner,"sessions":{}};profile.save()
	set_meta("expedition_mode","solo");set_meta("loading_destination","res://scenes/app/crew_expedition.tscn")
	var loader: Node=load("res://scenes/app/loading.tscn").instantiate();root.add_child(loader);current_scene=loader
	var covered_unready:=false
	var deadline:=Time.get_ticks_msec()+180000
	while is_instance_valid(loader) and Time.get_ticks_msec()<deadline:
		if is_instance_valid(loader.target) and loader.target is FrontierCrewExpedition:
			app=loader.target
			if app.surface_world!=null and not app.surface_world.landing_view_ready():
				covered_unready=has_meta("startup_loader")
		await process_frame
	check(not is_instance_valid(loader),"startup loader waits and completes")
	if is_instance_valid(loader):quit(1);return
	check(covered_unready and app.surface_world.landing_view_ready(),"cover stays until planetary terrain and models are ready")
	check(app.surface_world.terrain.ready_for([app.actors[actor_id].position]),"all local terrain collision chunks installed before reveal")
	if "--load-only" in OS.get_cmdline_user_args():
		check(app.surface_world.distant.fallback_task==-1 and app.surface_world.distant.fallback_queue.is_empty(),"temporary terrain coverage settled before reveal")
		check(await app.session.close_session(),"loaded session closes safely")
		app.queue_free();await process_frame
		print("FIELD_LOADING ",checks," FAILURES ",failures);quit(1 if failures else 0);return
	app.onboarding.letter.hide();app.onboarding.set_process(false);app.close_menus();app.outside=false;app.exterior_view.hide();app.if_flight_view()
	core=app.session.authority
	app.session.response_received.connect(func(_seq,value):
		if not value.get("ok",false):print("REJECT ",value))
	core.resolve_autonomous(true)
	var bag:=FrontierExpeditionBusiness.bag(core.world,actor_id)
	for crate in core.world.business.crates.values():
		FrontierExpeditionBusiness.transfer(bag,crate.inventory,1);crate.inventory=FrontierExpeditionBusiness.inventory()
	core.gun_dirty=true;app.session._publish()
	await create_timer(.5).timeout
	var walk_start: Vector3=app.actors[actor_id].position
	app.test_direction=Vector2(1,0);await create_timer(.5).timeout;app.test_direction=Vector2.ZERO
	check(app.actors[actor_id].position.distance_to(walk_start)>1,"normal walking stays available after loading")
	await capture("loaded")
	await verify_hull(app.surface_world.landing_ship,"common landed hull")
	core.resolve_autonomous(true)
	var holder: String=""
	for id in FrontierShuttles.fleet(core.world):
		if FrontierShuttles.fleet(core.world)[id].get("company",false):holder=id;break
	check(not holder.is_empty(),"shared FINCH available")
	if not holder.is_empty():
		var craft: Dictionary=FrontierShuttles.fleet(core.world)[holder]
		craft.deployment={"body_id":core.world.location,"position":[12,2,12],"yaw":0.0,"time":maxf(0,float(core.world.crew.navigation.orbit_time)-3)}
		app.session._publish();await create_timer(2.6).timeout
		check(app.surface_world.shuttle_models.has(holder),"deployed FINCH displayed")
		if app.surface_world.shuttle_models.has(holder):await verify_hull(app.surface_world.shuttle_models[holder],"FINCH")

	for id in ["miner_1","miner_2","terrain_1","terrain_2"]:
		app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:"+id})
		if not await until(func():return app.session.latest.crew.members[actor_id].loadout.slots[2]=="fixture:"+id,"equip "+id,5):continue
		await create_timer(.5).timeout
		check(is_instance_valid(app.feedback.tool_hands) and app.feedback.hand_contacts.size()==2,"Blender hand contacts connected "+id)
		if is_instance_valid(app.feedback.tool_hands):check(app.feedback.tool_hands.grip_error<.03,"hand IK reaches "+id)
		app.feedback.work_left=.6;app.feedback.recoil=.6 if id.begins_with("terrain") else 0
		await capture(id)
	app.session.send_request("equipment_equip",{"slot":2,"item_id":"fixture:pistol_1"})
	await until(func():return app.firearm.tool().get("item_id")=="fixture:pistol_1","pistol equipped",5)
	await create_timer(.6).timeout
	var ammo_before:=int(app.firearm.accepted.get("ammo",app.firearm.tool().magazine))
	app.pitch=.2;app.firearm.shoot()
	await until(func():return int(app.firearm.accepted.get("ammo",ammo_before))==ammo_before-1,"one shot updates remaining rounds",5)
	check(app.firearm.ammo_label.position.x>root.get_visible_rect().size.x*.7 and app.firearm.reload_hint.text=="R 재장전","bottom-right ammo and R hint")
	await capture("pistol-ammo")
	var event:=InputEventKey.new();event.physical_keycode=KEY_R;event.pressed=true;Input.parse_input_event(event)
	await until(func():return app.firearm.reload_left>0,"R starts authoritative reload",5)
	await capture("pistol-reload")
	event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
	await until(func():return app.firearm.reload_left<=0 and int(app.firearm.accepted.get("ammo",0))==int(app.firearm.tool().magazine),"reload refills magazine",5)
	root.size=Vector2i(960,640);root.content_scale_size=root.size;await capture("ammo-960")
	check(app.firearm.reload_hint.get_global_rect().end.x<=960 and app.firearm.reload_hint.get_global_rect().end.y<=640,"ammo and reload hint fit small window")
	app.toggle_inventory();await create_timer(.15).timeout;check(not app.firearm.hud.visible,"menu hides firearm overlay");app.toggle_inventory()
	check(await app.session.close_session(),"save after firing and reload")
	app.queue_free();await process_frame
	print("FIELD_SAFETY_PLAY ",checks," FAILURES ",failures);quit(1 if failures else 0)

func verify_hull(ship: Node3D,label: String) -> void:
	var solid:=ship.get_node_or_null("GroundHullCollision") as StaticBody3D
	check(solid!=null,label+" collider exists")
	if solid==null:return
	await physics_frame;await physics_frame
	var shape: ConcavePolygonShape3D=solid.get_child(0).shape
	var faces:=shape.get_faces()
	var contact: Dictionary={}
	for i in range(0,faces.size(),maxi(3,(faces.size()/150 as int)*3)):
		if i+2>=faces.size():break
		var a:=ship.to_global(faces[i]);var b:=ship.to_global(faces[i+1]);var c:=ship.to_global(faces[i+2])
		var normal: Vector3=(b-a).cross(c-a).normalized()
		if absf(normal.y)>.4:continue
		var center: Vector3=(a+b+c)/3
		for sign_value in [-1,1]:
			var query:=PhysicsRayQueryParameters3D.create(center+normal*sign_value*2,center-normal*sign_value*.2)
			var hit:=ship.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.collider==solid:contact=hit;break
		if not contact.is_empty():break
	check(not contact.is_empty(),label+" physical ray hits side of actual hull")
	if contact.is_empty():return
	var walker:=CharacterBody3D.new();ship.get_parent().add_child(walker)
	var capsule:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.22;capsule.shape=sphere;walker.add_child(capsule)
	walker.global_position=contact.position+contact.normal*.7
	await physics_frame
	var collision:=walker.move_and_collide(-contact.normal*1.2)
	check(collision!=null and collision.get_collider()==solid,label+" character body cannot pass through")
	walker.queue_free()
