extends "res://tests/check_shuttle_peer.gd"
var ready_sent:=false
var started:=false
var phase_time:=0.0
var initial: Dictionary={}
var finishing:=false
func _process(delta: float) -> bool:
	super._process(delta)
	if app==null or app.session.latest.is_empty() or finishing:return false
	var snapshot: Dictionary=app.session.latest
	if snapshot.get("phase")=="lobby":
		if role!="host" and app.session.active and not ready_sent:app.session.send_request("lobby_ready",{"value":true});ready_sent=true
		if role=="host" and app.session.authority.peers.size()==2 and not started:
			var everyone:=true
			for id in app.session.authority.peers.values():
				if id!=snapshot.crew.owner_id and not snapshot.lobby_ready.get(id,false):everyone=false
			if everyone:app.session.send_request("start_game",{});started=true
		return false
	if app.surface_world==null or not app.surface_world.ready_at(app.actors[snapshot.self_id].position):return false
	if initial.is_empty():
		if role=="host":
			for peer in app.session.authority.peers:
				var id: String=app.session.authority.peers[peer]
				var terrain:=app.spaces.terrain_for(id)
				if terrain==null or not terrain.ready_at(app.actors[id].position):return false
		for id in app.actors:initial[id]=FrontierExpeditionBusiness.array(app.actors[id].position)
		app.test_direction=Vector2(.5,0)
	phase_time+=delta
	if phase_time>2:app.test_direction=Vector2.ZERO
	if phase_time<4:return false
	finishing=true
	finish_check()
	return false
func finish_check() -> void:
	var value:=status_value();var moved: Dictionary={}
	for id in initial:moved[id]=FrontierCrewWorld.vector(initial[id]).distance_to(FrontierCrewWorld.vector(value.positions[id]))>.1
	var snapshot: Dictionary=app.session.latest
	var ok: bool=moved.get(snapshot.self_id,false)
	if role=="host":
		ok=ok and app.spaces.spaces.size()==1 and moved.values().all(func(v):return v)
		ok=ok and app.surface_world.body.id==snapshot.main_location
	else:ok=ok and not snapshot.local_shuttle.is_empty() and app.surface_world.body.id!=snapshot.main_location
	value["passed"]=ok;value["moved"]=moved
	var output:=FileAccess.open(folder+"/auto-result.json",FileAccess.WRITE);output.store_string(JSON.stringify(value));output.close()
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(folder+"/split-final.png")
	print("TWO_PLANET_",role.to_upper()," ","PASS" if ok else "FAIL")
	# Give the other role time to record the same connected session.
	await create_timer(3).timeout
	await app.session.close_session();app.queue_free();await process_frame;await process_frame
	quit(0 if ok else 1)
