class_name FrontierCrewSession
extends Node
signal snapshot_received(value: Dictionary)
signal notice(message: String)
signal surface_received(value: Dictionary)
signal response_received(sequence: int,value: Dictionary)
var authority: FrontierCrewAuthority
var enet: ENetMultiplayerPeer
var profile: FrontierPlayerProfile
var store: FrontierWorldStore
var latest: Dictionary={}
var manifest: Dictionary={}
var checkpoint_timer:=5.0
var session_id:=""
var world_id:=""
var active:=false
var hosting:=false
var next_sequence:=1
var movement_sequence:=0
var snapshot_serial:=0
var received_serial:=-1
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
func host(local_profile: FrontierPlayerProfile,world_store: FrontierWorldStore,port: int=24560,bind_ip: String="*") -> bool:
	if enet!=null:notice.emit("현재 연결을 종료한 뒤 새 방을 열어 주세요.");return false
	profile=local_profile;store=world_store
	if profile.data.is_empty():notice.emit("개인 프로필을 먼저 열어 주세요.");return false
	var state:=store.read_state()
	if state.is_empty():
		if store.has_history():notice.emit(store.last_error);return false
		state=FrontierUniverse.new_world(71491)
	authority=FrontierCrewAuthority.new()
	if not authority.start(state,profile.data.character,store.write):notice.emit(authority.error);return false
	enet=ENetMultiplayerPeer.new();enet.set_bind_ip(bind_ip)
	var result:=enet.create_server(port,11,3)
	if result!=OK:notice.emit("이 UDP 포트로 방을 열 수 없습니다: "+str(result));enet=null;return false
	multiplayer.multiplayer_peer=enet;hosting=true;active=true
	session_id=authority.session_id;world_id=authority.world.crew.world_id;manifest=authority.world.manifest.duplicate(true)
	next_sequence=int(authority.world.crew.members[profile.data.character.character_id].last_sequence)+1
	_publish();notice.emit("호스트 포함 최대 6명의 방을 열었습니다.");return true
func join(local_profile: FrontierPlayerProfile,address: String,port: int=24560) -> bool:
	if enet!=null:notice.emit("현재 연결을 종료한 뒤 다시 참가하세요.");return false
	profile=local_profile
	if profile.data.is_empty():notice.emit("개인 프로필을 먼저 열어 주세요.");return false
	enet=ENetMultiplayerPeer.new()
	var result:=enet.create_client(address,port,3)
	if result!=OK:notice.emit("접속을 시작할 수 없습니다: "+str(result));enet=null;return false
	multiplayer.multiplayer_peer=enet;hosting=false;active=false;received_serial=-1
	notice.emit("호스트에 연결 중입니다.");return true
