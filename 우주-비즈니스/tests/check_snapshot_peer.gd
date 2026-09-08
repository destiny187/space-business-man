extends SceneTree
var session: FrontierCrewSession
var role: String="host"
var elapsed:=0.0
var started:=false
var ready_sent:=false
var finishing:=false
var folder: String="/tmp/snapshot-peers"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--packet-role="):role=argument.trim_prefix("--packet-role=")
	session=FrontierCrewSession.new();session.name="Coop";root.add_child(session)
	session.notice.connect(func(message: String):print(role,": ",message))
	var profile:=FrontierPlayerProfile.new(folder+("/host.json" if role=="host" else "/guest.json"));profile.ensure()
	var ok:=session.host(profile,FrontierWorldStore.new(folder+"/world.json"),24617,"127.0.0.1") if role=="host" else session.join(profile,"127.0.0.1",24617)
	if not ok:quit(1)
func _process(delta: float) -> bool:
	elapsed+=delta
	if finishing or session==null:return false
	if elapsed>30:finish(false);return false
	if session.latest.is_empty():return false
	if role=="guest":
		if session.active and not ready_sent:session.send_request("lobby_ready",{"value":true});ready_sent=true
		if session.active and session.received_serial>=15 and not session.surface.is_empty():finish(session.latest.local_shuttle!="" and session.surface.body_id==session.latest.location)
	else:
		if session.authority.peers.size()==2 and not started:
			var ids:=session.authority.peers.values();ids.erase(session.authority.world.crew.owner_id)
			if session.authority.lobby_ready.get(ids[0],false):session.send_request("start_game",{});started=true
		if started and FileAccess.file_exists(folder+"/guest-result.json"):finish(session.snapshot_largest_fragment<=900 and session.snapshot_bytes_sent>0)
	return false
func finish(ok: bool) -> void:
	finishing=true
	var file:=FileAccess.open(folder+"/"+role+"-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":ok,"serial":session.received_serial,"largest_payload":session.snapshot_largest_fragment,"bytes_sent":session.snapshot_bytes_sent,"surface_bytes_sent":session.surface_bytes_sent}));file.close()
	print("SNAPSHOT_ENET_",role.to_upper()," ","PASS" if ok else "FAIL")
	await session.close_session();session.queue_free();await process_frame;await process_frame;quit(0 if ok else 1)
