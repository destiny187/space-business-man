extends SceneTree
var checks:=0
var failures:=0
var saved: Dictionary={}
var disk_ok:=true
func _initialize() -> void:call_deferred("run")
func persist(world: Dictionary) -> bool:
	if not disk_ok:return false
	var error:=FrontierUniverse.validate_world(world)
	if not error.is_empty():printerr("PERSIST_ERROR ",error);return false
	saved=JSON.parse_string(JSON.stringify(world));return true
func check(condition: bool,label: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+label)
func envelope(core: FrontierCrewAuthority,sequence: int,kind: String,args: Dictionary) -> Dictionary:
	return {"session_id":core.session_id,"sequence":sequence,"kind":kind,"args":args,"revision":core.world.crew.revision}
func run() -> void:
	var host:=FrontierPlayerProfile.new_character("호스트",0)
	var original:=host.duplicate(true)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),host,persist),"host opens and durably owns a world")
	var guests: Array=[];var tokens: Array=[]
	for i in 5:
		var guest:=FrontierPlayerProfile.new_character("승무원 %d" % i,i+1)
		guest.equipment[1].grade="rare";guest.equipment[1].traits=["efficient"]
		guests.append(guest)
		var accepted:=core.admit(i+2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
		check(accepted.ok,"reserve guest slot "+str(i))
		tokens.append(accepted.get("token",""))
		check(not core.request(i+2,envelope(core,1,"ready",{"value":true})).ok,"pending guest cannot act")
		check(core.acknowledge(i+2,core.session_id).ok,"profile persisted before activation")
	check(core.slots()==6,"host-inclusive six player limit")
	check(not core.admit(9,FrontierPlayerProfile.new_character("일곱 번째"),"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok,"seventh player rejected")
	check(not core.admit(10,guests[0],tokens[0],int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok,"duplicate character rejected")
	var before:=JSON.stringify(core.world)
	var take:=envelope(core,1,"withdraw",{"amount":1})
	check(core.request(2,take).ok,"guest takes actual shared cargo")
	var count: int=core.world.crew.rock
	check(core.request(2,take).ok and core.world.crew.rock==count,"retry is idempotent")
	var tampered:=take.duplicate(true);tampered.args.amount=2
	check(not core.request(2,tampered).ok,"same request ID cannot change payload")
	var stale:=envelope(core,1,"withdraw",{"amount":1})
	check(core.request(3,stale).ok,"first concurrent command commits")
	check(not core.request(4,stale).ok,"competing stale version cannot commit twice")
	before=JSON.stringify(core.world);disk_ok=false
	check(not core.request(2,envelope(core,2,"deposit",{"amount":1})).ok and JSON.stringify(core.world)==before,"failed disk commit leaves world untouched")
	disk_ok=true
	check(core.request(1,envelope(core,1,"pilot",{"character_id":guests[0].character_id})).ok,"host delegates one pilot")
	check(not core.request(3,envelope(core,2,"pilot",{"character_id":guests[1].character_id})).ok,"guest cannot seize pilot authority")
	check(core.disconnect_member(2),"disconnect persists cargo at last location")
	check(core.world.crew.pilot_id==host.character_id and core.world.crew.members[guests[0].character_id].carried==0,"disconnect releases pilot without retaining duplicate cargo")
	check(core.world.crew.recovery.size()==1 and core.slots()==6,"cargo and reconnect reservation retained")
	check(not core.admit(12,guests[0],"0".repeat(64),int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok,"nickname or character ID cannot impersonate reconnect")
	var admission:=core.admit(12,guests[0],tokens[0],int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admission.ok and core.slots()==6,"reserved owner can reclaim full session slot")
	core.advance_time(9)
	check(core.slots()==6 and core.reserved.has(guests[0].character_id),"expired handshake retains remaining reconnect grace")
	check(core.admit(12,guests[0],tokens[0],int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(12,core.session_id).ok,"reconnect activates the original character")
	check(core.world.crew.members[guests[0].character_id].profile==guests[0] and core.world.crew.members[guests[0].character_id].carried==0,"grade and traits preserved without duplicated world cargo")
	var snapshot:=core.snapshot(12)
	check(not JSON.stringify(snapshot).contains("capability_hash") and not JSON.stringify(snapshot).contains(tokens[0]),"snapshots do not disclose reconnection credentials")
	check(core.input(12,2,[1,0]) and not core.input(12,1,[-1,0]),"stale movement sequence ignored")
	check(not core.input(12,3,[INF,0]),"nonfinite movement rejected")
	core.advance_time(10)
	check(core.direction_for(12)==Vector2.ZERO,"lost input expires instead of walking forever")
	var old_session:=core.session_id
	check(core.close(),"normal host close persists state")
	var reopened:=FrontierCrewAuthority.new()
	check(reopened.start(saved,host,persist),"same owner reopens host world")
	check(reopened.session_id!=old_session,"new session invalidates old connection epoch")
	check(not reopened.request(1,{"session_id":old_session,"sequence":3,"kind":"ready","args":{"value":true}}).ok,"old-session command rejected")
	check(host==original,"host original personal equipment never mutated")
	disk_ok=false
	check(not reopened.checkpoint() and reopened.stopped,"checkpoint failure stops authoritative simulation")
	print("CREW_AUTHORITY_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
