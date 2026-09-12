extends "res://tests/check_pirate_rules.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("비행 공격 동작 확인",0);actor=owner.character_id
	authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);world=authority.world;authority.phase="playing"
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:system=index;break
	stage();FrontierSpaceCombat.begin(world,"crew","local_transit")
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter
	e.warning=.1
	var phases: Dictionary={};var min_clearance:=10000.0;var fired_during_charge:=false;var moved:=false;var crossed:=false
	for i in 140:
		var enemy: Dictionary=e.enemies[0];var old:=FrontierSpaceCombat.point(enemy.position)
		var was_align: bool=enemy.get("maneuver","")=="align" and enemy.windup>.15
		var serial: int=r.event_serial
		step(.1)
		phases[enemy.get("maneuver","")]=true
		min_clearance=minf(min_clearance,FrontierSpaceCombat.point(enemy.position).distance_to(FrontierSpaceCombat.point(world.crew.navigation.position)))
		if was_align:
			for event in r.events:
				if event.serial>serial and event.kind=="enemy_shot" and event.id==enemy.id:fired_during_charge=true
		if old.distance_to(FrontierSpaceCombat.point(enemy.position))>1:moved=true
		if enemy.get("maneuver","")=="strike" and (FrontierSpaceCombat.point(enemy.position)-FrontierSpaceCombat.point(world.crew.navigation.position)).z>50:crossed=true
	check(phases.has("approach") and phases.has("align") and phases.has("strike") and phases.has("break"),"host completes all four maneuver phases")
	check(moved and min_clearance>=84.9,"attack pass moves in space and clears the player hull")
	check(crossed,"raider attack passes beyond the target before banking away")
	check(not fired_during_charge,"locked preparation never applies an early shot")
	check(FrontierSpaceCombat.valid(r),"maneuver, velocity and in-flight projectile state validates")
	# A launched bolt is a swept host projectile, not delayed hitscan.
	var enemy: Dictionary=e.enemies[0];var center:=FrontierSpaceCombat.point(world.crew.navigation.position)
	enemy.position=FrontierSpaceCombat.arr(center+Vector3(0,0,-210));enemy.direction=[0.0,0.0,1.0];enemy.aim=FrontierSpaceCombat.arr(center)
	r.ships.crew.shield=100;e.projectiles=[]
	FrontierSpaceCombatPilot.launch(world,enemy,FrontierSpaceCombat.config().enemy.raider)
	check(e.projectiles.size()==1 and r.ships.crew.shield==100,"launch creates a visible bolt without immediate damage")
	world.crew.navigation.position=FrontierSpaceCombat.arr(center+Vector3.RIGHT*100)
	for i in 20:FrontierSpaceCombatPilot.projectiles(world,.1)
	check(r.ships.crew.shield==100 and e.projectiles.is_empty(),"moving off the frozen firing lane avoids the projectile")
	world.crew.navigation.position=FrontierSpaceCombat.arr(center)
	FrontierSpaceCombatPilot.launch(world,enemy,FrontierSpaceCombat.config().enemy.raider)
	for i in 10:FrontierSpaceCombatPilot.projectiles(world,.1)
	check(r.ships.crew.shield<100 and e.projectiles.is_empty(),"swept projectile hits a stationary shield once")
	var direction:=Vector3(.04,1,.02).normalized();var nav: Dictionary=world.crew.navigation
	nav.direction=FrontierSpaceCombat.arr(direction);enemy.position=FrontierSpaceCombat.arr(center+direction*120);enemy.shield=32;enemy.hull=100
	var camera_origin:=center+FrontierSpaceCombatPilot.basis(direction)*FrontierSpaceCombat.point(FrontierSpaceCombat.config().presentation.camera)
	var aim: Vector3=(FrontierSpaceCombat.point(enemy.position)-camera_origin).normalized()
	check(FrontierSpaceCombat.fire(world,actor,aim) and enemy.shield<32,"near-vertical camera aim converges at the actual target from the mounted muzzle")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(r));check(FrontierSpaceCombat.valid(restored),"active maneuver survives JSON save round-trip")
	FrontierSpaceCombat.resume(world);check(e.projectiles.is_empty() and e.resume>0,"resume removes stale bolts and retains the grace period")
	var old: Dictionary=restored.duplicate(true);old.encounter.erase("projectiles")
	for row in old.encounter.enemies:
		for key in ["maneuver","maneuver_age","maneuver_duration","velocity","roll","throttle","cycle","recoil","side","burst","pass_end","break_end"]:row.erase(key)
	check(FrontierSpaceCombat.valid(old),"earlier combat saves remain valid without maneuver extensions")
	print("PIRATE_MANEUVER_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
