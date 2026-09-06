extends "res://tests/test_crew_play_peer.gd"
var chosen: Dictionary={}
func run() -> void:
	if "--crew-ui-test" not in OS.get_cmdline_user_args():printerr("FAIL: isolated crew test flag required");quit(1);return
	super.run()
func handle_command(command: Dictionary) -> void:
	match command.kind:
		"look":
			var target:=Vector3(command.point[0],command.point[1],command.point[2])
			var eye: Vector3=FrontierCrewWorld.vector(app.session.latest.crew.members[app.session.latest.self_id].position)+Vector3.UP*1.72
			var direction: Vector3=(target-eye).normalized();app.yaw=atan2(-direction.x,-direction.z);app.pitch=asin(direction.y)
		"scan":app.test_scan=command.pressed
		"move_world":app.test_direction=Vector2(command.direction[0],command.direction[1]).rotated(app.yaw)
		"place":
			if not app.session.hosting:return
			var id: String=command.character_id
			if not app.actors.has(id):return
			var point:=Vector3(command.point[0],command.point[1],command.point[2]);app.actors[id].position=point;app.actors[id].velocity=Vector3.ZERO
			for peer in app.session.authority.peers:
				if app.session.authority.peers[peer]==id:app.session.authority.update_position(peer,point)
		"choose_specimen":choose_specimen()
		"surface_frame":surface_frame(str(command.get("name","surface")))
func choose_specimen() -> void:
	if app.surface_world==null or not app.session.hosting:return
	var core:=app.session.authority
	var terrain:=FrontierCrewSurface.field(core.world)
	for row in app.surface_world.ecology.encounters.values():
		if row.layer!="surface" or row.status!="active":continue
		var form:=FrontierEcologyCatalog.form(row.form_id)
		var height: float=(form.geometry.near.max[1]-form.geometry.near.floor_y)*FrontierEcologyCatalog.look(form.id,row.look_id).scale
		var center: Vector3=row.point+terrain.normal(row.point)*maxf(.35,height*.5)
		for angle in 8:
			var point: Vector3=row.point+Vector3(sin(angle*TAU/8)*2.2,0,cos(angle*TAU/8)*2.2);point.y=terrain.height(point.x,point.z)
			var id: String=core.peers[1];var old: Vector3=FrontierCrewWorld.vector(core.world.crew.members[id].position)
			core.update_position(1,point)
			var aim: Vector3=(center-point-Vector3.UP*1.72).normalized()
			var candidate:=FrontierCrewSurface.target(core.world,id,aim)
			core.update_position(1,old)
			if candidate.get("id")==row.id:
				chosen={"id":row.id,"form_id":row.form_id,"look_id":row.look_id,"observer":[point.x,point.y,point.z],"center":[center.x,center.y,center.z],"aim":[aim.x,aim.y,aim.z]};return
func status_value() -> Dictionary:
	var value:=super.status_value()
	value["chosen"]=chosen
	value["surface_loaded"]=app.surface_world!=null
	if app.surface_world!=null:
		var surface:=app.surface_world
		value["surface_ready"]=surface.terrain.jobs.is_empty() and surface.terrain.chunks.size()==surface.terrain.wanted.size() and surface.terrain.batch.is_empty() and surface.applied_edits==surface.incoming.size()
		value["body_id"]=surface.body.id
		value["edit_count"]=surface.applied_edits
		value["lineages"]=surface.ecology.ecology.planets[surface.body.id].lineages
		value["ecology_actors"]=surface.ecology.actors.keys()
		value["target"]=app.surface_target.get("id","")
		value["terrain_hash"]=FrontierUniverse.fingerprint({"edits":surface.incoming})
		value["observations"]=surface.ecology.ecology.get("observations",{})
		value["specimens"]=app.session.surface.get("ecology",{}).get("specimens",{})
		value["introductions"]=surface.ecology.ecology.planets[surface.body.id].introductions
	value["surface_bytes_sent"]=app.session.surface_bytes_sent
	return value
func surface_frame(name_value: String) -> void:
	if capturing:return
	capturing=true
	await create_timer(.4).timeout;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value.validate_filename()+".png")
	capturing=false
