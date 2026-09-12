extends SceneTree
var failures:=0
var checks:=0
var actor: String
var authority:=FrontierCrewAuthority.new()
var world: Dictionary
var system:=0
var sequence:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,name: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",name)
	else:print("PASS ",name)
func stage(id: String="crew") -> void:
	var local:=FrontierSpaceCombat.local_world(world,id);var nav: Dictionary=local.crew.navigation
	local.crew.landing={};nav.erase("solar_opening");nav.erase("station_docked");nav.system=system;nav.target=FrontierUniverse.first_ordinal(world.manifest,system)
	local.location=FrontierUniverse.body_id(world.manifest,int(nav.target));local.navigation_target=local.location
	nav.mode="idle";nav.manual=true;nav.direction=[0.0,0.0,-1.0];nav.speed=0.0;nav.hull=100.0;nav.energy=100.0;nav.first_stellar_system=1
	for i in range(10,60):
		var p:=Vector3(0,i*400,0)
		if FrontierSpaceCombat.clear_position(world,system,p,1200):nav.position=FrontierSpaceCombat.arr(p);break
	local.flight_position=nav.position.duplicate();FrontierSpaceCombat.commit(world,local,id)
	for m in local.crew.members.values():m.aboard=true;m.area="cabin";m.ready=true
