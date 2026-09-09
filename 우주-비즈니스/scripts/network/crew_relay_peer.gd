class_name FrontierCrewRelayPeer
extends MultiplayerPeerExtension
## Development transport. All frames use WebSocket/TCP, even when the RPC mode
## requests unreliable delivery. A production platform peer can replace this
## MultiplayerPeer without changing crew authority or world persistence.
signal failed(reason: String)
const MAX_PACKET:=65536
const MAX_BUFFER:=2*1024*1024
var socket:=WebSocketPeer.new()
var room_code:=""
var error:=""
var identity:=0
var host_side:=false
var state: MultiplayerPeer.ConnectionStatus=MultiplayerPeer.CONNECTION_DISCONNECTED
var target:=0
var channel:=0
var mode: MultiplayerPeer.TransferMode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
var refusing:=false
var announced:=false
var peers: Dictionary={}
var packets: Array[PackedByteArray]=[]
var packet_bytes:=0

func open(tree: SceneTree,url: String,create: bool,code: String="") -> bool:
	host_side=create
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		error="중계 주소는 ws:// 또는 wss://로 시작해야 합니다.";return false
	socket.inbound_buffer_size=MAX_BUFFER;socket.outbound_buffer_size=MAX_BUFFER
	socket.max_queued_packets=2048
	state=MultiplayerPeer.CONNECTION_CONNECTING
	if socket.connect_to_url(url)!=OK:error="중계 서버 주소를 확인하세요.";_close();return false
	var deadline:=Time.get_ticks_msec()+8000
	var sent:=false
	while Time.get_ticks_msec()<deadline and state==MultiplayerPeer.CONNECTION_CONNECTING:
		socket.poll()
		if socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:
			error=_reason(socket.get_close_reason()) if not socket.get_close_reason().is_empty() else "중계 서버에 연결하지 못했습니다. 서버 실행과 주소를 확인하세요.";_close();return false
		if socket.get_ready_state()==WebSocketPeer.STATE_OPEN:
			if not sent:
				socket.send_text(JSON.stringify({"op":"create" if create else "join","protocol":1,"code":code.to_upper().replace("-","").replace(" ","")}));sent=true
			if socket.get_available_packet_count()>0:
				var packet:=socket.get_packet()
				var message: Variant=JSON.parse_string(packet.get_string_from_utf8()) if socket.was_string_packet() else null
				if message is Dictionary and message.get("op")=="welcome" and int(message.get("protocol",0))==1:
					identity=int(message.get("peer",0));room_code=str(message.get("code",""))
					if (create and identity==1) or (not create and identity>1):
						state=MultiplayerPeer.CONNECTION_CONNECTED;return true
				error=_reason(str(message.get("reason","invalid_request"))) if message is Dictionary else "중계 응답 형식 오류입니다."
				_close();return false
		await tree.process_frame
	if error.is_empty():error="중계 서버의 응답 시간이 초과됐습니다."
	_close();return false

static func _reason(reason: String) -> String:
	return {"room_unavailable":"초대 코드가 없거나 방이 종료됐습니다.","room_full":"호스트 포함 최대 6명입니다.","server_full":"중계 서버가 가득 찼습니다.","protocol_mismatch":"중계 서버와 게임의 버전이 다릅니다.","host_left":"호스트가 방을 닫았습니다.","removed":"호스트가 접속을 종료했습니다.","slow_receiver":"수신이 지연되어 연결을 종료했습니다.","rate_limit":"중계 전송 한도를 초과했습니다."}.get(reason,"중계 연결이 종료됐습니다. 서버와 네트워크를 확인하세요.")

func _poll() -> void:
	if state!=MultiplayerPeer.CONNECTION_CONNECTED:return
	socket.poll()
	if socket.get_ready_state()!=WebSocketPeer.STATE_OPEN:
		_lost(_reason(socket.get_close_reason()));return
	if not announced:
		announced=true;socket.send_text('{"op":"ready"}')
	var received:=0
	while socket.get_available_packet_count()>0 and received<2048:
		received+=1
		var packet:=socket.get_packet()
		if socket.was_string_packet():
			var event: Variant=JSON.parse_string(packet.get_string_from_utf8())
			if not event is Dictionary:continue
			var peer:=int(event.get("peer",0))
			if peer<=0 or peer==identity:continue
			if event.get("op")=="peer_joined" and not peers.has(peer):
				peers[peer]=true;peer_connected.emit(peer)
			elif event.get("op")=="peer_left" and peers.has(peer):
				peers.erase(peer);peer_disconnected.emit(peer)
		else:
			if packet.size()<=6 or packet.size()>MAX_PACKET+6 or packet_bytes+packet.size()>MAX_BUFFER:
				_lost("중계 수신 버퍼 한도를 초과했습니다.");return
			if not peers.has(packet.decode_s32(0)):continue
			packets.append(packet);packet_bytes+=packet.size()

func _lost(reason: String) -> void:
	error=reason;_close();failed.emit(reason)

func _close() -> void:
	state=MultiplayerPeer.CONNECTION_DISCONNECTED
	socket.close();packets.clear();packet_bytes=0;peers.clear()

func _disconnect_peer(peer: int,_force: bool) -> void:
	if host_side and peers.has(peer):socket.send_text(JSON.stringify({"op":"kick","peer":peer}))
	elif not host_side and peer==1:_close()

func _get_packet_script() -> PackedByteArray:
	if packets.is_empty():return PackedByteArray()
	var packet: PackedByteArray=packets.pop_front();packet_bytes-=packet.size()
	return packet.slice(6)

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if state!=MultiplayerPeer.CONNECTION_CONNECTED:return ERR_UNCONFIGURED
	if buffer.size()>MAX_PACKET:return ERR_OUT_OF_MEMORY
	if socket.get_current_outbound_buffered_amount()+buffer.size()+6>MAX_BUFFER:
		call_deferred("_lost","중계 송신 버퍼 한도를 초과했습니다.");return ERR_OUT_OF_MEMORY
	var packet:=PackedByteArray();packet.resize(6);packet.encode_s32(0,target);packet[4]=channel;packet[5]=mode;packet.append_array(buffer)
	return socket.put_packet(packet)

func _get_available_packet_count() -> int:return packets.size()
func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:return state
func _get_max_packet_size() -> int:return MAX_PACKET
func _get_packet_channel() -> int:return int(packets[0][4]) if not packets.is_empty() else 0
func _get_packet_mode() -> MultiplayerPeer.TransferMode:return (int(packets[0][5]) as MultiplayerPeer.TransferMode) if not packets.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _get_packet_peer() -> int:return packets[0].decode_s32(0) if not packets.is_empty() else 0
func _get_transfer_channel() -> int:return channel
func _get_transfer_mode() -> MultiplayerPeer.TransferMode:return mode
func _get_unique_id() -> int:return identity
func _is_refusing_new_connections() -> bool:return refusing
func _is_server() -> bool:return host_side
func _is_server_relay_supported() -> bool:return false
func _set_refuse_new_connections(enable: bool) -> void:
	refusing=enable
	if state==MultiplayerPeer.CONNECTION_CONNECTED and host_side:socket.send_text(JSON.stringify({"op":"refuse","value":enable}))
func _set_target_peer(peer: int) -> void:target=peer
func _set_transfer_channel(value: int) -> void:channel=value
func _set_transfer_mode(value: MultiplayerPeer.TransferMode) -> void:mode=value
