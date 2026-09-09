extends "res://tests/test_crew_surface.gd"
var effects: Dictionary={}
func person() -> Dictionary:
 var m:=FrontierCrewWorld.member(FrontierPlayerProfile.new_character("전설 확인",0),"",0)
 m.area="surface";m.aboard=false;m.position=[100,0,100];FrontierSuitModules.ensure(m);FrontierCrewVitals.ensure(m)
 m.modules.items["module:shield"]={"slot":"defense","tier":1,"rarity":"common","affixes":{},"seed":0,"source":"starter"};m.modules.equipped.defense="module:shield"
 return m
func equip(m: Dictionary,effect: String) -> void:
 var item: Dictionary=effects[effect].duplicate(true);var id: String="module:"+effect
 m.modules.items[id]=item;m.modules.equipped[item.slot]=id
func run() -> void:
 var rarities: Dictionary={}
 for i in 18000:
  var item:=FrontierSuitModules.roll(i,3,"discovery");rarities[item.rarity]=true
  if item.has("legendary") and not effects.has(item.legendary):effects[item.legendary]=item
  if effects.size()==FrontierSuitModules.config().legendary.size():break
 check(effects.size()==11 and rarities.size()==5,"all 11 naturally rollable effects and 5 grades")
 if effects.size()!=11:quit(1);return
 for effect in effects:
  var m:=person();equip(m,effect)
  check(FrontierSuitModules.validate(m.modules),"valid legendary "+effect)
  check(FrontierSuitModules.roll(int(effects[effect].seed),3,"discovery")==effects[effect],"fixed legendary roll "+effect)
  check(not FrontierSuitModules.effect_text(effects[effect]).is_empty(),"visible effect "+effect)
 var m:=person();equip(m,"field_regeneration");m.vitals.health=50
 var maximum:=FrontierCrewAugmentation.maximum_health(m)
 FrontierSuitModules.enter_combat(m);FrontierCrewVitals.step(m,7,false,false);check(m.vitals.health==50,"no combat healing")
 FrontierCrewVitals.step(m,2,false,false);check(is_equal_approx(m.vitals.health,50+maximum*.01),"one peaceful second heals")
 FrontierSuitModules.enter_combat(m);check(m.vitals.combat_wait==8,"own attack resets combat timer")
 var split:=FrontierCrewVitals.split_shield_damage(100,40,1.5);check(split.absorbed==60 and split.health==0,"50 percent extra shield damage")
 split=FrontierCrewVitals.split_shield_damage(30,40,1.5);check(split.absorbed==30 and split.health==20,"bonus does not leak into health")
 split=FrontierCrewVitals.split_shield_damage(0,40,1.5);check(split.health==40,"unshielded health unchanged")
 m=person();equip(m,"fall_cushion");m.augmentation.levels.fall_guard=1
 var normal:=m.duplicate(true);normal.modules.equipped.erase(effects.fall_cushion.slot)
 var speed:=float(FrontierCrewVitals.config().fall_safe_speed)+2
 FrontierCrewVitals.land(normal,speed);FrontierCrewVitals.land(m,speed)
 check(is_equal_approx(100-float(m.vitals.health),(100-float(normal.vitals.health))*.5),"fall residual halves after passive")
 var second: Dictionary=effects.fall_cushion.duplicate(true);second.slot="life" if second.slot=="drive" else "drive";m.modules.items["module:second"]=second;m.modules.equipped[second.slot]="module:second"
 m.vitals.health=100;FrontierCrewVitals.land(m,speed);check(is_equal_approx(100-float(m.vitals.health),(100-float(normal.vitals.health))*.5),"same legendary does not stack")
 m=person();equip(m,"break_dash");m.vitals.shield=1;var base:=FrontierSuitModules.factor(m,"mobility")
 FrontierCrewVitals.damage(m,5);check(m.vitals.shield_haste==4 and is_equal_approx(FrontierSuitModules.factor(m,"mobility"),base+.25),"break dash actual damage trigger")
 FrontierCrewVitals.step(m,4,false,false);check(is_equal_approx(FrontierSuitModules.factor(m,"mobility"),base),"dash expires")
 m=person();equip(m,"survey_charge");FrontierSuitModules.on_analysis(m);check(is_equal_approx(m.vitals.shield,FrontierSuitModules.shield_max(m)*.15),"new analysis restores shield")
 m=person();equip(m,"carrier_engine");m.vitals.stamina=80;FrontierCrewVitals.step(m,1,true,true,false,true);check(m.vitals.stamina==80,"carrying sprint free")
 FrontierCrewVitals.step(m,1,true,true,false,false);check(m.vitals.stamina<80,"normal sprint still costs")
 m=person();equip(m,"stationary_charge");m.vitals.shield_wait=20;FrontierCrewVitals.step(m,3,false,false,true);check(m.vitals.shield==0,"stationary does not bypass delay")
 m.vitals.shield_wait=0;FrontierCrewVitals.step(m,.1,false,false,true)
 check(is_equal_approx(m.vitals.shield,.1*8*2*FrontierSuitModules.factor(m,"shield_rate")),"stationary doubles charge")
 m=person();equip(m,"critical_recharge");m.vitals.health=10;FrontierCrewVitals.damage(m,1);check(is_equal_approx(m.vitals.shield_wait,3*(1-FrontierSuitModules.bonus(m,"shield_delay"))),"critical delay halves")
 m=person();equip(m,"overflow_relay");m.vitals.health=FrontierCrewAugmentation.maximum_health(m);FrontierCrewVitals.heal(m,10);check(m.vitals.shield==5,"overheal becomes half shield")
 m=person();equip(m,"kill_recovery");m.vitals.health=10;m.vitals.stamina=10;FrontierSuitModules.on_kill(m);check(is_equal_approx(m.vitals.health,10+FrontierCrewAugmentation.maximum_health(m)*.05) and m.vitals.stamina==30,"kill restores life and stamina")
 m=person();equip(m,"full_shield_power");check(FrontierSuitModules.full_shield_factor(m)==1,"empty shield no offense bonus");m.vitals.shield=FrontierSuitModules.shield_max(m);check(FrontierSuitModules.full_shield_factor(m)==1.2,"full shield offense bonus")
 var old:=FrontierSuitModules.create();old.items["module:old"]={"slot":"work","tier":2,"rarity":"epic","affixes":{"mining":.1,"combat":.05,"healing":.1},"seed":2,"source":"robot"};check(FrontierSuitModules.validate(old) and FrontierSuitModules.config().rarities.epic.name=="유니크","old epic preserved as unique")
 var invalid:=old.duplicate(true);invalid.items["module:old"].legendary="fall_cushion";check(not FrontierSuitModules.validate(invalid),"nonlegendary special rejected")
 var world:=FrontierUniverse.new_world(71491);var profile:=FrontierPlayerProfile.new_character("전설 저장",0);var core:=FrontierCrewAuthority.new();check(core.start(world,profile,persist),"world")
 var actor: String=profile.character_id
 for effect in effects:
  core.world.crew.members[actor].modules=FrontierSuitModules.create();equip(core.world.crew.members[actor],effect)
  check(persist(core.world),"save effect "+effect)
  check(FrontierUniverse.validate_world(saved).is_empty(),"reload effect "+effect)
 print("LEGENDARY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
