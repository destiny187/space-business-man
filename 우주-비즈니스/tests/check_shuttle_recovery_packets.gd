extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var source:=FrontierWorldStore.new("/tmp/finch-sortie/world.json").read_state()
	if source.is_empty():printerr("Isolated /tmp/finch-sortie/world.json fixture required (check_shuttle_sortie).");quit(1);return
	var session:=FrontierCrewSession.new()
	check(session._valid_manifest(source.manifest),"legacy pre-cave manifest accepted without regeneration")
	check(session._valid_manifest(FrontierUniverse.generate(71491)),"new cave manifest accepted")
	session.free()
	var owner: Dictionary=source.crew.members[source.crew.owner_id].profile
	var courier: String=source.crew.shuttles.keys()[0]
	var guest: Dictionary=source.crew.members[courier].profile
	var profile:=FrontierPlayerProfile.new("/tmp/finch-sortie/courier.json");profile.ensure()
	var token: String=profile.data.sessions[source.crew.world_id]
	var core:=FrontierCrewAuthority.new()
	check(core.start(source,owner,persist),"start isolated distributed world")
	sequences[1]=int(core.world.crew.members[owner.character_id].last_sequence)
	check(request(core,1,"start_game").ok,"start")
	var admitted:=core.admit(2,guest,token,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok,"reconnect sortie")
	sequences[2]=int(core.world.crew.members[courier].last_sequence)
	check(not request(core,1,"shuttle_recall",{"character_id":courier}).ok,"reject online recall")
	check(not request(core,2,"shuttle_recall",{"character_id":courier}).ok,"reject guest recall")
	core.world.business.bags[courier].copper=9
	core.world.crew.members[courier].carried=3
	var items: Dictionary=core.world.crew.members[courier].loadout.items
	var equipment: String=items.keys()[0]
	var gear: String=items[equipment]
	core.world.crew.shuttles[courier].cargo_equipment[courier+"/"+equipment]={"owner":courier,"item_id":equipment,"definition":gear}
	items.erase(equipment)
	# Slots refer to IDs; clear any slot holding the stored equipment.
	for i in core.world.crew.members[courier].loadout.slots.size():
		if core.world.crew.members[courier].loadout.slots[i]==equipment:core.world.crew.members[courier].loadout.slots[i]=""
	check(core.disconnect_member(2),"disconnect keeps sortie freight")
	var bag:=FrontierUniverse.fingerprint(core.world.business.bags[courier])
	var freight:=FrontierUniverse.fingerprint(core.world.crew.shuttles[courier].cargo)
	var loadout:=FrontierUniverse.fingerprint(core.world.crew.members[courier].loadout)
	var stored_gear:=FrontierUniverse.fingerprint(core.world.crew.shuttles[courier].cargo_equipment)
	check(int(core.world.crew.members[courier].carried)==3,"legacy hand cargo remains owned on disconnect")
	admitted=core.admit(3,guest,token,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and not request(core,1,"shuttle_recall",{"character_id":courier}).ok,"reject during handshake")
	core.disconnect_member(3,false)
	var before:=FrontierUniverse.fingerprint(core.world);disk_ok=false
	check(not request(core,1,"shuttle_recall",{"character_id":courier}).ok and FrontierUniverse.fingerprint(core.world)==before,"failed save leaves remote sortie untouched")
	disk_ok=true
	var recall:=envelope(core,1,"shuttle_recall",{"character_id":courier})
	var result:=core.request(1,recall)
	check(result.ok,"durable host recall: "+str(result.get("error","")))
	check(core.request(1,recall)==result,"retry returns original receipt")
	check(not request(core,1,"shuttle_recall",{"character_id":courier}).ok,"new duplicate recall rejected")
	check(not FrontierShuttles.aboard(core.world,courier) and core.world.crew.shuttles[courier].state=="docked","recall releases sortie blocker")
	check(FrontierShuttles.guard(core.world,owner.character_id,"surface_board",{}).is_empty(),"mother can board again")
	check(FrontierUniverse.fingerprint(core.world.business.bags[courier])==bag and FrontierUniverse.fingerprint(core.world.crew.shuttles[courier].cargo)==freight,"bag and freight quantities preserved")
	check(FrontierUniverse.fingerprint(core.world.crew.members[courier].loadout)==loadout and FrontierUniverse.fingerprint(core.world.crew.shuttles[courier].cargo_equipment)==stored_gear,"personal and stored equipment preserved")
	check(core.close(),"save close before rescued member reconnects")
	var resumed:=FrontierCrewAuthority.new();check(resumed.start(saved,owner,persist),"host restart preserves recovery")
	check(FrontierUniverse.fingerprint(resumed.world.business.bags[courier])==bag and resumed.world.crew.members[courier].carried==3,"no recovery bag drop at close or restart")
	admitted=resumed.admit(4,guest,token,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and resumed.acknowledge(4,resumed.session_id).ok,"owner reconnects after recovery")
	check(not FrontierShuttles.aboard(resumed.world,courier) and FrontierShuttles.location(resumed.world,courier)==resumed.world.location,"reconnect at main ship planet")
	check(FrontierUniverse.fingerprint(resumed.world.business.bags[courier])==bag,"reconnect preserves same bag without grant")
	transport_check(resumed.snapshot(4))
	print("RECOVERY_PACKET_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
func transport_check(value: Dictionary) -> void:
	var parts:=FrontierCrewSnapshotTransport.fragments(value)
	check(parts.size()>1 and parts.all(func(p: PackedByteArray):return p.size()<=900),"compressed snapshot split below datagram budget")
	var receiver:=FrontierCrewSnapshotTransport.new()
	var complete: Dictionary={}
	for i in range(parts.size()-1,-1,-1):
		var result:=receiver.accept(1,i,parts.size(),parts[i],0)
		if not result.is_empty():complete=result
	check(complete==value,"reverse arrival reconstructs exact int/float snapshot")
	check(receiver.accept(1,0,parts.size(),parts[0],0).is_empty(),"old completed frame ignored")
	for i in parts.size()-1:check(receiver.accept(2,i,parts.size(),parts[i],0).is_empty(),"partial frame not applied")
	complete={}
	for i in parts.size():
		var result:=receiver.accept(3,i,parts.size(),parts[i],100)
		if not result.is_empty():complete=result
	check(complete==value and receiver.frames.is_empty(),"new whole snapshot supersedes dropped frame")
	check(receiver.accept(2,parts.size()-1,parts.size(),parts[-1],110).is_empty(),"late old fragment cannot rewind")
	check(receiver.accept(4,0,999999,parts[0],120).is_empty(),"reject unbounded fragment count")
	for serial in range(4,12):receiver.accept(serial,0,parts.size(),parts[0],200)
	check(receiver.frames.size()<=3,"bounded incomplete reassembly memory")
	receiver.accept(12,0,parts.size(),parts[0],1300)
	check(receiver.frames.size()==1,"expired partial frames discarded")
	print("SNAPSHOT_RAW_BYTES ",var_to_bytes(value).size()," COMPRESSED_BYTES ",parts.reduce(func(total: int,p: PackedByteArray):return total+p.size(),0)," PARTS ",parts.size())