func step(seconds: float,fire: bool=false,aim: Vector3=Vector3.FORWARD) -> void:
	for i in ceili(seconds/.1):
		sequence+=1;authority.now+=.1
		authority.input(1,sequence,[0,0],FrontierSpaceCombat.arr(aim),false,false,[0,0,0,0,1.0 if fire else 0.0,1.0],0,false)
		FrontierSpaceCombat.tick(world,.1,authority.inputs,authority.peers,authority.now)
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("해적 규칙 확인",0);actor=owner.character_id
	check(authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"new world host starts")
	world=authority.world;authority.phase="playing"
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:system=index;break
	check(system>0,"find T2 route");stage()
	var r:=FrontierSpaceCombat.record(world)
	check(FrontierSpaceCombat.valid(r),"new combat record valid")
	var legacy:=world.duplicate(true);legacy.crew.erase("space_combat")
	check(not FrontierSpaceCombat.tick(legacy,.1,{},authority.peers,0) and not legacy.crew.has("space_combat"),"old save does not gain ambushes")
	check(FrontierSpaceCombat.begin(world,"crew","stellar_arrival"),"stellar arrival intercept creates the combat formation")
	check(r.encounter.enemies.size()==3 and world.crew.navigation.mode=="idle","combat grants manual control")
	check(not FrontierSpaceCombat.guard(world,actor,"land",{}).is_empty(),"cannot land through active interception")
	step(8.2);check(r.encounter.phase=="combat","host warning completes after ready input")
	var enemy: Dictionary=r.encounter.enemies[0]
	world.crew.navigation.direction=FrontierSpaceCombat.arr((FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(world.crew.navigation.position)).normalized())
	var direction:=FrontierSpaceCombat.point(world.crew.navigation.direction)
	var camera_origin:=FrontierSpaceCombat.point(world.crew.navigation.position)-direction*57+Vector3.UP*16
	var aim: Vector3=(FrontierSpaceCombat.point(enemy.position)-camera_origin).normalized()
	var shield: float=enemy.shield
	check(FrontierSpaceCombat.fire(world,actor,aim) and float(enemy.shield)<shield,"pulse hits authoritative enemy shield")
	check(not FrontierSpaceCombat.fire(world,actor,aim),"fire rate enforced")
	FrontierSpaceCombat.damage_ship(world,"crew",120)
	check(r.ships.crew.shield==0 and world.crew.navigation.hull==80,"shield absorbs before hull")
	var before: float=enemy.hull
	for j in range(35):
		r.ships.crew.cooldown=0;r.ships.crew.heat=0;r.ships.crew.overheated=false
		FrontierSpaceCombat.fire(world,actor,aim)
		if enemy.hull<=0:break
	check(enemy.hull==0 and r.wrecks.size()==1,"destroyed craft leaves one physical salvage record")
	check(FrontierSpaceCombat.valid(r),"combat and wreck state validate")
	world.crew.navigation.position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(r.encounter.origin)+Vector3(2500,0,0));step(4.2)
	check(r.encounter.phase=="combat" and FrontierSpaceCombat.can_jump(world),"distance opens departure without ending pursuit")
	for remaining in r.encounter.enemies:remaining.hull=0
	step(.1)
	check(r.encounter.phase=="victory","all enemies must be defeated to salvage in the same system")
	check(r.cooldown>590 and r.safe_journeys==2,"both routes share cooldown")
	var w: Dictionary=r.wrecks[0];world.crew.navigation.position=w.position.duplicate();world.crew.navigation.speed=0
	var iron:=int(world.crew.get("cargo",{}).get("iron",0))
	check(FrontierSpaceCombat.apply(world,actor,"space_salvage",{"id":w.id}).is_empty(),"salvage starts from nearby physical pod")
	check(int(world.crew.get("cargo",{}).get("iron",0))==iron,"request does not grant cargo before hoist completes")
	step(2.6)
	check(r.wrecks.is_empty() and int(world.crew.cargo.iron)==iron+8,"timed recovery credits cargo once")
	check(not FrontierSpaceCombat.apply(world,actor,"space_salvage",{"id":w.id}).is_empty(),"same wreck cannot pay twice")
	r.encounter={};stage();r.serial+=1;check(FrontierSpaceCombat.begin(world,"crew","local_transit"),"local flight starts same combat foundation")
	world.crew.navigation.hull=0;step(.1)
	check(r.encounter.phase=="recovering","disabled hull enters recovery")
	step(6.1);check(world.crew.navigation.hull==35 and r.encounter.phase=="recovered","zero funds still restores basic flight")
	check(int(world.crew.cargo.iron)==iron+8,"recovery preserves existing cargo")
	r.encounter={};stage()
	# FINCH uses the actual context/commit path and keeps cargo in its own ledger.
	world.crew.shuttles={actor:{"state":"sortie","pad_slot":0,"progress":0.0,"factory_id":"","system":system,"location":world.location,"navigation_target":world.location,"navigation":world.crew.navigation.duplicate(true),"landing":{},"cargo":{"copper":3},"cargo_equipment":{},"rock":0}}
	world.crew.members[actor].shuttle_id=actor
	var id: String="shuttle:"+actor
	check(FrontierSpaceCombat.begin(world,id,"local_transit") and r.encounter.enemies.size()==1,"unarmed FINCH gets short single-pursuer encounter")
	check(not FrontierSpaceCombat.fire(world,actor,Vector3.FORWARD),"FINCH stays an unarmed transporter")
	var local:=FrontierShuttles.context(world,actor);local.crew.navigation.position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(r.encounter.origin)+Vector3(2200,0,0));FrontierShuttles.commit(world,local,actor)
	step(4.2);check(r.encounter.phase=="escaped","FINCH escapes without interstellar propulsion or kills")
	check(world.crew.shuttles[actor].cargo.copper==3,"FINCH cargo ownership preserved")
	check(FrontierSpaceCombat.guard(world,actor,"depart",{}).is_empty() and not FrontierShuttles.guard(world,actor,"navigate",{"ordinal":0}).is_empty(),"escape preserves FINCH interstellar prohibition")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(r));check(FrontierSpaceCombat.valid(saved),"combat serializes and validates")
	world.crew.space_combat=saved;FrontierSpaceCombat.resume(world);check(world.crew.space_combat.encounter.resume==5,"resume has warning instead of immediate damage")
	var malformed: Dictionary=saved.duplicate(true);malformed.encounter.enemies[0].position=["bad",0,0];check(not FrontierSpaceCombat.valid(malformed),"invalid network/save position rejected")
	world.crew.members[actor].erase("shuttle_id");world.crew.shuttles={};world.crew.space_combat=FrontierSpaceCombat.create();stage()
	r=FrontierSpaceCombat.record(world)
	var cfg:=FrontierSpaceCombat.config();var old_stellar: float=cfg.stellar_chance;var old_local: float=cfg.local_chance
	cfg.stellar_chance=1.0;cfg.local_chance=1.0
	step(.1)
	var nav: Dictionary=world.crew.navigation
	nav.system=system+1;nav.mode="jump";nav.jump_left=12.0;nav.transit={"from":[0.0,0.0],"to":[1.0,1.0],"galaxy_position":[0.0,0.0],"duration":12.0,"progress":0.0}
	step(.1);check(r.flights.crew.route=="ambush","departure rolls and saves one stellar encounter")
	nav.jump_left=.01
	FrontierCrewNavigation.step(world,.1)
	check(not r.encounter.is_empty() and r.encounter.variant=="stellar_arrival" and nav.mode=="idle","normal navigation step intercepts before final arrival")
	check(not world.visited.has(FrontierUniverse.body_id(world.manifest,int(nav.target))),"interception does not mark unvisited destination complete")
	r.encounter={};r.cooldown=0;r.safe_journeys=0;stage();r.flights={};step(.1)
	r.flights.crew.seconds=100;r.flights.crew.distance=3000;world.crew.navigation.speed=80
	step(.1)
	check(not r.encounter.is_empty() and r.encounter.variant=="local_transit","normal local flight scheduler creates second encounter type")
	r.encounter={};r.cooldown=0;r.safe_journeys=2;stage();r.flights={};step(.1)
	for journey in 2:
		r.flights.crew.seconds=100;r.flights.crew.distance=3000;world.crew.navigation.speed=80;step(.1)
		check(r.encounter.is_empty(),"safe journey %d stays protected until completed"%(journey+1))
	# Exercise durable command receipts through authority, including shared state snapshots.
	world.crew.navigation.speed=0;world.crew.navigation.hull=35;world.business=FrontierExpeditionBusiness.create();world.business.credits=100
	var request: Dictionary={"session_id":authority.session_id,"sequence":1,"kind":"space_repair","args":{},"revision":world.crew.revision}
	check(authority.request(1,request).ok,"repair request enters normal durable host transaction")
	world=authority.world;r=FrontierSpaceCombat.record(world);step(2.6)
	check(world.business.credits==40 and world.crew.navigation.hull==100,"repair costs deducted once on timed completion")
	check(authority.request(1,request).ok and world.business.credits==40,"replayed request does not repeat repair charge")
	var snapshot:=authority.snapshot(1)
	check(snapshot.crew.space_combat.event_serial==r.event_serial,"client snapshot carries authoritative combat results")
	world.crew.navigation.hull=35;authority.save_world=func(_w):return false
	request.sequence=2;request.revision=world.crew.revision
	check(not authority.request(1,request).ok and r.ships.crew.operation.is_empty(),"save failure does not publish a repair operation")
	cfg.stellar_chance=old_stellar;cfg.local_chance=old_local
	print("PIRATE_RULE_CHECKS ",checks," FAILURES ",failures," SYSTEM ",system)
	quit(1 if failures else 0)
