extends "res://tests/check_planet_supply.gd"
func run() -> void:
	var fixture_store:=FrontierWorldStore.new("/tmp/planet-supply-20260908/world.json")
	var source:=fixture_store.read_state()
	if source.is_empty():printerr("Run check_planet_supply first for an isolated world fixture.");quit(1);return
	var profile_store:=FrontierPlayerProfile.new("/tmp/planet-supply-20260908/profile.json")
	profile_store.ensure("")
	var owner: Dictionary=source.crew.members[source.crew.owner_id].profile
	actor=owner.character_id;core=FrontierCrewAuthority.new()
	check(core.start(source,owner,persist),"start isolated existing world")
	sequences[1]=int(core.world.crew.members[actor].last_sequence)
	check(command("start_game").ok,"start session")
	var guest:=FrontierPlayerProfile.new_character("운송 담당",2)
	var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok,"guest joins")
	var courier: String=guest.character_id
	core.world.business.bags[courier]=FrontierExpeditionBusiness.inventory()
	FrontierExpeditionBusiness.transfer(core.world.business.bags[courier],FrontierShuttles.config().cost,1)
	var home: String=core.world.location
	core.world.crew.members[courier].position=factory().position.duplicate()
	check(not request(core,2,"shuttle_build",{"factory_id":factory().id}).ok,"existing product reserves factory")
	for i in 20:core.step_surface(1)
	var result:=request(core,2,"shuttle_build",{"factory_id":factory().id})
	check(result.ok,"craft request: "+str(result.get("error","")))
	if not result.ok:quit(1);return
	check(not request(core,1,"business_produce",{"building_id":factory().id,"product":"reinforced_frame"}).ok,"assembly reserves factory")
	for i in 46:core.step_surface(1)
	check(core.world.crew.shuttles[courier].state=="docked","powered assembly finishes")
	check(not request(core,2,"shuttle_build",{"factory_id":factory().id}).ok,"no duplicate craft")
	core.world.crew.members[courier].position=FrontierExpeditionBusiness.array(FrontierShuttles.pad(core.world,courier))
	var mother_before:=FrontierUniverse.fingerprint(core.world.crew.navigation)
	var before:=FrontierUniverse.fingerprint(core.world);disk_ok=false
	check(not request(core,2,"shuttle_board").ok and FrontierUniverse.fingerprint(core.world)==before,"failed launch save preserves crew and ship")
	disk_ok=true
	result=request(core,2,"shuttle_board")
	check(result.ok,"independent departure: "+str(result.get("error","")))
	if not result.ok:quit(1);return
	check(FrontierShuttles.aboard(core.world,courier) and core.world.crew.members[actor].area=="surface" and core.world.location==home,"host stays at original planet")
	check(FrontierUniverse.fingerprint(core.world.crew.navigation)==mother_before,"mother navigation unchanged")
	check(float(core.snapshot(2).vessel_stats.stellar_range)==0,"shuttle map exposes no interstellar range")
	check(core.snapshot(2).crew.landing.is_empty() and not core.snapshot(1).crew.landing.is_empty(),"independent viewer scene state")
	check(not request(core,1,"surface_board").ok,"mother waits for returning courier")
	var ship: Dictionary=core.world.crew.shuttles[courier]
	var outside_system:=0
	check(not request(core,2,"navigate",{"ordinal":outside_system}).ok,"reject interstellar navigation")
	var target: Dictionary={}
	for i in FrontierUniverse.body_count(core.world.manifest,int(ship.system)):
		var body:=FrontierUniverse.body(core.world.manifest,FrontierUniverse.first_ordinal(core.world.manifest,int(ship.system))+i)
		if body.id!=home and FrontierUniverse.landable(body):target=body;break
	check(not target.is_empty(),"same system landable destination")
	if target.is_empty():quit(1);return
	check(request(core,2,"navigate",{"ordinal":target.ordinal}).ok,"select same system destination")
	check(request(core,2,"depart").ok,"local flight approach")
	for i in 4000:
		var local:=FrontierShuttles.context(core.world,courier)
		FrontierCrewNavigation.step(local,.05);FrontierShuttles.commit(core.world,local,courier)
		if core.world.crew.shuttles[courier].navigation.mode=="idle":break
	check(core.world.crew.shuttles[courier].navigation.mode=="idle" and core.world.crew.shuttles[courier].location==target.id,"flight reaches destination")
	request(core,2,"ready",{"value":true})
	result=request(core,2,"land",{"ordinal":target.ordinal})
	check(result.ok,"courier lands: "+str(result.get("error","")))
	if not result.ok:quit(1);return
	var local:=FrontierShuttles.context(core.world,courier)
	check(local.location==target.id and core.world.location==home,"two independent surface locations")
	var packet:=FrontierCrewSurfaceReplica.packet(local,courier)
	check(packet.body_id==target.id and FrontierCrewSurfaceReplica.validate(packet,core.world.manifest),"destination surface replica validates")
	# Existing local warehouse stock represents previously produced freight, transferred through real commands.
	var depot:=FrontierExpeditionBusiness.site(local);depot.inventory.iron=12
	core.world.crew.members[courier].position=depot.center.duplicate()
	check(request(core,2,"business_withdraw",{"resource":"iron","amount":12}).ok,"courier collects destination warehouse freight")
	core.world.crew.members[courier].position=FrontierCrewSurface.config().ship_position.duplicate()
	check(request(core,2,"deposit",{"resource":"iron","amount":12}).ok,"load personal shuttle")
	check(int(core.world.crew.shuttles[courier].cargo.get("iron",0))==12 and int(core.world.crew.get("cargo",{}).get("iron",0))==int(source.crew.get("cargo",{}).get("iron",0)),"shuttle cargo isolated from mother")
	var guest_before:=FrontierUniverse.fingerprint(core.world.business.sites[target.id].inventory)
	check(FrontierCrewSurfaceReplica.packet(core.world,actor).body_id==home,"host still receives home")
	var stored:=core.world.duplicate(true)
	check(core.disconnect_member(2),"disconnect courier")
	var readmit:=core.admit(3,guest,admitted.token,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(readmit.ok and core.acknowledge(3,core.session_id).ok,"courier reconnects")
	sequences[3]=int(core.world.crew.members[courier].last_sequence)
	check(FrontierShuttles.location(core.world,courier)==target.id and int(core.world.crew.shuttles[courier].cargo.iron)==12,"reconnect preserves destination and freight")
	# Store scene fixture with courier on destination, host at home for the live two-place check.
	var output:=FrontierWorldStore.new("/tmp/finch-sortie/world.json");DirAccess.make_dir_recursive_absolute("/tmp/finch-sortie")
	check(output.write(core.world),"save distributed scene")
	var owner_file:=FrontierPlayerProfile.new("/tmp/finch-sortie/profile.json");owner_file.data={"version":1,"character":owner,"sessions":{}};check(owner_file.save(),"write isolated host profile")
	var courier_file:=FrontierPlayerProfile.new("/tmp/finch-sortie/courier.json");courier_file.data={"version":1,"character":guest,"sessions":{core.world.crew.world_id:admitted.token}};check(courier_file.save(),"write isolated courier profile")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"distributed world validates")
	# Return with the same craft and inventory.
	core.world.crew.members[courier].position=FrontierCrewSurface.config().ship_position.duplicate()
	check(request(core,3,"surface_board").ok,"courier takes off alone")
	var ordinal:=FrontierUniverse.ordinal_of(core.world.manifest,home)
	request(core,3,"navigate",{"ordinal":ordinal});request(core,3,"ready",{"value":true});request(core,3,"depart")
	for i in 4000:
		local=FrontierShuttles.context(core.world,courier);FrontierCrewNavigation.step(local,.05);FrontierShuttles.commit(core.world,local,courier)
		if local.crew.navigation.mode=="idle":break
	request(core,3,"ready",{"value":true});check(request(core,3,"land",{"ordinal":ordinal}).ok,"return landing")
	core.world.crew.members[courier].position=FrontierCrewSurface.config().ship_position.duplicate()
	check(request(core,3,"withdraw",{"resource":"iron","amount":12}).ok,"unload shuttle into personal bag")
	check(request(core,3,"shuttle_dock").ok,"rejoin mother team")
	check(not FrontierShuttles.aboard(core.world,courier) and int(core.world.business.bags[courier].iron)==12,"physical freight retained after reunion")
	check(FrontierUniverse.fingerprint(core.world.business.sites[target.id].inventory)==guest_before,"return does not duplicate destination stock")
	print("SHUTTLE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
