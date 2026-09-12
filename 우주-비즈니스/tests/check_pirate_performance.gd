extends "res://tests/check_pirate_rules.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("항해 캐시와 저장 확인",0);actor=owner.character_id
	check(authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host starts with immutable generation data")
	world=authority.world;authority.phase="playing";system=1000;stage()
	var first:=FrontierSpaceCombat.obstacles(world,system,0.0)
	check(first==FrontierCrewNavigation.departure_obstacles(world.manifest,system,world.crew.navigation.orbit_time,0),"cached collision includes the full current obstacle set")
	world.crew.navigation.orbit_time+=125.0
	var later:=FrontierSpaceCombat.obstacles(world,system,0.0)
	check(later!=first and later==FrontierCrewNavigation.departure_obstacles(world.manifest,system,world.crew.navigation.orbit_time,0),"orbital movement invalidates old collision positions")
	check(FrontierSpaceCombat.obstacles(world,0,8.0)==FrontierCrewNavigation.departure_obstacles(world.manifest,0,world.crew.navigation.orbit_time,8.0),"changing system and forecast horizon preserves departure safety")
	var mutable:=world.duplicate();mutable.manifest=world.manifest.duplicate(true);mutable.manifest.seed+=7
	check(FrontierSpaceCombat.obstacles(mutable,system,0.0)==FrontierCrewNavigation.departure_obstacles(mutable.manifest,system,world.crew.navigation.orbit_time,0),"mutable world cannot reuse an immutable world's collision cache")
	check(FrontierSpaceCombat.begin(world,"crew","local_transit"),"encounter starts")
	var r:=FrontierSpaceCombat.record(world);r.encounter.warning=100.0;r.encounter.resume=0.0
	var writes: Dictionary={"periodic":0,"durable":0}
	authority.save_world=func(_w):writes.durable+=1;return true
	authority.save_flight_checkpoint=func(_w):writes.periodic+=1;return true
	for i in 21:authority.step_flight_combat(.1)
	check(writes.periodic==1 and writes.durable==0,"routine combat checkpoint uses the bounded worker path")
	for enemy in r.encounter.enemies:enemy.hull=0
	authority.step_flight_combat(.1)
	check(writes.durable==1 and r.encounter.phase=="victory","confirmed combat outcome retains a synchronous durable save")
	r.encounter.phase="warning";r.encounter.warning=100.0
	for enemy in r.encounter.enemies:enemy.hull=100
	authority.save_flight_checkpoint=func(_w):return false
	authority.flight_combat_checkpoint=2.0;authority.step_flight_combat(.1)
	check(authority.stopped and not authority.error.is_empty(),"checkpoint submission failure stops the host explicitly")
	print("PIRATE_PERFORMANCE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
