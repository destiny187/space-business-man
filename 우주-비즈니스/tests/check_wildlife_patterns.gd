extends "res://tests/check_wildlife_combat.gd"
const Attacks=preload("res://scripts/domain/wildlife_attacks.gd")
var live: Dictionary
var info: Dictionary
var member: Dictionary
var free:=func(_actor,_row,_from,_to,_radius,_height):return true
func reset_attack(kind: String,destination: Vector3) -> void:
	member.vitals.health=100;member.vitals.protection=0;member.position=FrontierExplorationIncidents.array(destination)
	core.world.crew.combat={};core.world.crew.wildlife_encounters={}
	live=FrontierWildlifeCombat.ensure(core.world.crew,body.id,chosen)
	info=FrontierWildlifeCombat.profile(chosen)
	if kind=="leap":info.merge(FrontierWildlifeCombat.config().anatomical_behaviors.felid,true)
	else:info.merge(FrontierWildlifeCombat.config().patterns[kind],true);info.pattern=kind
	live.target=actor_id;live.aim=[0,0,1];live.yaw=0
	FrontierWildlifeCombat.set_phase(live,"attack");Attacks.begin(live,info,destination,field,chosen)
func advance(seconds: float,obstacle: Callable=Callable()) -> void:
	for i in ceili(seconds/.05):FrontierWildlifeCombat._step(core.world,chosen,live,info,[actor_id],field,.05,free if not obstacle.is_valid() else obstacle)
func run() -> void:
	folder="/tmp/native-patterns";DirAccess.make_dir_recursive_absolute(folder)
	check(fixture(),"native terrain fixture for attack mechanics")
	if chosen.is_empty():quit(1);return
	member=core.world.crew.members[actor_id]
	reset_attack("ram",home+Vector3(0,0,5))
	advance(float(info.windup)-.1)
	check(FrontierCrewWorld.vector(live.position).distance_to(home)<.01 and member.vitals.health==100,"charge telegraph precedes movement and damage")
	advance(.8)
	check(FrontierCrewWorld.vector(live.position).distance_to(home)>2 and member.vitals.health<100,"charge travels and swept collision hits")
	var health_before:=float(member.vitals.health);advance(.2)
	check(member.vitals.health==health_before,"charge contact cannot repeatedly damage")
	reset_attack("ram",home+Vector3(0,0,5));member.position=FrontierExplorationIncidents.array(home+Vector3(4,0,5));advance(1.8)
	check(member.vitals.health==100 and absf(float(live.position[0])-home.x)<.01,"sidestep avoids nonhoming charge")
	reset_attack("ram",home+Vector3(0,0,5))
	var cover: Dictionary={"id":"fixture:cover","type":"combat_barricade","position":FrontierExplorationIncidents.array(home+Vector3(0,0,2.5)),"yaw":0.0}
	FrontierCombatCover.create(cover,0);cover.assembly_left=0;FrontierExpeditionBusiness.site(core.world).buildings[cover.id]=cover
	advance(1.8)
	check(live.attack.blocked and float(live.position[2])<home.z+2.5 and member.vitals.health==100,"crafted cover stops moving charge and protects player")
	var ram_row:=chosen.duplicate()
	for form in FrontierEcologyCatalog.all_forms():
		if form.get("construction","")=="bovid":ram_row.form_id=form.id;ram_row.look_id=FrontierEcologyCatalog.look_for_seed(form.id,0);break
	var before:=FrontierWildlifeCombat.health(ram_row)
	FrontierWildlifeCombat.hit(core.world,actor_id,ram_row,20)
	check(core.world.crew.combat[key]==before-27,"failed charge exposes counterattack damage window")
	FrontierExpeditionBusiness.site(core.world).buildings.erase(cover.id)
	reset_attack("leap",home+Vector3(0,0,4));advance(1.25)
	check(float(live.get("air_height",0))>1 and float(live.position[2])>home.z+1,"pounce moves through real elevated body position")
	var goal: Array=live.attack.goal.duplicate();member.position=FrontierExplorationIncidents.array(home+Vector3(4,0,4));advance(.5)
	check(member.vitals.health==100 and live.attack.goal==goal and float(live.get("air_height",0))==0,"leave fixed landing circle to dodge pounce")
	reset_attack("leap",home+Vector3(0,0,4));advance(1.75)
	check(member.vitals.health<100 and float(live.get("air_height",0))==0,"pounce damages only at landing")
	reset_attack("leap",home+Vector3(0,0,4));advance(1.25)
	FrontierWildlifeCombat.hit(core.world,actor_id,chosen,1000);advance(.5)
	check(live.phase=="down" and float(live.get("air_height",0))==0,"midair defeat falls to ground without floating corpse")
	reset_attack("slam",home+Vector3(0,0,-3));advance(1.55)
	check(member.vitals.health==75,"shockwave hits behind creature without frontal arc")
	reset_attack("slam",home+Vector3(0,0,3));advance(.8);member.position=FrontierExplorationIncidents.array(home+Vector3(0,0,5));advance(.75)
	check(member.vitals.health==100,"leave announced shockwave radius before impact")
	reset_attack("slam",home+Vector3(0,1.2,3));advance(1.55)
	check(member.vitals.health==100,"jump clears ground shockwave")
	reset_attack("scythe",home+Vector3(0,0,2));advance(1.0);health_before=member.vitals.health;advance(.65)
	check(health_before==88 and member.vitals.health==76,"two scythe swings have separate timed impacts")
	reset_attack("scythe",home+Vector3(0,0,2));advance(1.0);member.position=FrontierExplorationIncidents.array(home+Vector3(5,0,2));advance(.65)
	check(member.vitals.health==88,"retreat between scythe swings avoids second strike")
	check(not Attacks._enters_safe_zone(Vector3(18,0,0),Vector3(19,0,0)) and Attacks._enters_safe_zone(Vector3(23,0,0),Vector3(21,0,0)),"landing perimeter allows exit and blocks inward rush")
	check(FrontierWildlifeCombat.valid(core.world.crew),"extended attack state validates")
	FrontierWildlifeCombat.resume(core.world.crew)
	check(live.phase=="return" and not live.has("attack") and live.air_height==0,"reload cancels committed motion and air height")
	print("NATIVE_PATTERNS ",checks," FAILURES ",failures);quit(1 if failures else 0)
