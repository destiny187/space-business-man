class_name FrontierCrewSession
extends Node
const SnapshotDelta=preload("res://scripts/network/crew_snapshot_delta.gd")
signal discoveries_received(serial: int,value: Dictionary)
signal snapshot_received(value: Dictionary)
signal notice(message: String)
signal surface_received(value: Dictionary)
signal response_received(sequence: int,value: Dictionary)
signal request_started(sequence: int,kind: String,args: Dictionary)
var local_request_guard: Callable
var mine_sequence:=0
var mine_ready_at:=0
var mine_revision:=0
var authority: FrontierCrewAuthority
# MultiplayerPeer is the transport boundary for direct, local relay and future SDK peers.
var enet: MultiplayerPeer
var relay_pending: FrontierCrewRelayPeer
var connecting:=false
var closing:=false
var connection_kind:="direct"
var invite_code:=""
signal connection_lost(message: String)
var profile: FrontierPlayerProfile
var store: FrontierWorldStore
var latest: Dictionary={}
var manifest: Dictionary={}
var checkpoint_timer:=5.0
var session_id:=""
var world_id:=""
var active:=false
var hosting:=false
var offline:=false
var next_sequence:=1
var movement_sequence:=0
var snapshot_serial:=0
var received_serial:=-1
var snapshot_transport:=FrontierCrewSnapshotTransport.new()
var snapshot_delta:=SnapshotDelta.new()
var peer_snapshot_deltas: Dictionary={}
var snapshot_bytes_sent:=0
var snapshot_largest_fragment:=0
var snapshot_timer:=0.0
var pending_connections: Dictionary={}
var closing_connections: Dictionary={}
var rate_windows: Dictionary={}
var surface: Dictionary={}
var surface_timer:=0.0
var surface_serial:=0
var received_surface_serial:=-1
var surface_digests: Dictionary={}
var surface_bytes_sent:=0
func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.connection_failed.connect(func():active=false;notice.emit("호스트에 연결하지 못했습니다. 주소와 UDP 포트를 확인하세요."))
func host(local_profile: FrontierPlayerProfile,world_store: FrontierWorldStore,port: int=24560,bind_ip: String="*",solo: bool=false,transport: MultiplayerPeer=null) -> bool:
	if connecting or enet!=null or hosting:notice.emit("현재 연결을 종료한 뒤 새 방을 열어 주세요.");return false
	profile=local_profile;store=world_store
	if profile.data.is_empty():notice.emit("개인 프로필을 먼저 열어 주세요.");return false
	var state:=store.read_state()
	if state.is_empty():
		if store.has_history():notice.emit(store.last_error);return false
		state=FrontierUniverse.new_world(int(Crypto.new().generate_random_bytes(4).decode_u32(0)&0x7fffffff))
	authority=FrontierCrewAuthority.new()
	if not authority.start(state,profile.data.character,store.write):notice.emit(authority.error);return false
	offline=solo
	connection_kind="local_relay" if transport is FrontierCrewRelayPeer else ("solo" if solo else "direct")
	if transport==null:invite_code=""
	if offline:multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	elif transport!=null:
		enet=transport;multiplayer.multiplayer_peer=enet
	else:
		var direct:=ENetMultiplayerPeer.new();direct.set_bind_ip(bind_ip)
		var result:=direct.create_server(port,11,4)
		if result!=OK:notice.emit("이 UDP 포트로 방을 열 수 없습니다: "+str(result));enet=null;return false
		enet=direct;multiplayer.multiplayer_peer=enet
	peer_snapshot_deltas.clear()
	hosting=true;active=true
	session_id=authority.session_id;world_id=authority.world.crew.world_id;manifest=authority.world.manifest.duplicate(true)
	next_sequence=int(authority.world.crew.members[profile.data.character.character_id].last_sequence)+1
	_publish();notice.emit("세계를 열었습니다. 준비 후 시작하세요." if offline else "대기실을 열었습니다. 참가자 준비 후 호스트가 시작합니다.");return true
