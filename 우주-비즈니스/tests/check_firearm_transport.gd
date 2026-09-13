extends SceneTree
class ShotSession extends FrontierCrewSession:
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _exit_tree() -> void:
		if enet!=null:enet.close()
var failures:=0
var received: Array=[]
var replies: Array=[]
var server_api: SceneMultiplayer
var client_api: SceneMultiplayer
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures+=1
func poll_for(seconds: float) -> void:
	var until:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		server_api.poll();client_api.poll();await create_timer(.01).timeout
func run() -> void:
	var world:=FrontierWorldStore.new("/tmp/firearm-upgrade-rules/world.json").read_state()
	if world.is_empty():printerr("Run check_firearm_upgrade first");quit(2);return
	multiplayer_poll=false
	var server_branch:=Node.new();server_branch.name="HostBranch";root.add_child(server_branch)
	var client_branch:=Node.new();client_branch.name="ClientBranch";root.add_child(client_branch)
	server_api=SceneMultiplayer.new();client_api=SceneMultiplayer.new()
	set_multiplayer(server_api,server_branch.get_path());set_multiplayer(client_api,client_branch.get_path())
	var host:=ShotSession.new();host.name="Session";server_branch.add_child(host)
	var client:=ShotSession.new();client.name="Session";client_branch.add_child(client)
	var server_peer:=ENetMultiplayerPeer.new();server_peer.set_bind_ip("127.0.0.1")
	if server_peer.create_server(24683,2,4)!=OK:quit(2);return
	var client_peer:=ENetMultiplayerPeer.new();client_peer.create_client("127.0.0.1",24683,4)
	server_api.multiplayer_peer=server_peer;client_api.multiplayer_peer=client_peer
	host.enet=server_peer;client.enet=client_peer
	await poll_for(.15)
	check(client_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"real ENet loopback established")
	if client_peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:quit(1);return
	var peer:=client_peer.get_unique_id();var owner: String=world.crew.owner_id
	var guest:=FrontierPlayerProfile.new_character("탄도 원격 검사",0);var actor: String=guest.character_id
	world.crew.members[actor]=world.crew.members[owner].duplicate(true);world.crew.members[actor].profile=guest;world.crew.members[actor].last_sequence=0
	world.business.bags[actor]=FrontierExpeditionBusiness.inventory();world.business.bags[actor]["ammo_light"]=10
	var member: Dictionary=world.crew.members[actor];member.loadout.slots[2]="fixture:smg_2";member.loadout.selected=2
	var gun:=FrontierEquipment.active(member);var state:=FrontierFirearms.ensure(member,gun)
	state.ammo=32;state.reload_left=0;state.reload_rounds=0;state.cooldown=0
	var core:=FrontierCrewAuthority.new();core.world=world;core.phase="playing";core.session_id="ballistic-transport-test";core.peers={1:owner,peer:actor}
	core.inputs[peer]={"expires":1000000.0,"controls_enabled":true,"direction":Vector2.ZERO}
	host.authority=core;host.hosting=true;host.active=true;host.session_id=core.session_id
	client.active=true;client.session_id=core.session_id;client.latest={"crew":world.crew.duplicate(true),"self_id":actor,"inventory":world.business.bags[actor],"location":world.location}
	client.firearm_event_received.connect(func(e):received.append(e))
	client.response_received.connect(func(seq,result):replies.append({"sequence":seq,"result":result}))
	# Hold server packet polling for 120 ms, then deliver through the actual request RPC.
	client.send_request("surface_fire",{"item_id":gun.item_id,"aim":[0,1,0],"ads":false});client_api.poll()
	await create_timer(.12).timeout
	check(state.ammo==32 and replies.is_empty(),"delayed request cannot confirm or consume a shot locally")
	await poll_for(.08);host._drain_firearm_events();await poll_for(.08)
	check(state.ammo==31 and replies.size()==1 and replies[0].result.get("ok",false),"delayed remote trigger consumes one host round")
	check(received.size()==1 and received[0].projectiles.size()==1,"remote launch arrives without periodic snapshot")
	for i in 3:
		FrontierFirearms.tick(member,.12)
		client.send_request("surface_fire",{"item_id":gun.item_id,"aim":[0,1,0],"ads":false})
		await poll_for(.025);host._drain_firearm_events();await poll_for(.025)
	check(received.size()==4 and received.map(func(e):return int(e.serial))==[1,2,3,4],"four reliable launch events retain every automatic shot")
	core.gun_events=core.ballistics.step(world,.02,func(_actor,_origin,_direction,reach):return minf(.1,reach))
	host._drain_firearm_events();await poll_for(.05)
	check(received.filter(func(e):return e.get("impact_only",false)).size()==4,"host impacts arrive on reliable event channel")
	# Replay the last exact request: receipt returns the same result without extra shots.
	client._request.rpc_id(1,{"session_id":core.session_id,"sequence":4,"revision":world.crew.revision,"kind":"surface_fire","args":{"item_id":gun.item_id,"aim":[0,1,0],"ads":false}})
	await poll_for(.05)
	check(state.ammo==28 and core.ballistics.count()==0,"remote request replay spends no additional ammunition")
	server_peer.close();client_peer.close();host.queue_free();client.queue_free();await process_frame
	print("FIREARM_TRANSPORT FAILURES ",failures);quit(1 if failures else 0)
