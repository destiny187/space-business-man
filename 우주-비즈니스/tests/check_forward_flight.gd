extends "res://tests/check_pirate_rules.gd"
func control(throttle: float=0,yaw: float=0,pitch: float=0,boost: float=0,roll_axis: float=0,brake: float=0,precision: float=0) -> Array:
	return [throttle,yaw,pitch,boost,0,1,0,roll_axis,brake,precision]
func fly(controls: Array,seconds: float) -> void:
	for i in ceili(seconds/.05):FrontierCrewNavigation.steer(world,controls,.05)
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("전진 비행 확인",0);actor=owner.character_id
	authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true);world=authority.world;authority.phase="playing"
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:system=index;break
	stage()
	var nav: Dictionary=world.crew.navigation
	var origin: Array
	var cargo: Dictionary=world.crew.cargo
	var revision: int=world.crew.revision
	fly(control(1),1);var speed:=float(nav.speed)
	fly(control(),1)
	check(speed>0 and is_equal_approx(float(nav.speed),speed),"W accelerates; neutral input preserves forward speed")
	fly(control(-1),3)
	check(nav.speed==0,"S stops without entering reverse")
	origin=nav.position.duplicate()
	var old_heading:=FrontierSpaceCombat.point(nav.direction)
	fly(control(0,0,0,0,1),PI/3.6)
	check(absf(FrontierCrewNavigation.orientation(nav).y.x)>.98 and old_heading.dot(FrontierSpaceCombat.point(nav.direction))>.999,"Q rolls the real ship axes without changing its heading")
	check(is_same(cargo,world.crew.cargo) and revision==int(world.crew.revision) and nav.position==origin,"one roll preserves unrelated cargo and transaction revision")
	fly(control(0,0,1),.35)
	check(absf(FrontierSpaceCombat.point(nav.direction).x)>.3,"pitch follows the rolled local axis")
	fly(control(0,0,1),5)
	check(FrontierCrewNavigation.validate(nav).is_empty() and absf(FrontierCrewNavigation.orientation(nav).determinant()-1)<.001,"continuous pitch passes both poles with valid orthonormal axes")
	fly(control(-1,0,0,0,0,0,1),1.5)
	check(is_equal_approx(float(nav.speed),-18),"Alt+S is limited to precision reverse")
	fly(control(),.2);check(nav.speed==0,"releasing precision mode brakes reverse to zero")
	nav.manual=false
	fly(control(0,0,0,1),1)
	check(nav.boosting and nav.manual and float(nav.speed)>0,"Shift enters manual forward boost without holding W")
	fly(FrontierCrewNavigation.stopped_input(),2)
	check(nav.speed==0 and not nav.boosting,"menu and expired-input control brakes and clears boost")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(nav))
	check(FrontierCrewNavigation.validate(restored).is_empty() and FrontierCrewNavigation.orientation(restored).is_equal_approx(FrontierCrewNavigation.orientation(nav)),"rolled orientation round-trips through saved navigation")
	check(authority.input(1,1,[0,0],[0,0,-1],false,false,control(0,0,0,0,1)) and not authority.input(1,1,[0,0],[0,0,-1],false,false,control()) and not authority.input(1,2,[0,0],[0,0,-1],false,false,control(0,0,0,0,2)),"network accepts roll, rejects duplicate and out-of-range input")
	stage();nav=world.crew.navigation;nav.erase("up")
	FrontierSpaceCombat.begin(world,"crew","local_transit")
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter;e.phase="combat";e.warning=0
	var forward:=true;var bounded:=true;var banks:=false;var shots: Dictionary={};var phases: Dictionary={};var clearance:=true
	for i in 360:
		for enemy in e.enemies:
			var before:=FrontierSpaceCombat.point(enemy.position);var heading:=FrontierSpaceCombat.point(enemy.direction)
			FrontierSpaceCombatPilot.step(world,enemy,.1)
			var shift:=FrontierSpaceCombat.point(enemy.position)-before
			if shift.length()>.01:forward=forward and shift.normalized().dot(FrontierSpaceCombat.point(enemy.direction))>.999
			bounded=bounded and heading.angle_to(FrontierSpaceCombat.point(enemy.direction))<.181
			banks=banks or absf(float(enemy.roll))>.2
			clearance=clearance and FrontierSpaceCombat.point(enemy.position).distance_to(FrontierSpaceCombat.point(nav.position))>=float(FrontierSpaceCombat.config().enemy[enemy.kind].pass_clearance)-.01
			phases[enemy.kind+":"+enemy.maneuver]=true
		FrontierSpaceCombatPilot.projectiles(world,.1)
		r.ships.crew.shield=100;nav.hull=100
		for event in r.events:
			if event.kind in ["enemy_shot","missile_launch"]:shots[event.id]=true
	check(forward and bounded and banks and clearance,"all enemy hulls move forward with bounded banked turns and physical clearance")
	check(shots.size()==3 and phases.has("raider:break") and phases.has("gunship:break"),"both fighters and missile ship attack, pass and reapproach")
	print("NATURAL_SHOTS ",shots," PHASES ",phases)
	check(FrontierSpaceCombat.valid(JSON.parse_string(JSON.stringify(r))),"enemy forward flight state survives validation and serialization")
	print("FORWARD_FLIGHT_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
