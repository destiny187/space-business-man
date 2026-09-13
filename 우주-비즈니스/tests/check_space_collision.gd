extends "res://tests/check_pirate_rules.gd"
const Collision=preload("res://scripts/domain/space_collision.gd")
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("기체 충돌 재현",0);actor=owner.character_id
 check(authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host starts")
 world=authority.world;authority.phase="playing";system=1000;stage()
 check(FrontierSpaceCombat.begin(world,"crew","local_transit"),"encounter starts")
 var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter;e.phase="combat"
 var enemy: Dictionary=e.enemies[0]
 for other in e.enemies:
  if other!=enemy:other.hull=0
 var nav: Dictionary=world.crew.navigation;var origin:=FrontierSpaceCombat.point(nav.position)
 nav.direction=[0,0,-1];nav.speed=700;nav.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,-50))
 enemy.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,50));enemy.direction=[0,0,1];enemy.velocity=[0,0,700]
 var before: float=enemy.hull+enemy.shield;var shield: float=r.ships.crew.shield
 var inventory: Dictionary=world.manifest
 var starts: Dictionary={"crew":origin+Vector3(0,0,90),str(enemy.id):origin+Vector3(0,0,-90)}
 check(Collision.step(world,.2,starts),"swept fast crossing causes impact")
 check(enemy.hull+enemy.shield<before and r.ships.crew.shield<shield,"both hulls receive shield-first physical damage")
 var a:=FrontierSpaceCombat.point(nav.position);var b:=FrontierSpaceCombat.point(enemy.position)
 check(a.z>b.z,"head-on craft do not exchange sides or tunnel")
 check(float(nav.speed)<700 and FrontierSpaceCombat.point(enemy.velocity).z<0,"opposing impulse changes both velocities")
 check(is_same(inventory,world.manifest),"collision does not copy inventory or world")
 check(r.events.filter(func(event):return event.kind=="collision").size()==1,"one pair emits one collision")
 var hp: float=enemy.hull+enemy.shield
 nav.speed=0;nav.impact_velocity=[0,0,0];enemy.velocity=[0,0,0];enemy.impact_velocity=[0,0,0]
 Collision.step(world,.1,{"crew":a,str(enemy.id):b})
 check(enemy.hull+enemy.shield==hp,"resting separation does not repeatedly deal damage")
 check(Collision.contact(Vector3(-100,0,0),Vector3(100,60,0),Vector3(200,0,0),Vector3(-200,0,0),50)<0,"near miss preserves flight")
 check(Collision.contact(Vector3(-100,0,0),Vector3(100,0,0),Vector3(200,0,0),Vector3(-200,0,0),50)>=0,"continuous test catches subframe impact")
 check(FrontierSpaceCombat.valid(JSON.parse_string(JSON.stringify(r))),"collision state survives JSON reload")
 # The same host tick resolves two owned craft even with no pirate encounter.
 r.encounter={};r.hull_contacts={};stage()
 nav=world.crew.navigation;origin=FrontierSpaceCombat.point(nav.position)
 world.crew.shuttles={actor:{"state":"sortie","pad_slot":0,"progress":0.0,"factory_id":"","system":system,"location":world.location,"navigation_target":world.location,"navigation":nav.duplicate(true),"landing":{},"cargo":{"copper":3},"cargo_equipment":{},"rock":0}}
 world.crew.members[actor].shuttle_id=actor
 var shuttle: Dictionary=world.crew.shuttles[actor].navigation
 nav.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,12));nav.speed=0;nav.impact_velocity=[0,0,0]
 shuttle.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,-12));shuttle.direction=[0,0,1];shuttle.speed=0
 FrontierSpaceCombat.tick(world,.05,authority.inputs,authority.peers,authority.now)
 var crew_center:=FrontierSpaceCombat.point(nav.position)+FrontierCrewNavigation.orientation(nav)*FrontierSpaceCombat.point(Collision.shape("kestrel").center)
 shuttle=world.crew.shuttles[actor].navigation
 var shuttle_center:=FrontierSpaceCombat.point(shuttle.position)+FrontierCrewNavigation.orientation(shuttle)*FrontierSpaceCombat.point(Collision.shape("finch").center)
 check(crew_center.distance_to(shuttle_center)>=float(Collision.shape("kestrel").radius)+float(Collision.shape("finch").radius),"ordinary host tick separates shared ship and FINCH outside combat")
 check(world.crew.shuttles[actor].cargo.copper==3,"FINCH collision preserves its cargo")
 shuttle.system=system+1;shuttle.position=nav.position.duplicate()
 var remote: Array=shuttle.position.duplicate()
 Collision.step(world,.05,{})
 check(world.crew.shuttles[actor].navigation.position==remote,"craft in different systems cannot collide")
 check(FrontierCrewNavigation.validate(JSON.parse_string(JSON.stringify(nav))).is_empty(),"navigation impact velocity reloads through its own validator")
 # A fatal collision outside a pirate encounter must not strand its pilot.
 world.crew.members[actor].erase("shuttle_id");world.crew.shuttles={};nav=world.crew.navigation
 nav.hull=1;FrontierSpaceCombat.ship_state(world,"crew").shield=0
 Collision.apply_damage(world,{"player":true,"id":"crew","row":nav},20,FrontierSpaceCombat.point(nav.position)+Vector3.RIGHT)
 check(nav.hull==0 and nav.get("impact_recovery_left",0)>0,"fatal non-combat impact starts basic recovery")
 for i in 70:FrontierCrewNavigation.step(world,.1)
 check(nav.hull>=float(FrontierSpaceCombat.config().recovery_hull) and not nav.has("impact_recovery_left") and not nav.combat_recovery,"non-combat recovery restores control without cargo loss")
 print("SPACE_COLLISION ",checks," FAILURES ",failures);quit(1 if failures else 0)