func _peer_connected(peer: int) -> void:
	if not hosting:return
	pending_connections[peer]=Time.get_ticks_msec()/1000.0+float(FrontierCrewWorld.config().handshake_seconds)
	_offer.rpc_id(peer,session_id,world_id,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
func _peer_disconnected(peer: int) -> void:
	if not hosting:return
	pending_connections.erase(peer);closing_connections.erase(peer);rate_windows.erase(peer);surface_digests.erase(peer)
	if not authority.disconnect_member(peer):
		active=false;notice.emit(authority.error);_closed.rpc(authority.error);return
	_publish()
func _server_disconnected() -> void:
	active=false;latest={};surface={};notice.emit("호스트 연결이 종료됐습니다. 개인 장비 원본은 유지됩니다.")
func _process(delta: float) -> void:
	if not hosting or enet==null or authority.stopped:return
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
	latest=authority.snapshot(1);snapshot_received.emit(latest)
	for peer in authority.peers:
		if peer!=1:_snapshot.rpc_id(peer,snapshot_serial,authority.snapshot(peer))
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
	session_id=epoch;world_id=realm
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
	if not value is Dictionary or value.get("session_id")!=session_id or not value.get("crew") is Dictionary or not value.crew.has("navigation"):return false
	if not value.get("self_id") is String or not value.crew.get("members") is Dictionary or not value.crew.members.has(value.self_id) or not value.get("active") is bool:return false
	if not value.get("vessel") is Dictionary or not value.get("vessel_seed") is int:return false
	if not value.vessel.is_empty() and not FrontierVesselRefit.validate(value.vessel,value.vessel_seed,world_id).is_empty():return false
	if not value.get("vessel_stats") is Dictionary:return false
	for key in ["mass","power","speed","research_speed","hangar"]:
		if not FrontierUniverse._finite(value.vessel_stats.get(key),0,100):return false
	var crew: Dictionary=value.crew.duplicate(true);crew.receipts={}
	for id in crew.members:
		if not crew.members[id] is Dictionary:return false
		crew.members[id].capability_hash="0".repeat(64)
	return crew.get("world_id")==world_id and FrontierCrewWorld.validate(crew).is_empty()
@rpc("authority","call_remote","unreliable_ordered",2)
func _snapshot(serial: int,value: Dictionary) -> void:
	if hosting or serial<=received_serial or not _valid_snapshot(value):return
	received_serial=serial;latest=value;active=value.active
	next_sequence=maxi(next_sequence,int(value.crew.members[value.self_id].last_sequence)+1)
	snapshot_received.emit(value)
@rpc("authority","call_remote","reliable",0)
func _rejected(message: String) -> void:
	active=false;notice.emit(message)
func send_request(kind: String,args: Dictionary) -> bool:
	if not active or latest.is_empty():notice.emit("참가 동기화가 끝난 뒤 실행하세요.");return false
	var request: Dictionary={"session_id":session_id,"sequence":next_sequence,"kind":kind,"args":args,"revision":latest.crew.revision}
	next_sequence+=1
	if hosting:
		var result:=authority.request(1,request);response_received.emit(int(request.sequence),result);_publish();_publish_surface()
	else:_request.rpc_id(1,request)
	return true
@rpc("any_peer","call_remote","reliable",0)
func _request(value: Dictionary) -> void:
	if not hosting:return
	var peer:=multiplayer.get_remote_sender_id()
	if not _rate_allowed(peer):return
	var result:=authority.request(peer,value)
	_response.rpc_id(peer,int(value.sequence) if FrontierUniverse._finite(value.get("sequence"),1,9007199254740000) else 0,result);_publish();_publish_surface()
@rpc("authority","call_remote","reliable",0)
func _response(sequence: int,value: Dictionary) -> void:
	if not hosting:response_received.emit(sequence,value)
func send_input(direction: Vector2,aim: Vector3=Vector3.FORWARD,scanning: bool=false) -> void:
	if not active:return
	movement_sequence+=1
	if hosting:authority.input(1,movement_sequence,[direction.x,direction.y],[aim.x,aim.y,aim.z],scanning)
	else:_movement.rpc_id(1,session_id,movement_sequence,[direction.x,direction.y],[aim.x,aim.y,aim.z],scanning)
@rpc("any_peer","call_remote","unreliable_ordered",1)
func _movement(epoch: String,sequence: int,direction: Array,aim: Array=[],scanning: bool=false) -> void:
	if hosting and epoch==session_id:authority.input(multiplayer.get_remote_sender_id(),sequence,direction,aim,scanning)
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
	active=false
	if enet==null:return true
	if hosting:
		if not authority.close():notice.emit(authority.error);return false
		_closed.rpc("호스트가 세계를 저장하고 종료했습니다.")
	elif enet.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:_leave.rpc_id(1)
	await get_tree().create_timer(.25).timeout
	enet.close();enet=null;hosting=false;latest={};return true
@rpc("authority","call_remote","reliable",0)
func _closed(message: String) -> void:
	active=false;notice.emit(message)
func _exit_tree() -> void:
	if hosting and authority!=null and not authority.stopped:authority.close()
	if enet!=null:enet.close()

func _physics_process(delta: float) -> void:
	if not hosting or not active or authority.stopped:return
	authority.step_surface(minf(delta,.1))
	if authority.stopped:active=false;notice.emit(authority.error);_closed.rpc(authority.error);return
	var arrived:=FrontierCrewNavigation.step(authority.world,minf(delta,.1))
	checkpoint_timer-=delta
	if arrived or checkpoint_timer<=0:
		checkpoint_timer=5.0
		if not authority.checkpoint():active=false;notice.emit(authority.error);_closed.rpc(authority.error)

func _valid_manifest(value: Variant) -> bool:
	if not value is Dictionary or not FrontierUniverse._finite(value.get("seed"),0,2147483647):return false
	if value.seed!=floorf(value.seed):return false
	return FrontierUniverse.fingerprint(value)==FrontierUniverse.fingerprint(FrontierUniverse.generate(int(value.seed)))

func _publish_surface() -> void:
	if not hosting or authority==null or authority.stopped:return
	if not FrontierCrewSurface.landed(authority.world):
		surface={};surface_digests.clear();return
	for peer in authority.peers:
		var value:=FrontierCrewSurfaceReplica.packet(authority.world,authority.peers[peer])
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

@rpc("authority","call_remote","reliable",0)
func _surface_state(epoch: String,serial: int,data: PackedByteArray) -> void:
	if hosting or epoch!=session_id or serial<=received_surface_serial or manifest.is_empty():return
	var value:=FrontierCrewSurfaceReplica.decode(data,manifest)
	if value.is_empty():notice.emit("공동 지표 기록이 손상되어 적용하지 않았습니다.");return
	received_surface_serial=serial;surface=value;surface_received.emit(value)
