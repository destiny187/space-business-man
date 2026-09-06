extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var core:=FrontierCrewAuthority.new()
	var owner:=FrontierPlayerProfile.new_character("전송 상한",0)
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"budget world opens")
	navigate(core,15);ready_all(core);check(request(core,1,"land").ok,"budget world lands")
	check(request(core,1,"business_register").ok,"budget world registers industry")
	for peer in range(2,7):
		var guest:=FrontierPlayerProfile.new_character("전송 검증 "+str(peer),0)
		check(core.admit(peer,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(peer,core.session_id).ok,"six admitted recipients "+str(peer))
	# Legal maximum-size state fixture; this is codec stress, not a 4096-excavation gameplay claim.
	var path: Array=[]
	for i in 3500:path.append([sin(i*.013)*60,2.0+sin(i*.02),cos(i*.017)*60])
	for i in 6:
		var id: String="robot:"+str(i+1)
		var robot: Dictionary={"id":id,"grade":"standard","position":[float(i*3),2.0,-8.0],"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","path":path.duplicate(true),"status":"경로 상한 검증","work":0.0,"charging":false}
		if i<4:FrontierExpeditionBusiness.site(core.world).robots[id]=robot
		else:core.world.business.hangar[id]=robot
	core.world.business.counter=6
	var edits: Array=[]
	for i in 4096:edits.append({"center":[sin(i*.033)*5000,cos(i*.11)*25-30,cos(i*.019)*5000],"radius":2.6})
	core.world.terrain_edits[core.world.location]=edits
	check(FrontierUniverse.validate_world(core.world).is_empty(),"maximum path and excavation fixture is valid persisted state")
	var before:=FrontierUniverse.fingerprint(core.world)
	var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner.character_id)
	var legacy:=packet.duplicate(true)
	legacy.business.sites[core.world.location].robots=FrontierExpeditionBusiness.site(core.world).robots.duplicate(true)
	legacy.business.hangar=core.world.business.hangar.duplicate(true)
	var old_bytes:=JSON.stringify(legacy).to_utf8_buffer().size()
	var current_bytes:=JSON.stringify(packet).to_utf8_buffer().size()
	check(old_bytes>int(FrontierCrewSurface.config().maximum_packet_bytes),"old full route replication exceeded the decoder budget")
	check(current_bytes<int(FrontierCrewSurface.config().maximum_packet_bytes),"visible state and 4096 edits fit the uncompressed budget")
	check(FrontierCrewSurfaceReplica.encode(legacy).is_empty(),"sender rejects an oversized decompressed payload before transmission")
	var encoded:=FrontierCrewSurfaceReplica.encode(packet)
	check(not encoded.is_empty() and not FrontierCrewSurfaceReplica.decode(encoded,core.world.manifest).is_empty(),"maximum client payload encodes and decodes")
	check(FrontierCrewSurfaceReplica.decode(PackedByteArray(),core.world.manifest).is_empty(),"empty payload rejects without decompressor errors")
	for id in FrontierExpeditionBusiness.site(core.world).robots:
		var authoritative: Dictionary=FrontierExpeditionBusiness.site(core.world).robots[id]
		var visible: Dictionary=packet.business.sites[core.world.location].robots[id]
		check(visible.position==authoritative.position and visible.cargo==authoritative.cargo and visible.path.is_empty(),"robot pose and cargo survive without private route "+id)
	check(FrontierUniverse.fingerprint(core.world)==before,"replication does not erase host routes or mutate the saved world")
	packet.business.sites[core.world.location].robots["robot:1"].position[0]+=1
	check(FrontierUniverse.fingerprint(core.world)==before,"editing a client pose cannot alias host simulation arrays")
	var milliseconds: Array=[]
	var compressed: Array=[]
	for peer in core.peers:
		var start:=Time.get_ticks_usec()
		var value:=FrontierCrewSurfaceReplica.packet(core.world,core.peers[peer])
		var data:=FrontierCrewSurfaceReplica.encode(value)
		check(not data.is_empty() and not FrontierCrewSurfaceReplica.decode(data,core.world.manifest).is_empty(),"bounded packet for recipient "+str(peer))
		milliseconds.append((Time.get_ticks_usec()-start)/1000.0);compressed.append(data.size())
	var report: Dictionary={"checks":checks,"failures":failures,"fixture":"4096 terrain edits, four local robots, two transported robots, 3500 waypoints per robot","before_raw_bytes":old_bytes,"after_raw_bytes":current_bytes,"compressed_bytes":compressed,"packet_encode_decode_milliseconds":milliseconds,"recipients":6,"real_network":false,"gpu_performance":false}
	var output:=FileAccess.open("/tmp/locus-industry-replica-budget.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "));output.close()
	print("INDUSTRY_REPLICA_CHECKS ",checks," FAILURES ",failures," before=",old_bytes," after=",current_bytes," compressed=",encoded.size())
	quit(1 if failures else 0)
