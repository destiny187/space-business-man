extends SceneTree
var core: FrontierCrewAuthority
var checks:=0
var failures:=0
var disk_ok:=true
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func persist(world: Dictionary) -> bool:
	var reason:=FrontierUniverse.validate_world(world)
	if not reason.is_empty():printerr(reason)
	return disk_ok and reason.is_empty()
func request(kind: String,args: Dictionary={},peer: int=1) -> Dictionary:
	return core.request(peer,{"session_id":core.session_id,"sequence":int(core.world.crew.members[core.peers[peer]].last_sequence)+1,"revision":core.world.crew.revision,"kind":kind,"args":args})
func at_station() -> void:
	var m: Dictionary=core.world.manifest
	for index in range(1,200):
		var station:=FrontierSpaceStation.definition(m,index)
		if station.is_empty():continue
		var nav: Dictionary=core.world.crew.navigation
		nav.system=index;nav.target=FrontierUniverse.first_ordinal(m,index);nav.mode="idle";nav.speed=0;nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,0,1000))
		core.world.location=FrontierUniverse.body_id(m,int(nav.target));core.world.flight_position=nav.position.duplicate();core.world.crew.landing={}
		for member in core.world.crew.members.values():member.aboard=true;member.area="cabin";member.ready=true
		return
func find_body(tier: int) -> int:
	var first:=maxi(1,(tier-2)*25000)*8
	for ordinal in range(first,first+2000):
		var body:=FrontierUniverse.body(core.world.manifest,ordinal,false)
		if int(body.planet_tier)==tier and FrontierUniverse.landable(body):return ordinal
	return -1
