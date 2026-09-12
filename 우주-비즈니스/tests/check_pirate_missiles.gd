extends "res://tests/check_pirate_rules.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("곡선 유도 미사일과 이탈 확인",0);actor=owner.character_id
	check(authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host starts")
	world=authority.world;authority.phase="playing"
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:system=index;break
	stage();var r:=FrontierSpaceCombat.record(world)
	check(FrontierSpaceCombat.begin(world,"crew","local_transit"),"local ambush starts")
	check(r.encounter.enemies.map(func(e):return e.kind)==["raider","gunship","raider"],"formation consists of combat ships")
	var nav: Dictionary=world.crew.navigation;var origin:=FrontierSpaceCombat.point(nav.position)
	var enemy: Dictionary=r.encounter.enemies[0]
	enemy.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,-300))
	for i in [1,2]:r.encounter.enemies[i].position=FrontierSpaceCombat.arr(origin+Vector3(i*200,0,-650))
	r.encounter.warning=100.0
	var aim: Vector3=(FrontierSpaceCombat.point(enemy.position)-(origin+Vector3(0,19,62))).normalized()
	var before: float=enemy.hull+enemy.shield
	authority.input(1,1,[0,0],FrontierSpaceCombat.arr(aim),false,false,[0,0,0,0,0,1,1],0,false)
	FrontierSpaceCombat.tick(world,.1,authority.inputs,authority.peers,authority.now)
	check(r.encounter.projectiles.size()==2 and enemy.hull+enemy.shield==before,"secondary input launches a real missile without instant damage")
	check(not FrontierSpaceCombat.launch_missile(world,actor,aim),"missile reload prevents repeated launch")
	var left:=FrontierSpaceCombat.point(r.encounter.projectiles[0].velocity).normalized()
	var right:=FrontierSpaceCombat.point(r.encounter.projectiles[1].velocity).normalized()
	check(left.x<-.3 and right.x>.3,"paired missiles leave in visibly different outward directions")
	step(1.5)
	check(enemy.hull+enemy.shield<before and r.events.any(func(e):return e.kind=="missile_blast"),"homing salvo collides and emits an impact explosion")
	r.ships.crew.missile_cooldown=0
	before=enemy.hull+enemy.shield
	check(FrontierSpaceCombat.launch_missile(world,actor,aim),"second missile launches")
	var bolt: Dictionary=r.encounter.projectiles[-1];var ray:=FrontierSpaceCombat.point(bolt.velocity).normalized()
	enemy.position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(enemy.position)+Vector3(250,0,0))
	step(.8)
	check(FrontierSpaceCombat.point(bolt.velocity).normalized().dot(ray)<.99,"missile curves toward its locked target after fan-out")
	step(4.0)
	check(enemy.hull+enemy.shield<before and r.encounter.projectiles.is_empty(),"guided attack follows the original target and resolves through collision")
	check(FrontierSpaceCombat.valid(JSON.parse_string(JSON.stringify(r))),"missile cooldown and results serialize")
	r.ships.crew.missile_cooldown=0
	check(not FrontierSpaceCombat.launch_missile(world,actor,Vector3(0,.3,-1).normalized()) and r.ships.crew.missile_cooldown==0,"no target consumes neither missiles nor cooldown")
	enemy.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,-300));enemy.hull=1;enemy.shield=0
	for i in [1,2]:r.encounter.enemies[i].hull=0
	FrontierSpaceCombat.launch_missile(world,actor,aim);step(1.5)
	check(r.encounter.phase=="victory" and not r.encounter.projectiles.is_empty(),"a surviving salvo projectile keeps flying after its last target dies")
	step(4.0)
	check(r.encounter.is_empty(),"post-victory missile expires before encounter cleanup")

	r.encounter={};stage();r.serial+=1;FrontierSpaceCombat.begin(world,"crew","local_transit")
	r.encounter.phase="combat";r.encounter.warning=0;nav=world.crew.navigation
	var gunship: Dictionary=r.encounter.enemies[1]
	FrontierSpaceCombat.damage_enemy(world,gunship,500,origin,FrontierSpaceCombat.point(gunship.position));step(.1)
	check(r.encounter.phase=="combat" and r.encounter.enemies[0].hull>0,"destroying the missile ship does not end its living escorts' pursuit")
	r.encounter.elapsed=1000;step(.1)
	check(r.encounter.phase=="combat","standing still never grants a timed escape")
	check(not FrontierSpaceCombat.guard(world,actor,"depart",{}).is_empty(),"close-range departure is blocked")
	nav.direction=[0,0,1]
	var elapsed:=0.0
	for i in 150:
		sequence+=1;authority.now+=.1
		authority.input(1,sequence,[0,0],[0,0,1],false,false,[1,0,0,1,0,1,0],0,false)
		FrontierCrewNavigation.steer(world,[1,0,0,1],.1);FrontierCrewNavigation.step(world,.1)
		FrontierSpaceCombat.tick(world,.1,authority.inputs,authority.peers,authority.now);elapsed+=.1
		if FrontierSpaceCombat.can_jump(world):break
	check(FrontierSpaceCombat.can_jump(world) and elapsed<15,"actual boost movement opens a jump window away from pursuing fighters")
	check(nav.energy>=float(world.manifest.settings.flight.get("transit_energy_cost",30)),"boost preserves the energy needed for escape jump")
	check(r.encounter.phase=="combat" and nav.combat_active,"distance alone leaves the encounter active")
	var far_enemy: Dictionary=r.encounter.enemies[0];var old_position: Array=far_enemy.position.duplicate()
	far_enemy.position=nav.position.duplicate();check(not FrontierSpaceCombat.can_jump(world),"closing pursuit invalidates a stale jump window");far_enemy.position=old_position
	var target: int=-1
	for index in range(5000):
		if FrontierUniverse.map_position(world.manifest,index).distance_to(FrontierUniverse.map_position(world.manifest,int(nav.system)))>FrontierVesselRefit.stellar_range(world):continue
		var ordinal:=FrontierUniverse.first_ordinal(world.manifest,index)
		if index!=int(nav.system) and int(FrontierUniverse.body(world.manifest,ordinal).planet_tier)<=2:target=ordinal;break
	check(target>=0,"reachable alternate stellar route exists")
	if target>=0:
		check(FrontierCrewNavigation.apply(world,actor,"navigate",{"ordinal":target},authority.peers).is_empty(),"alternate system can be selected")
		authority.save_world=func(_w):return false
		var rejected:=authority.request(1,{"session_id":authority.session_id,"sequence":1000,"kind":"depart","args":{},"revision":world.crew.revision})
		check(not rejected.ok and world.crew.navigation.mode=="idle" and r.encounter.phase=="combat","failed save cannot publish jump or escape")
		authority.save_world=func(_w):return true
		var result:=authority.request(1,{"session_id":authority.session_id,"sequence":1001,"kind":"depart","args":{},"revision":world.crew.revision})
		world=authority.world;r=FrontierSpaceCombat.record(world);nav=world.crew.navigation
		check(result.ok and nav.mode=="jump" and r.encounter.phase=="escaped" and not nav.combat_active,"committed interstellar departure confirms escape")
		check(r.cooldown>0 and r.safe_journeys>0,"escaped route shares the encounter cooldown")
	print("MISSILE_BREAKOUT_CHECKS ",checks," FAILURES ",failures," BOOST_SECONDS ",elapsed)
	quit(1 if failures else 0)