func join(local_profile: FrontierPlayerProfile,address: String,port: int=24560) -> bool:
	if connecting or enet!=null or hosting:notice.emit("현재 연결을 종료한 뒤 다시 참가하세요.");return false
	profile=local_profile;connection_kind="direct";invite_code=""
	if profile.data.is_empty():notice.emit("개인 프로필을 먼저 열어 주세요.");return false
	var direct:=ENetMultiplayerPeer.new()
	var result:=direct.create_client(address,port,4)
	if result!=OK:notice.emit("접속을 시작할 수 없습니다: "+str(result));enet=null;return false
	enet=direct;multiplayer.multiplayer_peer=enet;hosting=false;active=false;received_serial=-1
	notice.emit("호스트에 연결 중입니다.");return true
func connect_relay(local_profile: FrontierPlayerProfile,world_store: FrontierWorldStore,url: String,create: bool,code: String="") -> bool:
	if connecting or enet!=null or hosting:notice.emit("현재 연결을 종료한 뒤 다시 시도하세요.");return false
	if local_profile.data.is_empty():notice.emit("개인 프로필을 먼저 열어 주세요.");return false
	connecting=true;notice.emit("초대 방을 만드는 중입니다." if create else "초대 방에 연결 중입니다.")
	if create:FrontierCrewLocalRelay.ensure_for(get_tree(),url)
	var candidate:=FrontierCrewRelayPeer.new();relay_pending=candidate
	var opened: bool=await candidate.open(get_tree(),url,create,code)
	if relay_pending!=candidate:return false
	relay_pending=null;connecting=false
	if not opened:notice.emit(candidate.error);return false
	connection_kind="local_relay";invite_code=candidate.room_code
	candidate.failed.connect(func(message: String):call_deferred("_relay_lost",candidate,message))
	if create:
		if host(local_profile,world_store,24560,"*",false,candidate):return true
		candidate.close();invite_code="";return false
	return join_transport(local_profile,candidate)

# Platform SDK adapters supply a peer with the host at ID 1. Platform identity
# verification belongs to the adapter; crew admission and reconnect stay here.
func join_transport(local_profile: FrontierPlayerProfile,transport: MultiplayerPeer) -> bool:
	if connecting or enet!=null or hosting or local_profile.data.is_empty() or transport==null:return false
	profile=local_profile;enet=transport;hosting=false;offline=false;active=false;received_serial=-1
	multiplayer.multiplayer_peer=enet
	notice.emit("호스트와 캐릭터를 확인 중입니다.");return true

func _relay_lost(candidate: MultiplayerPeer,message: String) -> void:
	if enet!=candidate:return
	active=false
	var unsaved:=hosting and authority!=null and not authority.close()
	if unsaved:message+="\n"+authority.error+" 시작 화면으로 나갈 때 다시 저장합니다."
	hosting=unsaved;enet.close();enet=null;invite_code="";latest={};surface={}
	pending_connections.clear();closing_connections.clear();rate_windows.clear();surface_digests.clear()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	notice.emit(message);connection_lost.emit(message)