func at_orbit(ordinal: int) -> void:
	var world: Dictionary=core.world;var m: Dictionary=world.manifest;var nav: Dictionary=world.crew.navigation
	var body:=FrontierUniverse.body(m,ordinal)
	nav.system=FrontierUniverse.system_index(m,ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0;nav.erase("station_docked")
	var p:=FrontierUniverse.position(m,ordinal,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+float(m.settings.flight.arrival_clearance))
	nav.position=FrontierExpeditionBusiness.array(p);world.flight_position=nav.position.duplicate();world.location=body.id;world.crew.landing={}
	for member in world.crew.members.values():member.aboard=true;member.area="cabin";member.ready=true
func run() -> void:
	core=FrontierCrewAuthority.new()
	var profile:=FrontierPlayerProfile.new_character("항해 조건 검사")
	check(core.start(FrontierUniverse.new_world(71503),profile,persist),"start legacy-compatible fresh vessel")
	check(request("start_game").ok,"start playing")
	core.world.vessel=FrontierVesselRefit.create(int(core.world.manifest.seed),core.world.crew.world_id)
	check(FrontierVesselAccess.tier_for(FrontierVesselAccess.capabilities(core.world.vessel))==2,"starter permits T1 and T2")
	for tier in range(1,6):check(FrontierVesselAccess.reason({},tier).is_empty()==(tier<=2),"base capability threshold T"+str(tier))
	var m: Dictionary=core.world.manifest
	check(FrontierVesselAccess.system_tier(m,49999)==2 and FrontierVesselAccess.system_tier(m,50000)==3 and FrontierVesselAccess.system_tier(m,75000)==4 and FrontierVesselAccess.system_tier(m,100000)==5,"radial region thresholds")
	var t3:=find_body(3);check(t3>=0,"T3 target exists")
	at_orbit(t3)
	var before:=FrontierUniverse.fingerprint(core.world)
	check(not request("depart").ok and not request("land",{"ordinal":t3}).ok and before==FrontierUniverse.fingerprint(core.world),"manual flight and same-system approach cannot bypass T3 landing gate")
	var nav: Dictionary=core.world.crew.navigation
	nav.system=40000;nav.target=50000*8
	check(str(request("depart").get("error","")).contains("항해 내성"),"short-hop route also checks destination region before range")
	# An old low-spec vessel deep within a band can move outward even before reaching a band boundary.
	nav.system=62000
	var source:=FrontierUniverse.map_position(m,int(nav.system));var outward: int=-1;var inward: int=-1
	for index in range(50000,75000):
		var point:=FrontierUniverse.map_position(m,index)
		if point.distance_to(source)>7.9 or index==int(nav.system):continue
		if point.length()>source.length()+.01:outward=index
		else:inward=index
		if outward>=0 and inward>=0:break
	check(outward>=0 and inward>=0,"nearby radial escape fixtures")
	check(FrontierVesselAccess.departure_reason(core.world,outward*8).is_empty() and not FrontierVesselAccess.departure_reason(core.world,inward*8).is_empty(),"legacy retreat only outward; inward travel remains locked")
	at_station()
	core.world.business=FrontierExpeditionBusiness.create();core.world.business.credits=500000
	var owner: String=core.peers[1];core.world.business.bags[owner]=FrontierExpeditionBusiness.inventory()
	var module:=FrontierVesselRefit.add_module(core.world.vessel,"cargo","standard");core.world.vessel.loadout.utility=module
	var hull_item: String=""
	for id in core.snapshot().station.stock:
		if id.begins_with("hull:"):hull_item=id
	check(request("station_buy",{"item":hull_item}).ok,"buy a T3-rated role hull")
	check(FrontierVesselAccess.tier_for(FrontierVesselAccess.capabilities(core.world.vessel))==2,"parked owned hull grants no capability")
	check(request("station_equip",{"item":hull_item.trim_prefix("hull:")}).ok,"activate purchased hull")
	check(int(core.snapshot().vessel_stats.navigation_tier)==3 and core.world.vessel.loadout.utility==module,"active hull unlocks T3 and preserves utility module")
	check(request("station_equip",{"item":"kestrel"}).ok and int(core.snapshot().vessel_stats.navigation_tier)==2,"switching hull immediately recomputes capability")
	check(not request("station_navigation_refit",{"item":"5"}).ok,"no skipping refit stages")
	before=FrontierUniverse.fingerprint(core.world);disk_ok=false
	check(not request("station_navigation_refit",{"item":"3"}).ok and before==FrontierUniverse.fingerprint(core.world),"failed save rolls back funds and refit")
	disk_ok=true
	var receipt: Dictionary={"session_id":core.session_id,"sequence":int(core.world.crew.members[owner].last_sequence)+1,"revision":core.world.crew.revision,"kind":"station_navigation_refit","args":{"item":"3"}}
	var credits:=int(core.world.business.credits)
	check(core.request(1,receipt).ok,"station refits current basic hull")
	before=FrontierUniverse.fingerprint(core.world)
	check(core.request(1,receipt).ok and before==FrontierUniverse.fingerprint(core.world) and credits-int(core.world.business.credits)==int(FrontierVesselAccess.config().refits["3"].station_credits),"retry charges only once")
	var guest:=FrontierPlayerProfile.new_character("공동 승무원",1)
	check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"second crew member joins")
	check(int(core.snapshot(2).vessel_stats.navigation_tier)==3 and not request("station_navigation_refit",{"item":"4"},2).ok,"shared access and host-only spending")
	for tier in range(3,6):
		if tier>3:
			at_station();check(request("station_navigation_refit",{"item":str(tier)}).ok,"successive refit T"+str(tier))
		var ordinal:=find_body(tier);check(ordinal>=0,"target T"+str(tier))
		at_orbit(ordinal)
		check(request("land",{"ordinal":ordinal}).ok,"rated ship lands T"+str(tier))
		check(FrontierVesselAccess.reason(FrontierVesselAccess.capabilities(core.world.vessel),mini(5,tier+1)).is_empty()==(tier==5),"next tier still requires next capability")
		var saved: Dictionary=JSON.parse_string(JSON.stringify(core.world))
		check(FrontierUniverse.validate_world(saved).is_empty() and FrontierVesselAccess.tier_for(FrontierVesselAccess.capabilities(saved.vessel))==tier,"refit survives serialized save T"+str(tier))
	var invalid: Dictionary=core.world.vessel.duplicate(true);invalid.navigation_refits.kestrel=6
	check(not FrontierVesselAccess.validate(invalid).is_empty(),"invalid refit rejected")
	invalid=core.world.vessel.duplicate(true);invalid.navigation_refits.unknown=3
	check(not FrontierVesselAccess.validate(invalid).is_empty(),"unowned refit rejected")
	# FINCH gets the active expedition capability, never the player's parked hull collection.
	var shuttle_world: Dictionary=core.world.duplicate(true)
	shuttle_world.vessel.hull="kestrel";shuttle_world.vessel.erase("navigation_refits")
	shuttle_world.crew.shuttles[owner]={"state":"away","location":shuttle_world.location,"navigation_target":shuttle_world.location,"navigation":shuttle_world.crew.navigation,"landing":{},"cargo":{},"cargo_equipment":{},"rock":0}
	shuttle_world.crew.members[owner].shuttle_id=owner
	var local:=FrontierShuttles.context(shuttle_world,owner)
	check(not FrontierVesselAccess.landing_reason(local,t3).is_empty(),"FINCH cannot bypass active ship restrictions")
	check(FrontierVesselAccess.landing_reason(local,FrontierUniverse.ordinal_of(m,local.mothership_location)).is_empty(),"FINCH recovery to mothership remains possible")
	# Ground refit consumes existing T2 products, without requiring T3 exploration.
	at_orbit(find_body(2));check(request("land").ok,"T2 still freely landable")
	core.world.vessel.navigation_refits={};core.world.vessel.hull="kestrel"
	check(request("business_register").ok,"register ground service site")
	check(request("business_lease").ok,"lease ground site")
	var site:=FrontierExpeditionBusiness.site(core.world)
	for id in FrontierVesselAccess.config().refits["3"].materials:site.inventory[id]=int(FrontierVesselAccess.config().refits["3"].materials[id])
	core.world.crew.members[owner].position=FrontierCrewSurface.config().ship_position.duplicate()
	credits=int(core.world.business.credits)
	var result:=request("vessel_navigation_refit",{"tier":3})
	check(result.ok,"ground T3 refit using T2-only materials: "+str(result.get("error","")))
	check(credits-int(core.world.business.credits)==int(FrontierVesselAccess.config().refits["3"].field_credits),"ground service charges shared credits once")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"final fixture save valid")
	print("VESSEL ACCESS: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
