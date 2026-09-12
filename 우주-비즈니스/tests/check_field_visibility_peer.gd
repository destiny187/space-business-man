extends "res://tests/test_crew_surface_peer.gd"
var watched:=""
var cover: Node3D
var last_state:=""
func run() -> void:
	super.run()
	root.size=Vector2i(1280,800)
	var settings:=FrontierClientSettings.ensure(self);settings._preset(1);settings.values.fps=30;settings.values.vsync=false;settings.apply_all()
func handle_command(command: Dictionary) -> void:
	match command.kind:
		"prepare":
			app.outside=false;app.exterior_view.hide();app.onboarding.letter.hide();app.close_menus();app.if_flight_view()
		"watch":
			watched=command.id
			var actor: Node3D=app.surface_world.ecology.actors[watched]
			var target: Vector3=actor.global_position+Vector3.UP
			app.test_camera_position=target+Vector3(0,4,-20 if command.get("back",false) else 30)
			var direction: Vector3=(target-app.test_camera_position).normalized()
			app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
		"turn":app.yaw+=PI
		"cover":
			if is_instance_valid(cover):cover.queue_free();cover=null
			if not command.enabled:return
			var actor: Node3D=app.surface_world.ecology.actors[watched]
			cover=Node3D.new();app.surface_world.add_child(cover);cover.position=actor.position+Vector3(0,4,15)
			var box:=BoxMesh.new();box.size=Vector3(80,50,.5)
			var visual:=MeshInstance3D.new();visual.mesh=box;var material:=StandardMaterial3D.new();material.albedo_color=Color("577680");visual.material_override=material;cover.add_child(visual)
			var vertices:=box.get_faces();var indices:=PackedInt32Array()
			for i in vertices.size():indices.append(i)
			cover.add_child(FrontierFieldVisibility.terrain_occluder(vertices,indices))
		"equip_dig_fixture":
			if not app.session.hosting:return
			var member: Dictionary=app.session.authority.world.crew.members[command.id]
			member.loadout.items["visibility-test-tool"]="terrain_1";member.loadout.slots[1]="visibility-test-tool";member.loadout.selected=1
			app.session._publish()
		"capture_now":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+"/"+str(command.name)+".png")
		_:super.handle_command(command)
func status_value() -> Dictionary:
	var value:=super.status_value()
	value.arrival=app.arrival.active;value.disable_3d=root.disable_3d;value.occlusion=root.use_occlusion_culling
	value.draw_calls=root.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	value.renderer=RenderingServer.get_current_rendering_method()
	value.viewport_size=[root.size.x,root.size.y]
	value.tick_ms=Time.get_ticks_msec()
	value.network_peers=app.session.authority.peers.size() if app.session.hosting else 0
	value.network_pending=app.session.pending_connections.size()
	var transition:=str([value.active,value.get("surface_ready",false),value.arrival,value.snapshot.get("phase",""),value.snapshot.get("crew",{}).get("members",{}).size(),value.network_peers,value.network_pending,messages])
	if transition!=last_state:
		print("PEER_STATE ",value.tick_ms," ",transition);last_state=transition
	value.positions={}
	for id in app.actors:value.positions[id]=FrontierExpeditionBusiness.array(app.actors[id].position)
	value.creatures={};value.watched={};value.articulated=[]
	if app.surface_world!=null:
		var ecology: FrontierSurfaceEcology=app.surface_world.ecology
		for id in ecology.actors:
			var actor: Node3D=ecology.actors[id]
			value.creatures[id]=FrontierExpeditionBusiness.array(actor.position)
			if not actor.joints[0].is_empty():value.articulated.append(id)
			if id!=watched:continue
			var pose_data: Array=[]
			for row in actor.joints:
				for part in row.values():pose_data.append(part.node.transform)
			value.watched={"id":id,"visible":FrontierFieldVisibility.active(actor.visibility_notifier),"clock":actor.elapsed,"pose":hash(str(pose_data))}
		var paired:=true;var count:=0
		for chunk in app.surface_world.terrain.chunks.values():
			if chunk.triangles<=0:continue
			var occluder:=chunk.node.get_node_or_null("TerrainOccluder") as OccluderInstance3D
			paired=paired and occluder!=null and occluder.occluder.indices.size()==int(chunk.triangles)*3;count+=1
		value.occluders_paired=paired;value.occluder_chunks=count
	return value
