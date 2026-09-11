extends SceneTree
const Delta=preload("res://scripts/network/crew_snapshot_delta.gd")
var failures:=0
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func receive(receiver: RefCounted,raw: PackedByteArray,serial: int)->Dictionary:
 var transport:=FrontierCrewSnapshotTransport.new()
 var parts:=FrontierCrewSnapshotTransport.fragments_raw(raw)
 var packet: Dictionary={}
 for i in range(parts.size()-1,-1,-1):packet=transport.accept(serial,i,parts.size(),parts[i],0)
 var value: Dictionary=receiver.decode(packet)
 if not value.is_empty():receiver.remember(serial,value)
 return value
func run()->void:
 var sender:=Delta.new();var receiver:=Delta.new()
 var world:=FrontierUniverse.new_world(71503)
 var owner:=FrontierPlayerProfile.new_character("전송 확인")
 var authority:=FrontierCrewAuthority.new()
 check(authority.start(world,owner,func(_state: Dictionary)->bool:return true),"current authority starts")
 var guest:=FrontierPlayerProfile.new_character("승무원")
 check(authority.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and authority.acknowledge(2,authority.session_id).ok,"second crew member admitted")
 var shared:=authority.snapshot_shared()
 var first:=authority.snapshot(2,shared)
 check(first==authority.snapshot(2) and first.self_id!=authority.snapshot(1,shared).self_id,"shared calculation preserves per-viewer state")
 var raw:=sender.encode(first)
 check(bytes_to_var(raw).base==-1,"first frame is self-contained")
 sender.remember(1,first)
 check(receive(receiver,raw,1)==first,"fragmented full frame reconstructs in reverse order")
 sender.acknowledge(999)
 check(sender.acknowledged==-1,"unknown acknowledgement ignored")
 sender.acknowledge(1)
 authority.now=1.0;authority.world.crew.members[guest.character_id].position[0]+=2
 var next:=authority.snapshot(2)
 raw=sender.encode(next);sender.remember(2,next)
 check(bytes_to_var(raw).base==1 and raw.size()<var_to_bytes(next).size(),"movement uses a smaller acknowledged delta")
 var roundtrip:=receive(receiver,raw,2)
 check(roundtrip==next,"nested movement and clock changes reconstruct")
 roundtrip.crew.members.clear()
 check(not receiver.history[2].crew.members.is_empty(),"presentation cannot mutate retained baseline")
 # Do not acknowledge or deliver frame 3. Frame 4 still names the known frame 1.
 authority.now=2;var skipped:=authority.snapshot(2);sender.remember(3,skipped)
 authority.now=3;next=authority.snapshot(2);next["optional_test"]={"added":[1,2,3]}
 raw=sender.encode(next);sender.remember(4,next)
 check(receive(receiver,raw,4)==next,"lost intermediate frame does not break later deltas")
 sender.acknowledge(4)
 var removed:=next.duplicate(true);removed.erase("optional_test");removed.crew.members[guest.character_id].ready=true
 raw=sender.encode(removed);sender.remember(5,removed)
 check(receive(receiver,raw,5)==removed,"removed section and nested replacement reconstruct")
 var invalid: Dictionary=bytes_to_var(raw)
 invalid.patch.children["absent"]={"set":{},"erase":[],"children":{}}
 check(receiver.decode(invalid).is_empty(),"malformed delta rejected without changing baseline")
 receiver.reset()
 check(receiver.decode(bytes_to_var(raw)).is_empty(),"new session refuses a previous baseline")
 for serial in range(6,15):sender.remember(serial,removed)
 raw=sender.encode(removed)
 check(bytes_to_var(raw).base==-1 and receive(receiver,raw,15)==removed,"expired acknowledgements recover with a full frame")
 var full_size:=0;var delta_size:=0
 sender=Delta.new();receiver=Delta.new()
 var stable:=authority.snapshot(2);sender.remember(1,stable);sender.acknowledge(1)
 for i in 10:
  authority.now+=.1;authority.world.crew.members[guest.character_id].position[0]+=.15
  var current:=authority.snapshot(2)
  for part in FrontierCrewSnapshotTransport.fragments(current):full_size+=part.size()
  for part in FrontierCrewSnapshotTransport.fragments_raw(sender.encode(current)):delta_size+=part.size()
 print("SNAPSHOT_10_COMPRESSED_BYTES full=",full_size," delta=",delta_size)
 check(delta_size<full_size,"current movement payload sends fewer compressed bytes")
 print("SNAPSHOT DELTA failures ",failures);quit(1 if failures else 0)