func _peer_connected(peer: int) -> void:
	if not hosting:return
	pending_connections[peer]=Time.get_ticks_msec()/1000.0+float(FrontierCrewWorld.config().handshake_seconds)
	_offer.rpc_id(peer,session_id,world_id,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
func _peer_disconnected(peer: int) -> void:
	if not hosting:return
	pending_connections.erase(peer);closing_connections.erase(peer);rate_windows.erase(peer);surface_digests.erase(peer);peer_snapshot_deltas.erase(peer)
	if not authority.disconnect_member(peer):
		active=false;notice.emit(authority.error)
		if not offline:_closed.rpc(authority.error);return
	_publish()
func _server_disconnected() -> void:
	active=false;latest={};surface={};notice.emit("호스트 연결이 종료됐습니다. 개인 장비 원본은 유지됩니다.")
	if enet is FrontierCrewRelayPeer:call_deferred("_relay_lost",enet,enet.error if not enet.error.is_empty() else "호스트 연결이 종료됐습니다.")
func _process(delta: float) -> void:
	if not hosting or (enet==null and not offline) or authority.stopped:return
	var now:=Time.get_ticks_msec()/1000.0
	for peer in authority.advance_time(now):_reject_peer(peer,"참가 준비 시간이 초과됐습니다.")
	for peer in pending_connections.keys():
		if pending_connections[peer]<=now:_reject_peer(peer,"호스트와 버전·프로필 확인을 완료하지 못했습니다.")
	for peer in closing_connections.keys():
		if closing_connections[peer]<=now:
			enet.disconnect_peer(peer);closing_connections.erase(peer)
	surface_timer-=delta
	if surface_timer<=0:
		surface_timer=float(FrontierCrewSurface.config().snapshot_interval)
		_publish_surface()
	snapshot_timer-=delta
	if snapshot_timer<=0:snapshot_timer=1.0/float(FrontierCrewWorld.config().snapshot_hz);_publish()
func _publish() -> void:
	if not hosting or authority==null or authority.stopped:return
	snapshot_serial+=1
	var shared:=authority.snapshot_shared()
	latest=authority.snapshot(1,shared);snapshot_received.emit(latest)
	for peer in authority.peers:
		if peer==1:continue
		if not peer_snapshot_deltas.has(peer):peer_snapshot_deltas[peer]=SnapshotDelta.new()
		var encoder: RefCounted=peer_snapshot_deltas[peer]
		var value:=authority.snapshot(peer,shared)
		var parts:=FrontierCrewSnapshotTransport.fragments_raw(encoder.encode(value))
		if parts.is_empty():notice.emit("승무원 상태 전송 한도를 초과했습니다.");continue
		encoder.remember(snapshot_serial,value)
		for index in parts.size():
			snapshot_bytes_sent+=parts[index].size();snapshot_largest_fragment=maxi(snapshot_largest_fragment,parts[index].size())
			_snapshot_fragment.rpc_id(peer,session_id,snapshot_serial,index,parts.size(),parts[index])
func _reject_peer(peer: int,message: String) -> void:
	pending_connections.erase(peer)
	if closing_connections.has(peer):return
	_rejected.rpc_id(peer,message)
	closing_connections[peer]=Time.get_ticks_msec()/1000.0+.25
func _rate_allowed(peer: int) -> bool:
	var now:=Time.get_ticks_msec()/1000.0
	if not rate_windows.has(peer) or rate_windows[peer].until<now:rate_windows[peer]={"until":now+1,"count":0}
	rate_windows[peer].count+=1
	return rate_windows[peer].count<=32
@rpc("authority","call_remote","reliable",0)
func _offer(epoch: String,realm: String,protocol: int,content: String) -> void:
	if hosting:return
	if protocol!=int(FrontierCrewWorld.config().protocol) or content!=FrontierCrewWorld.content_hash() or not FrontierPlayerProfile.identifier(epoch) or not FrontierPlayerProfile.identifier(realm):
		notice.emit("호스트의 게임 버전과 현재 버전이 다릅니다.");enet.close();return
	session_id=epoch;world_id=realm;received_serial=-1;received_surface_serial=-1;snapshot_transport.reset();snapshot_delta.reset()
	_hello.rpc_id(1,epoch,protocol,content,profile.data.character,profile.data.sessions.get(realm,""))
@rpc("any_peer","call_remote","reliable",0)
func _hello(epoch: String,protocol: int,content: String,character: Dictionary,capability: String) -> void:
	if not hosting:return
	var peer:=multiplayer.get_remote_sender_id()
	if not pending_connections.has(peer) or epoch!=session_id or not _rate_allowed(peer):return
	if JSON.stringify(character).length()>int(FrontierCrewWorld.config().maximum_message_bytes):_reject_peer(peer,"프로필 크기 초과");return
	var result:=authority.admit(peer,character,capability,protocol,content)
	if not result.ok:_reject_peer(peer,result.error);return
	result.manifest=authority.world.manifest
	_admitted.rpc_id(peer,result)
@rpc("authority","call_remote","reliable",0)
func _admitted(value: Dictionary) -> void:
	if hosting or value.get("session_id")!=session_id or value.get("world_id")!=world_id:return
	if not _valid_snapshot(value.get("snapshot")):notice.emit("초기 세계 상태가 올바르지 않습니다.");enet.close();return
	if not _valid_manifest(value.get("manifest")) or value.manifest.id!=value.snapshot.get("galaxy_id"):notice.emit("은하 생성 정의 오류");enet.close();return
	manifest=value.manifest.duplicate(true)
	if not value.get("token") is String or not profile.remember(world_id,value.token):notice.emit(profile.error);enet.close();return
	latest=value.snapshot;snapshot_received.emit(latest)
	_acknowledge.rpc_id(1,session_id)
@rpc("any_peer","call_remote","reliable",0)
func _acknowledge(epoch: String) -> void:
	if not hosting:return
	var peer:=multiplayer.get_remote_sender_id()
	var result:=authority.acknowledge(peer,epoch)
	if not result.ok:_reject_peer(peer,result.error);return
	pending_connections.erase(peer);surface_digests.erase(peer);_publish();_publish_surface()
func _valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.get("phase") not in ["lobby","playing"] or not value.get("lobby_ready") is Dictionary or value.get("session_id")!=session_id or not value.get("crew") is Dictionary or not value.crew.has("navigation"):return false
	if not value.get("self_id") is String or not value.crew.get("members") is Dictionary or not value.crew.members.has(value.self_id) or not value.get("active") is bool:return false
	if not value.get("vessel") is Dictionary or not value.get("vessel_seed") is int:return false
	if not value.vessel.is_empty() and not FrontierVesselRefit.validate(value.vessel,value.vessel_seed,world_id).is_empty():return false
	if not value.get("vessel_stats") is Dictionary:return false
	if value.vessel_stats.has("stellar_range") and not FrontierUniverse._finite(value.vessel_stats.stellar_range,0,1000):return false
	for key in ["mass","power","speed","research_speed","hangar"]:
		if not FrontierUniverse._finite(value.vessel_stats.get(key),0,100):return false
	if not value.get("motion",{}) is Dictionary or not FrontierUniverse._finite(value.get("motion_time",0),0,9007199254740000):return false
	for motion in value.get("motion",{}).values():
		if not FrontierCrewLocomotion.valid(motion):return false
	var crew: Dictionary=value.crew.duplicate(true);crew.receipts={}
	for id in crew.members:
		if not crew.members[id] is Dictionary:return false
		crew.members[id].capability_hash="0".repeat(64)
	return crew.get("world_id")==world_id and FrontierCrewWorld.validate(crew).is_empty()
@rpc("authority","call_remote","unreliable",2)
func _snapshot_fragment(epoch: String,serial: int,index: int,count: int,data: PackedByteArray) -> void:
	if hosting or epoch!=session_id:return
	var value:=snapshot_transport.accept(serial,index,count,data,Time.get_ticks_msec())
	if not value.is_empty() and _snapshot(serial,snapshot_delta.decode(value)):_snapshot_ack.rpc_id(1,session_id,serial)
func _snapshot(serial: int,value: Dictionary) -> bool:
	if hosting or serial<=received_serial or not _valid_snapshot(value):return false
	snapshot_delta.remember(serial,value)
	received_serial=serial;latest=value;active=value.active
	next_sequence=maxi(next_sequence,int(value.crew.members[value.self_id].last_sequence)+1)
	snapshot_received.emit(value)
	return true
@rpc("any_peer","call_remote","unreliable",2)
func _snapshot_ack(epoch: String,serial: int) -> void:
	if not hosting or epoch!=session_id:return
	var peer:=multiplayer.get_remote_sender_id()
	if authority.peers.has(peer) and peer_snapshot_deltas.has(peer):peer_snapshot_deltas[peer].acknowledge(serial)
@rpc("authority","call_remote","reliable",0)
func _rejected(message: String) -> void:
	active=false;notice.emit(message)
func mining_ready() -> bool:
	return mine_sequence==0 and Time.get_ticks_msec()>=mine_ready_at and not latest.is_empty() and int(latest.crew.revision)>=mine_revision
func send_request(kind: String,args: Dictionary) -> bool:
	if not active or latest.is_empty():notice.emit("참가 동기화가 끝난 뒤 실행하세요.");return false
	if local_request_guard.is_valid():
		var reason: String=local_request_guard.call(kind,args)
		if not reason.is_empty():notice.emit(reason);return false
	if kind=="business_mine":
		if not mining_ready():return false
		mine_sequence=next_sequence
	var request: Dictionary={"session_id":session_id,"sequence":next_sequence,"kind":kind,"args":args,"revision":latest.crew.revision}
	next_sequence+=1
	request_started.emit(int(request.sequence),kind,args)
	if hosting:
		authority.now=Time.get_ticks_msec()/1000.0
		var result:=authority.request(1,request);_complete_request(int(request.sequence),result)
		if kind not in ["surface_fire","surface_reload","surface_stance"]:_publish();_publish_surface()
	else:_request.rpc_id(1,request)
	return true
@rpc("any_peer","call_remote","reliable",0)
func _request(value: Dictionary) -> void:
	if not hosting:return
	var peer:=multiplayer.get_remote_sender_id()
	if not _rate_allowed(peer):return
	authority.now=Time.get_ticks_msec()/1000.0
	var result:=authority.request(peer,value)
	_response.rpc_id(peer,int(value.sequence) if FrontierUniverse._finite(value.get("sequence"),1,9007199254740000) else 0,result)
	if value.get("kind","") not in ["surface_fire","surface_reload","surface_stance"]:_publish();_publish_surface()
@rpc("authority","call_remote","reliable",0)
func _response(sequence: int,value: Dictionary) -> void:
	if not hosting:_complete_request(sequence,value)
func _complete_request(sequence: int,value: Dictionary) -> void:
	if sequence==mine_sequence:
		mine_sequence=0
		var interval:=float(FrontierEquipment.active(latest.crew.members[latest.self_id]).get("interval",.6))
		mine_ready_at=Time.get_ticks_msec()+int(ceil(float(value.get("retry_after",interval))*1000))+20
		mine_revision=int(value.get("revision",0))
	response_received.emit(sequence,value)
func send_input(direction: Vector2,aim: Vector3=Vector3.FORWARD,scanning: bool=false,sprinting: bool=false,flight_controls: Array=[0.0,0.0,0.0],jump_request: int=0,controls_enabled: bool=true,vehicle_controls: Array=[],weather_ready: bool=false) -> void:
	if not active:return
	movement_sequence+=1
	if hosting:authority.input(1,movement_sequence,[direction.x,direction.y],[aim.x,aim.y,aim.z],scanning,sprinting,flight_controls,jump_request,controls_enabled,vehicle_controls,weather_ready)
	else:_movement.rpc_id(1,session_id,movement_sequence,[direction.x,direction.y],[aim.x,aim.y,aim.z],scanning,sprinting,flight_controls,jump_request,controls_enabled,vehicle_controls,weather_ready)
@rpc("any_peer","call_remote","unreliable_ordered",1)
func _movement(epoch: String,sequence: int,direction: Array,aim: Array=[],scanning: bool=false,sprinting: bool=false,flight_controls: Array=[0.0,0.0,0.0],jump_request: int=0,controls_enabled: bool=true,vehicle_controls: Array=[],weather_ready: bool=false) -> void:
	if hosting and epoch==session_id:authority.input(multiplayer.get_remote_sender_id(),sequence,direction,aim,scanning,sprinting,flight_controls,jump_request,controls_enabled,vehicle_controls,weather_ready)
func kick(character_id: String) -> bool:
	if not hosting or character_id==authority.world.crew.owner_id:return false
	for peer in authority.peers.keys():
		if authority.peers[peer]==character_id:
			if not authority.disconnect_member(peer,false):notice.emit(authority.error);return false
			_reject_peer(peer,"호스트가 세션 참가를 종료했습니다.");_publish();return true
	return false
@rpc("any_peer","call_remote","reliable",0)
func _leave() -> void:
	if hosting:
		var peer:=multiplayer.get_remote_sender_id()
		if authority.disconnect_member(peer,false):_reject_peer(peer,"원정을 나갔습니다.")
func close_session() -> bool:
	if closing:return false
	closing=true
	if relay_pending!=null:relay_pending.close();relay_pending=null
	connecting=false
	if hosting:
		if not authority.close():closing=false;notice.emit(authority.error);return false
		if not offline and enet!=null and enet.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:_closed.rpc("호스트가 세계를 저장하고 종료했습니다.")
	elif enet!=null and enet.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:_leave.rpc_id(1)
	active=false;mine_sequence=0;mine_ready_at=0;mine_revision=0
	if enet!=null:
		var closing_peer:=enet
		await get_tree().create_timer(.25).timeout
		closing_peer.close()
		if enet==closing_peer:enet=null
	hosting=false;offline=false;closing=false;invite_code="";latest={};surface={}
	pending_connections.clear();closing_connections.clear();rate_windows.clear();surface_digests.clear()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	return true
@rpc("authority","call_remote","reliable",0)
func _closed(message: String) -> void:
	active=false;notice.emit(message)
func _exit_tree() -> void:
	if relay_pending!=null:relay_pending.close();relay_pending=null
	if store!=null:store.finish_pending()
	if hosting and authority!=null and not authority.stopped:authority.close()
	if enet!=null:enet.close()

func _physics_process(delta: float) -> void:
	if not hosting or not active or authority.stopped or authority.phase!="playing":return
	if not store.poll_checkpoint():
		authority.stopped=true;authority.error="체크포인트 저장 실패: "+store.last_error
	else:authority.step_surface(minf(delta,.1))
	if authority.stopped:
		active=false;notice.emit(authority.error)
		if not offline:_closed.rpc(authority.error)
		return
	var controls: Array=[0.0,0.0,0.0]
	for peer in authority.peers:
		if authority.peers[peer]==authority.world.crew.pilot_id and authority.inputs.has(peer) and authority.inputs[peer].expires>=authority.now:
			controls=authority.inputs[peer].get("flight_controls",controls)
	FrontierCrewNavigation.steer(authority.world,controls,minf(delta,.1))
	var opening_wait: bool=FrontierSolarOpening.active(authority.world.crew.navigation) and (get_tree().has_meta("startup_loader") or (get_parent() is FrontierCrewExpedition and (get_parent().preparing_first_snapshot or (offline and (get_parent().any_menu_open() or not get_window().has_focus())))))
	var arrived:=false
	if not opening_wait:arrived=FrontierCrewNavigation.step(authority.world,minf(delta,.1))
	for peer in authority.peers:
		var actor: String=authority.peers[peer]
		if not FrontierShuttles.aboard(authority.world,actor):continue
		var local:=FrontierShuttles.context(authority.world,actor)
		var input: Dictionary=authority.inputs.get(peer,{})
		var local_controls: Array=input.get("flight_controls",[0.0,0.0,0.0]) if float(input.get("expires",-1))>=authority.now else [0.0,0.0,0.0]
		if FrontierSpaceTraffic.enabled(authority.world.manifest):local.crew.navigation.orbit_time=float(authority.world.crew.navigation.orbit_time)-minf(delta,.1)
		FrontierCrewNavigation.steer(local,local_controls,minf(delta,.1))
		if FrontierCrewNavigation.step(local,minf(delta,.1)):arrived=true
		FrontierShuttles.commit(authority.world,local,actor)
	if FrontierSpaceTraffic.enabled(authority.world.manifest):
		var interests:=FrontierSpaceTraffic.observers(authority.world)
		authority.world.crew.navigation.traffic_observers=interests
		for craft in FrontierShuttles.fleet(authority.world).values():craft.navigation.traffic_observers=interests
		FrontierSpacePatrol.step(authority.world)
	checkpoint_timer-=delta
	if arrived or checkpoint_timer<=0:
		checkpoint_timer=5.0
		if not (authority.checkpoint() if arrived else store.begin_checkpoint(authority.world)):
			authority.stopped=true;authority.error="항해 상태 저장 실패: "+store.last_error
			active=false;notice.emit(authority.error)
			if not offline:_closed.rpc(authority.error)

func _valid_manifest(value: Variant) -> bool:
	if not value is Dictionary or not FrontierUniverse._finite(value.get("seed"),0,2147483647):return false
	if value.seed!=floorf(value.seed):return false
	var settings: Dictionary=FrontierUniverse.config()
	if value.get("settings",{}).get("generator_version")=="galaxy-v2":settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/galaxy-v2.json"))
	if not value.get("settings",{}).has("underground_rules"):settings.erase("underground_rules")
	if not value.get("settings",{}).has("planetary_cycles"):settings.erase("planetary_cycles")
	else:
		if not FrontierPlanetaryCycles.valid(value.settings.planetary_cycles):return false
		settings.planetary_cycles=value.settings.planetary_cycles.duplicate(true)
	# Saved corporate rules are immutable, including worlds created before traffic.
	if value.settings.has("corporate_space"):
		settings.corporate_space=value.settings.corporate_space.duplicate(true)
	else:settings.erase("corporate_space")
	return FrontierUniverse.fingerprint(value)==FrontierUniverse.fingerprint(FrontierUniverse.generate(int(value.seed),settings))

func _publish_surface() -> void:
	if not hosting or authority==null or authority.stopped or authority.phase!="playing":return
	for peer in authority.peers:
		var local:=FrontierShuttles.context(authority.world,authority.peers[peer])
		var value:=FrontierCrewSurfaceReplica.packet(local,authority.peers[peer])
		if value.is_empty():
			if peer==1:surface={}
			surface_digests.erase(peer);continue
		if authority.water_solvers.has(value.body_id):
			value.water_columns=authority.water_solvers[value.body_id].columns_packet(FrontierCrewWorld.vector(local.crew.members[authority.peers[peer]].position))
		var digest:=FrontierUniverse.fingerprint(value)
		if surface_digests.get(peer,"")==digest:continue
		surface_serial+=1
		if peer==1:surface=value;surface_received.emit(value)
		else:
			var encoded:=FrontierCrewSurfaceReplica.encode(value)
			if encoded.is_empty():notice.emit("지표 기록 전송 한도를 확인해야 합니다.");continue
			surface_bytes_sent+=encoded.size()
			_surface_state.rpc_id(peer,session_id,surface_serial,encoded)
		surface_digests[peer]=digest

@rpc("authority","call_remote","reliable",3)
func _surface_state(epoch: String,serial: int,data: PackedByteArray) -> void:
	if hosting or epoch!=session_id or serial<=received_surface_serial or manifest.is_empty():return
	var value:=FrontierCrewSurfaceReplica.decode(data,manifest)
	if value.is_empty():notice.emit("공동 지표 기록이 손상되어 적용하지 않았습니다.");return
	received_surface_serial=serial;surface=value;surface_received.emit(value)

# A requested page travels once on the reliable channel, outside movement/surface snapshots.
func request_discoveries(serial: int,query: String,kind: String,body_id: String,page_index: int) -> void:
	if not active:return
	if hosting:discoveries_received.emit(serial,FrontierDiscoveryIndex.page(authority.world,query,kind,body_id,page_index))
	else:_discoveries_request.rpc_id(1,session_id,serial,query,kind,body_id,page_index)
@rpc("any_peer","call_remote","reliable",0)
func _discoveries_request(epoch: String,serial: int,query: String,kind: String,body_id: String,page_index: int) -> void:
	if not hosting or epoch!=session_id:return
	var peer:=multiplayer.get_remote_sender_id()
	if not authority.peers.has(peer) or not _rate_allowed(peer):return
	if query.length()>100 or kind not in ["all","mineral","biology","discovery","incident","corporation","weather"] or page_index<0:return
	if not body_id.is_empty() and FrontierUniverse.ordinal_of(manifest,body_id)<0:return
	_discoveries_page.rpc_id(peer,epoch,serial,FrontierDiscoveryIndex.page(authority.world,query,kind,body_id,page_index))
@rpc("authority","call_remote","reliable",0)
func _discoveries_page(epoch: String,serial: int,value: Dictionary) -> void:
	if hosting or not active or epoch!=session_id:return
	if not value.get("entries") is Array or value.entries.size()>FrontierDiscoveryIndex.PAGE_SIZE:return
	discoveries_received.emit(serial,value)
