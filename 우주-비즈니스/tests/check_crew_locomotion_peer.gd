extends "res://tests/test_crew_surface_peer.gd"
func handle_command(command: Dictionary) -> void:
	match command.kind:
		"prepare":
			app.outside=false;app.exterior_view.hide();app.navigation_frame.hide();app.onboarding.letter.hide();app.if_flight_view()
		"jump":app.test_jump=command.pressed
		"sprint":app.test_sprint=command.pressed
		"menu":app.inventory_panel.visible=command.visible
		"view_actor":
			var target: Vector3=app.actors[command.character_id].position+Vector3.UP*.9
			app.test_camera_position=target+Vector3(2.3,1.1,3.5)
			var direction: Vector3=(target-app.test_camera_position).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
		"capture_now":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+str(command.name)+".png")
		"land_fixture":
			var world: Dictionary=app.session.authority.world
			var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
			while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
			var body:=FrontierUniverse.body(world.manifest,ordinal)
			var nav: Dictionary=world.crew.navigation
			nav.system=23;nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
			var point:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30)
			nav.position=[point.x,point.y,point.z];nav.direction=[0,0,-1];world.location=body.id
			app.session._publish()
		_:super.handle_command(command)
func status_value() -> Dictionary:
	var value:=super.status_value()
	value["positions"]={};value["poses"]={}
	for id in app.actors:
		var actor: CharacterBody3D=app.actors[id];var pose: FrontierCrewPose=app.visuals[id].pose
		var foot: Dictionary={}
		for side in ["L","R"]:
			if pose.skeleton!=null:foot[side]=pose.skeleton.get_bone_pose_rotation(pose.bones["shin_"+side]).get_euler().x
		value.positions[id]=[actor.position.x,actor.position.y,actor.position.z]
		value.poses[id]={"bones":pose.bones.size(),"knees":foot,"motion":app.visuals[id].motion,"sound_playing":pose.speakers.any(func(p: AudioStreamPlayer3D):return p.playing)}
	value["arrival"]=app.arrival.active
	value["prediction_history"]=app.prediction_history.size()
	return value
