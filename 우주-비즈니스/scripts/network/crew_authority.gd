class_name FrontierCrewAuthority
extends RefCounted
## Host-only admission, immutable profile references and durable transactions.
var world: Dictionary={}
var peers: Dictionary={}
var pending: Dictionary={}
var reserved: Dictionary={}
var inputs: Dictionary={}
var input_sequences: Dictionary={}
var session_id: String
var save_world: Callable
var stopped:=false
var error:=""
var now:=0.0
func start(source: Dictionary,profile: Dictionary,persist: Callable) -> bool:
	error=FrontierPlayerProfile.validate_character(profile)
	if not error.is_empty():return false
	world=source.duplicate(true);save_world=persist
	if not world.has("crew"):world.crew=FrontierCrewWorld.create(profile)
	if not world.crew.has("navigation"):world.crew.navigation=FrontierCrewNavigation.create(world)
	if world.crew.owner_id!=profile.character_id:error="이 세계를 만든 호스트의 개인 프로필이 필요합니다.";return false
	error=FrontierCrewWorld.validate(world.crew)
	if not error.is_empty():return false
	for id in world.crew.members:FrontierCrewWorld.disconnect_member(world.crew,id)
	world.crew.members[profile.character_id].position=FrontierCrewWorld.config().spawn_positions[0].duplicate()
	world.crew.members[profile.character_id].area="cabin"
	world.crew.members[profile.character_id].aboard=true
	world.crew.pilot_id=world.crew.owner_id
	world.crew.members[profile.character_id].profile=profile.duplicate(true)
	if not save_world.call(world):error="호스트 세계를 저장할 수 없습니다.";return false
	session_id=FrontierPlayerProfile.token();peers={1:profile.character_id};pending.clear();reserved.clear();stopped=false
	return true
func advance_time(time_seconds: float) -> Array[int]:
	now=time_seconds
	var expired: Array[int]=[]
	for peer in pending.keys():
		if pending[peer].expires<=now:_drop_pending(peer);expired.append(peer)
	for id in reserved.keys():
		if reserved[id]<=now:reserved.erase(id)
	return expired
func _drop_pending(peer: int) -> void:
	if not pending.has(peer):return
	var entry: Dictionary=pending[peer]
	if float(entry.reserved_until)>now:reserved[entry.profile.character_id]=entry.reserved_until
	pending.erase(peer)
func slots() -> int:return peers.size()+pending.size()+reserved.size()
func admit(peer: int,profile: Variant,capability: String,protocol: int,content: String) -> Dictionary:
	if stopped or peer<=1:return failure("세션이 닫혔습니다.")
	if peers.has(peer) or pending.has(peer):return failure("이미 참가 처리 중입니다.")
	if protocol!=int(FrontierCrewWorld.config().protocol) or content!=FrontierCrewWorld.content_hash():return failure("게임/생성/장비 버전이 호스트와 다릅니다.")
	var reason:=FrontierPlayerProfile.validate_character(profile)
	if not reason.is_empty():return failure(reason)
	var id: String=profile.character_id
	if id==world.crew.owner_id or id in peers.values():return failure("같은 캐릭터가 이미 접속해 있습니다.")
	for entry in pending.values():
		if entry.profile.character_id==id:return failure("같은 캐릭터가 참가 처리 중입니다.")
	var known: bool=world.crew.members.has(id)
	if known and (not FrontierPlayerProfile.identifier(capability,64) or capability.sha256_text()!=world.crew.members[id].capability_hash):return failure("이 캐릭터의 재접속 자격을 확인할 수 없습니다.")
	var reclaiming: bool=reserved.has(id)
	if slots()-(1 if reclaiming else 0)>=int(FrontierCrewWorld.config().maximum_players):return failure("호스트 포함 최대 6명입니다.")
	var token: String=capability if known else FrontierPlayerProfile.token(32)
	var reserved_until: float=float(reserved.get(id,0))
	if reclaiming:reserved.erase(id)
	pending[peer]={"profile":profile.duplicate(true),"token":token,"known":known,"reserved_until":reserved_until,"expires":now+float(FrontierCrewWorld.config().handshake_seconds)}
	return {"ok":true,"world_id":world.crew.world_id,"token":token,"session_id":session_id,"snapshot":snapshot(peer)}
func acknowledge(peer: int,received_session: String) -> Dictionary:
	if stopped or received_session!=session_id or not pending.has(peer):return failure("유효한 참가 준비 응답이 아닙니다.")
	var entry: Dictionary=pending[peer]
	var draft:=world.duplicate(true)
	var id: String=entry.profile.character_id
	if not draft.crew.members.has(id):draft.crew.members[id]=FrontierCrewWorld.member(entry.profile,entry.token.sha256_text(),peers.size())
	else:
		# Equipment stays a reference to the owner's profile. World cargo never
		# gets written into the owner's equipment list.
		draft.crew.members[id].profile=entry.profile.duplicate(true)
		draft.crew.members[id].position=FrontierCrewWorld.config().spawn_positions[peers.size()%6].duplicate()
		draft.crew.members[id].area="cabin";draft.crew.members[id].aboard=true;draft.crew.members[id].ready=false
	draft.crew.revision+=1
	if not save_world.call(draft):return failure("참가 상태 저장에 실패했습니다.")
	world=draft;peers[peer]=id;pending.erase(peer)
	return {"ok":true,"snapshot":snapshot(peer)}
