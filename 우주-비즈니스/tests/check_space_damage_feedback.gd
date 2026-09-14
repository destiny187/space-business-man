extends "res://tests/check_pirate_rules.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("우주 피해 확인",0);actor=owner.character_id
	authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true)
	world=authority.world;authority.phase="playing"
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=2:system=index;break
	stage();FrontierSpaceCombat.begin(world,"crew","stellar_arrival")
	var r:=FrontierSpaceCombat.record(world);var enemy:Dictionary=r.encounter.enemies[0]
	var at:=FrontierSpaceCombat.point(enemy.position);var source:=at+Vector3.BACK*100
	enemy.shield=10.0;enemy.hull=20.0
	FrontierSpaceCombat.damage_enemy(world,enemy,6,source,at)
	check(r.events.back().damage=={"hull":0.0,"shield":6.0,"killed":false},"shield hit publishes actual absorbed damage")
	FrontierSpaceCombat.damage_enemy(world,enemy,9,source,at)
	check(r.events.back().kind=="break" and r.events.back().damage=={"hull":5.0,"shield":4.0,"killed":false},"shield break reports shield and hull separately")
	var serial:int=r.event_serial
	FrontierSpaceCombat.damage_enemy(world,enemy,30,source,at,true)
	check(r.event_serial==serial,"shield-only attack on empty shield creates no false hit")
	FrontierSpaceCombat.damage_enemy(world,enemy,1000,source,at)
	check(r.events[-2].damage=={"hull":15.0,"shield":0.0,"killed":true},"overkill number is capped at remaining hull")
	serial=r.event_serial;FrontierSpaceCombat.damage_enemy(world,enemy,10,source,at)
	check(r.event_serial==serial,"dead enemy cannot publish duplicate damage")
	FrontierSpaceCombat.ship_state(world,"crew").shield=4
	world.crew.navigation.hull=3
	FrontierSpaceCombat.damage_ship(world,"crew",100,source)
	check(r.events.back().damage=={"hull":3.0,"shield":4.0,"killed":true},"own ship feedback uses actual shield and hull loss")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(r))
	check(FrontierSpaceCombat.valid(saved),"new damage fields survive JSON validation")
	saved.events.back().damage.hull=-1
	check(not FrontierSpaceCombat.valid(saved),"negative damage field rejected")
	for event in saved.events:event.erase("damage")
	check(FrontierSpaceCombat.valid(saved),"legacy events without damage stay valid")
	print("SPACE_DAMAGE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
