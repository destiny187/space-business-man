class_name FrontierCrewLocalRelay
extends Node
## In-game implementation of the same protocol as services/crew-relay/server.py.
## The host game process owns this directory/relay; it is not a world simulator.
const MAX_PACKET:=65536
const MAX_BUFFER:=2*1024*1024
const MAX_ROOMS:=64
const ALPHABET:="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
var listener:=TCPServer.new()
var clients: Dictionary={}
var rooms: Dictionary={}
var closing_sockets: Array[Dictionary]=[]
var next_client:=1
var port:=24680

static func ensure_for(tree: SceneTree,url: String) -> void:
	# Only a local ws endpoint can be started automatically. Never turn a failed
	# remote / wss connection into a different local room silently.
	if not url.begins_with("ws://"):return
	var endpoint:=url.substr(5).get_slice("/",0)
	var hostname:=endpoint.get_slice(":",0)
	if hostname not in ["127.0.0.1","localhost"]:return
	var value:=endpoint.get_slice(":",1)
	if not value.is_valid_int():return
	var local_port:=int(value)
	if local_port<1024 or local_port>65535:return
	var meta:="crew_local_relay_"+str(local_port)
	if tree.has_meta(meta):return
	var service:=FrontierCrewLocalRelay.new();service.port=local_port
	# Bind LAN as well: another machine can use this host's LAN IP. Internet
	# reachability still requires router/firewall configuration.
	if service.listener.listen(local_port,"*")!=OK:
		service.free();return # An already-running native / Docker relay can own it.
	service.name="LocalCrewRelay"+str(local_port)
	tree.root.add_child(service);tree.set_meta(meta,service)

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()
	while listener.is_connection_available():
		var stream:=listener.take_connection()
		if clients.size()>=MAX_ROOMS*6+32:stream.disconnect_from_host();continue
		var socket:=WebSocketPeer.new();socket.inbound_buffer_size=MAX_BUFFER;socket.outbound_buffer_size=MAX_BUFFER;socket.max_queued_packets=2048
		if socket.accept_stream(stream)!=OK:continue
		clients[next_client]={"socket":socket,"since":now,"room":"","peer":0,"ready":false,"window":now,"bytes":0,"count":0};next_client+=1
	for key in clients.keys():
		if not clients.has(key):continue
		var client: Dictionary=clients[key]
		var socket: WebSocketPeer=client.socket;socket.poll()
		if socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:_disconnect(key,"connection_closed");continue
		if int(client.peer)==0 and now-int(client.since)>8000:_disconnect(key,"handshake_timeout");continue
		if socket.get_ready_state()!=WebSocketPeer.STATE_OPEN:continue
		if now-int(client.window)>=1000:client.window=now;client.bytes=0;client.count=0
		var received:=0
		while clients.has(key) and socket.get_available_packet_count()>0 and received<2048:
			received+=1
			var packet:=socket.get_packet();client.bytes+=packet.size();client.count+=1
			if int(client.bytes)>8*1024*1024 or int(client.count)>12000:_disconnect(key,"rate_limit");break
			if socket.was_string_packet():
				if packet.size()>512:_disconnect(key,"invalid_request");break
				var request: Variant=JSON.parse_string(packet.get_string_from_utf8())
				if not request is Dictionary:_disconnect(key,"invalid_request");break
				if int(client.peer)==0:_admit(key,request)
				else:_control(key,request)
			else:_forward(key,packet)
	for index in range(closing_sockets.size()-1,-1,-1):
		var entry: Dictionary=closing_sockets[index];entry.socket.poll()
		if entry.socket.get_ready_state()==WebSocketPeer.STATE_CLOSED or now-int(entry.since)>1000:closing_sockets.remove_at(index)

func _admit(key: int,request: Dictionary) -> void:
	if request.get("protocol")!=1:_reject(key,"protocol_mismatch");return
	var code:=""
	var peer:=1
	if request.get("op")=="create":
		if rooms.size()>=MAX_ROOMS:_reject(key,"server_full");return
		code=_code()
		rooms[code]={"clients":{},"next_peer":2,"ready":false,"refusing":false}
	elif request.get("op")=="join":
		if not request.get("code") is String:_reject(key,"room_unavailable");return
		code=request.code
		if not rooms.has(code) or not rooms[code].ready or rooms[code].refusing:_reject(key,"room_unavailable");return
		if rooms[code].clients.size()>=6:_reject(key,"room_full");return
		peer=int(rooms[code].next_peer);rooms[code].next_peer+=1
	else:_reject(key,"invalid_request");return
	clients[key].room=code;clients[key].peer=peer;rooms[code].clients[peer]=key
	_event(key,{"op":"welcome","peer":peer,"code":code,"protocol":1})