func snapshot(viewer: int=1) -> Dictionary:
	var data: Dictionary=world.crew.duplicate(true)
	var visible: Dictionary=peers.duplicate()
	if pending.has(viewer):
		var entry: Dictionary=pending[viewer];var id: String=entry.profile.character_id
		if not data.members.has(id):data.members[id]=FrontierCrewWorld.member(entry.profile,"",peers.size())
		visible[viewer]=id
	for id in data.members.keys():
		if id not in visible.values():data.members.erase(id)
	return {"session_id":session_id,"crew":FrontierCrewWorld.public_snapshot(data,peers),"self_id":visible.get(viewer,""),"active":peers.has(viewer),"galaxy_id":world.manifest.id,"location":world.location}
func request(peer: int,envelope: Variant) -> Dictionary:
	if stopped or not peers.has(peer):return failure("참가 동기화가 끝나지 않았습니다.")
	if not envelope is Dictionary or envelope.get("session_id")!=session_id:return failure("지난 세션의 요청입니다.")
	if not envelope.get("kind") is String or not envelope.get("args") is Dictionary:return failure("요청 형식 오류")
	if JSON.stringify(envelope).length()>int(FrontierCrewWorld.config().maximum_message_bytes):return failure("요청 크기 초과")
	if not FrontierUniverse._finite(envelope.get("sequence"),1,9007199254740000) or envelope.sequence!=floorf(envelope.sequence):return failure("요청 순번 오류")
	var actor: String=peers[peer]
	var sequence:=int(envelope.sequence)
	var key: String=actor+":"+str(sequence)
	var digest:=JSON.stringify({"kind":envelope.kind,"args":envelope.args,"revision":envelope.get("revision")},"",true).sha256_text()
	if world.crew.receipts.has(key):
		var receipt: Dictionary=world.crew.receipts[key]
		return receipt.result.duplicate(true) if receipt.digest==digest else failure("같은 요청 번호의 내용이 달라졌습니다.")
	if sequence<=int(world.crew.members[actor].last_sequence):return failure("이미 확정된 오래된 요청입니다.")
	if envelope.kind in ["withdraw","deposit","recover","pilot","navigate","depart"] and envelope.get("revision")!=world.crew.revision:return failure("세계 상태가 바뀌었습니다. 최신 상태에서 다시 요청하세요.")
	var draft:=world.duplicate(true)
	var reason:=FrontierCrewNavigation.apply(draft,actor,envelope.kind,envelope.args,peers) if envelope.kind in ["navigate","depart"] else FrontierCrewWorld.apply(draft.crew,actor,envelope.kind,envelope.args,peers)
	if not reason.is_empty():return failure(reason)
	draft.crew.revision+=1;draft.crew.members[actor].last_sequence=sequence
	var result: Dictionary={"ok":true,"sequence":sequence,"revision":draft.crew.revision}
	draft.crew.receipts[key]={"digest":digest,"result":result.duplicate()}
	if draft.crew.receipts.size()>128:
		var oldest: String="";var revision:=INF
		for id in draft.crew.receipts:
			if float(draft.crew.receipts[id].result.revision)<revision:revision=float(draft.crew.receipts[id].result.revision);oldest=id
		draft.crew.receipts.erase(oldest)
	if not save_world.call(draft):return failure("저장에 실패했습니다. 변경은 확정되지 않았습니다.")
	world=draft
	return result
func input(peer: int,sequence: int,direction: Variant) -> bool:
	if stopped or not peers.has(peer) or sequence<=int(input_sequences.get(peer,0)) or not direction is Array or direction.size()!=2:return false
	for axis in direction:
		if not FrontierUniverse._finite(axis,-1,1):return false
	input_sequences[peer]=sequence;inputs[peer]={"direction":Vector2(direction[0],direction[1]).limit_length(),"expires":now+.35}
	return true
func direction_for(peer: int) -> Vector2:
	if not inputs.has(peer) or inputs[peer].expires<now:return Vector2.ZERO
	return inputs[peer].direction
func update_position(peer: int,position: Vector3) -> void:
	# Called exclusively by host-side collision simulation, never an RPC.
	if not peers.has(peer) or not position.is_finite():return
	var id: String=peers[peer]
	world.crew.members[id].position=[position.x,position.y,position.z]
func disconnect_member(peer: int,reserve_slot: bool=true) -> bool:
	_drop_pending(peer);inputs.erase(peer);input_sequences.erase(peer)
	if not peers.has(peer):return true
	var id: String=peers[peer]
	var draft:=world.duplicate(true)
	FrontierCrewWorld.disconnect_member(draft.crew,id);draft.crew.revision+=1
	if not save_world.call(draft):stopped=true;error="연결 종료 상태를 저장하지 못해 세계 진행을 정지했습니다.";return false
	world=draft;peers.erase(peer)
	if reserve_slot and peer!=1:reserved[id]=now+float(FrontierCrewWorld.config().reconnect_seconds)
	return true
func close() -> bool:
	stopped=true
	var draft:=world.duplicate(true)
	for id in peers.values():FrontierCrewWorld.disconnect_member(draft.crew,id)
	draft.crew.revision+=1
	if not save_world.call(draft):error="마지막 호스트 저장에 실패했습니다.";return false
	world=draft;peers.clear();pending.clear();inputs.clear();return true
func failure(message: String) -> Dictionary:return {"ok":false,"error":message,"revision":world.get("crew",{}).get("revision",0)}

func checkpoint() -> bool:
	if stopped:return false
	if not save_world.call(world):stopped=true;error="항해 상태 저장 실패로 세계를 정지했습니다.";return false
	return true
