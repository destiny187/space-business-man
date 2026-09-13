extends "res://tests/check_ground_combat.gd"
class ShotSession extends FrontierCrewSession:
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _exit_tree() -> void:
		if enet!=null:enet.close()
var apis: Array[SceneMultiplayer]=[]
var sessions: Array=[]
var replies: Dictionary={}
var launches: Dictionary={}
var packets: Dictionary={}
func poll_for(seconds: float) -> void:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		for api in apis:api.poll()
		await create_timer(.01).timeout
func run() -> void:
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	multiplayer_poll=false
	for index in 6:
		var branch:=Node.new();branch.name="Branch"+str(index);root.add_child(branch)
		var api:=SceneMultiplayer.new();set_multiplayer(api,branch.get_path());apis.append(api)
		var session:=ShotSession.new();session.name="Session";branch.add_child(session);sessions.append(session)
		var peer:=ENetMultiplayerPeer.new()
		if index==0:
			peer.set_bind_ip("127.0.0.1")
			if peer.create_server(24684,5,4)!=OK:quit(2);return
		else:peer.create_client("127.0.0.1",24684,4)
		api.multiplayer_peer=peer;session.enet=peer
	await poll_for(.2)
	var host: ShotSession=sessions[0];host.authority=core;host.hosting=true
	var original: Dictionary=core.world.crew.members[actor_id]
	for index in 6:
		var session: ShotSession=sessions[index];var peer: int=1 if index==0 else session.enet.get_unique_id()
		var id: String=actor_id if index==0 else FrontierPlayerProfile.new_character("원격 사수 "+str(index),index).character_id
		if index>0:
			core.world.crew.members[id]=original.duplicate(true);core.world.crew.members[id].profile=FrontierPlayerProfile.new_character("원격 사수",index);core.world.crew.members[id].profile.character_id=id
			core.world.crew.members[id].last_sequence=0;core.world.business.bags[id]=FrontierExpeditionBusiness.inventory()
		var member: Dictionary=core.world.crew.members[id]
		member.loadout.slots[2]="fixture:laser_2" if index%2 else "fixture:pulse_2";member.loadout.selected=2
		core.peers[peer]=id;core.inputs[peer]={"controls_enabled":true,"expires":10000000.0,"direction":Vector2.ZERO}
		session.active=true;session.session_id=core.session_id
		session.latest={"crew":core.world.crew.duplicate(true),"self_id":id,"location":core.world.location,"inventory":core.world.business.bags[id]}
		replies[index]=[];launches[index]=[]
		session.response_received.connect(func(seq,result):replies[index].append({"sequence":seq,"result":result}))
		session.firearm_event_received.connect(func(e):
			if not e.get("impact_only",false):launches[index].append(e))
		session.request_started.connect(func(seq,kind,args):packets[index]={"session_id":core.session_id,"sequence":seq,"kind":kind,"args":args.duplicate(true),"revision":core.world.crew.revision})
	check(sessions.all(func(s):return s.enet.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED) and core.peers.size()==6,"host and five independent ENet clients connected")
	core.shot_obstacle_provider=func(_actor,_origin,_direction,reach):return reach
	var ecology_ref: Dictionary=core.world.ecology;var terrain_ref: Dictionary=core.world.terrain_edits
	for delay in [.08,.14,.06]:
		for member in core.world.crew.members.values():FrontierFirearms.tick(member,.25)
		var stamp:=Time.get_ticks_msec()/1000.0;core.now=stamp
		core.firearm_history.capture(core.world,core.peers,stamp)
		for index in 6:
			var session: ShotSession=sessions[index];var id: String=core.peers[1 if index==0 else session.enet.get_unique_id()]
			core.firearm_history.issue(1 if index==0 else session.enet.get_unique_id(),stamp)
			session.latest.motion_time=stamp
			var gun:=FrontierEquipment.active(core.world.crew.members[id])
			session.send_request("surface_fire",{"item_id":gun.item_id,"aim":[0,1,0],"ads":false})
			if index>0:apis[index].poll()
		# Actual packets wait at the host. No fabricated response or direct fire call.
		await create_timer(delay).timeout
		await poll_for(.06);host._drain_firearm_events();await poll_for(.05)
	check(replies.values().all(func(rows):return rows.size()==3 and rows.all(func(r):return r.result.get("ok",false))),"all eighteen triggers accepted through RPC with 60–140 ms varied delay")
	check(launches.values().all(func(rows):return rows.size()==18),"all six observers receive every beam and ballistic launch exactly once")
	check(replies[1].all(func(r):return float(r.result.get("rewind_seconds",0))>0 and float(r.result.rewind_seconds)<=.2),"remote beam requests carry bounded host-issued history")
	var ammunition: Array=[]
	for member in core.world.crew.members.values():ammunition.append(FrontierFirearms.ensure(member,FrontierEquipment.active(member)).ammo)
	for index in range(1,6):sessions[index]._request.rpc_id(1,packets[index])
	await poll_for(.06);host._drain_firearm_events();await poll_for(.05)
	var after: Array=[]
	for member in core.world.crew.members.values():after.append(FrontierFirearms.ensure(member,FrontierEquipment.active(member)).ammo)
	check(ammunition==after and launches.values().all(func(rows):return rows.size()==18),"five duplicate requests do not spend ammo or repeat presentation")
	check(is_same(ecology_ref,core.world.ecology) and is_same(terrain_ref,core.world.terrain_edits),"fire path preserves unrelated world branches")
	for session in sessions:session.active=false;session.hosting=false;session.enet.close()
	for child in root.get_children():child.queue_free()
	await process_frame;await process_frame
	print("FIREARM_SIX_PEER_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