func _control(key: int,message: Dictionary) -> void:
	var client: Dictionary=clients[key]
	if not rooms.has(client.room):_disconnect(key,"host_left");return
	var room: Dictionary=rooms[client.room]
	match message.get("op",""):
		"ready":
			if client.ready:_disconnect(key,"invalid_request");return
			client.ready=true
			if int(client.peer)==1:room.ready=true
			else:
				_event(int(room.clients[1]),{"op":"peer_joined","peer":client.peer})
				_event(key,{"op":"peer_joined","peer":1})
		"kick":
			if int(client.peer)!=1:_disconnect(key,"invalid_request");return
			if not (message.get("peer") is float or message.get("peer") is int):_disconnect(key,"invalid_request");return
			var target:=int(message.peer)
			if target!=1 and room.clients.has(target):_disconnect(int(room.clients[target]),"removed")
		"refuse":
			if int(client.peer)!=1:_disconnect(key,"invalid_request");return
			room.refusing=bool(message.get("value",false))
		_:_disconnect(key,"invalid_request")

func _forward(key: int,packet: PackedByteArray) -> void:
	var client: Dictionary=clients[key]
	if not client.ready or packet.size()<=6 or packet.size()>MAX_PACKET+6 or packet[4]>3 or packet[5]>2:
		_disconnect(key,"invalid_packet");return
	if not rooms.has(client.room):_disconnect(key,"host_left");return
	var room: Dictionary=rooms[client.room]
	var target:=packet.decode_s32(0)
	packet.encode_s32(0,int(client.peer))
	if int(client.peer)!=1:
		if target not in [0,1]:_disconnect(key,"invalid_target");return
		if room.clients.has(1):_send(int(room.clients[1]),packet)
	else:
		var destinations: Array[int]=[]
		for peer in room.clients.keys():
			if peer!=1 and (target==0 or peer==target or (target<0 and peer!=-target)):destinations.append(int(room.clients[peer]))
		for destination in destinations:_send(destination,packet)

func _send(key: int,packet: PackedByteArray) -> void:
	if not clients.has(key):return
	var socket: WebSocketPeer=clients[key].socket
	if socket.get_current_outbound_buffered_amount()+packet.size()>MAX_BUFFER or socket.put_packet(packet)!=OK:_disconnect(key,"slow_receiver")

func _event(key: int,value: Dictionary) -> void:
	if not clients.has(key):return
	var socket: WebSocketPeer=clients[key].socket
	if socket.send_text(JSON.stringify(value))!=OK:_disconnect(key,"slow_receiver")

func _reject(key: int,reason: String) -> void:
	_event(key,{"op":"error","reason":reason});_disconnect(key,reason)

func _disconnect(key: int,reason: String) -> void:
	if not clients.has(key):return
	var client: Dictionary=clients[key];clients.erase(key)
	var socket: WebSocketPeer=client.socket
	socket.close(1000,reason);socket.poll();closing_sockets.append({"socket":socket,"since":Time.get_ticks_msec()})
	if not rooms.has(client.room):return
	var room: Dictionary=rooms[client.room];room.clients.erase(client.peer)
	if int(client.peer)==1:
		rooms.erase(client.room)
		for guest in room.clients.values():_disconnect(int(guest),"host_left")
	elif room.clients.has(1):_event(int(room.clients[1]),{"op":"peer_left","peer":client.peer})

func _code() -> String:
	while true:
		var bytes:=Crypto.new().generate_random_bytes(12)
		var value:=""
		for byte in bytes:value+=ALPHABET[int(byte)%ALPHABET.length()]
		if not rooms.has(value):return value
	return ""

func _exit_tree() -> void:
	listener.stop()
	for client in clients.values():client.socket.close();client.socket.poll()
