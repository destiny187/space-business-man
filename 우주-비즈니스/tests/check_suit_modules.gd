extends "res://tests/check_exploration_discoveries.gd"
var core: FrontierCrewAuthority
var actor: String
func action(kind: String,id: String="") -> Dictionary:
 return request(core,1,"suit_module",{"action":kind,"id":id,"revision":int(FrontierSuitModules.state(core.world.crew.members[actor]).get("revision",0))})
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("모듈 확인",0);actor=owner.character_id
 core=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,persist),"start")
 check(request(core,1,"start_game").ok,"game")
 check(land_fixture(core,11),"land")
 core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory();core.world.business.bags[actor].iron=12;core.world.business.bags[actor].copper=8
 var r:=action("starter");check(r.ok,"starter "+str(r));check(not action("starter").ok,"single starter")
 r=action("equip","module:starter");check(r.ok,"equip "+str(r))
 var m: Dictionary=core.world.crew.members[actor];var v:=FrontierCrewVitals.ensure(m)
 check(v.shield==0 and v.shield_wait>0,"equip grants no instant shield")
 for i in 120:FrontierCrewVitals.step(m,.1,false,false)
 check(is_equal_approx(v.shield,30),"shield charged")
 var health: float=v.health
 FrontierCrewVitals.damage(m,20)
 check(is_equal_approx(v.shield,10) and v.health==health,"shield absorbs")
 FrontierCrewVitals.damage(m,16)
 check(v.shield==0 and is_equal_approx(v.health,health-6),"overflow health")
 check(v.shield_break_serial==1,"break once")
 FrontierCrewVitals.step(m,1,false,false);check(v.shield==0,"wait")
 v.shield=30;var before: float=v.health
 FrontierCrewVitals.land(m,float(FrontierCrewVitals.config().fall_safe_speed)+1)
 check(v.health<before and v.shield==30,"fall bypass existing passive")
 var same:=FrontierSuitModules.roll(881,3,"robot")
 check(same==FrontierSuitModules.roll(881,3,"robot"),"deterministic rolls")
 var types: Dictionary={};var rarities: Dictionary={}
 for tier in range(1,4):
  for i in 90:
   var item:=FrontierSuitModules.roll(i,tier,"discovery");types[item.slot]=true;rarities[item.rarity]=true
   var rack:=FrontierSuitModules.create();rack.items["module:test"]=item
   check(FrontierSuitModules.validate(rack),"roll validates T%d seed%d"%[tier,i])
 check(types.size()==6 and rarities.size()==5,"all types/rarities")
 check(not FrontierSuitModules.config().stats.has("fall_guard"),"no falling affix")
 check(FrontierSuitModules.drop(core.world,actor,"fixture:T3",3,"robot").is_empty(),"T3 field reward")
 var id: String="module:"+"fixture:T3".sha256_text().substr(0,24)
 check(core.world.crew.members[actor].modules.items[id].tier==3,"T3 actual item")
 check(not FrontierSuitModules.drop(core.world,actor,"fixture:T3",3,"robot").is_empty(),"duplicate source rejected")
 var rack: Dictionary=core.world.crew.members[actor].modules
 var bag_item: Dictionary={"slot":"storage","tier":3,"rarity":"common","affixes":{},"seed":0,"source":"fixture"};rack.items["module:bag"]=bag_item
 check(action("equip","module:bag").ok,"bag equip")
 m=core.world.crew.members[actor]
 core.world.business.bags[actor].iron=100*10
 check(not action("unequip","module:bag").ok,"capacity-safe bag removal")
 core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 check(action("unequip","module:bag").ok,"bag removal after storage")
 check(not action("salvage","module:starter").ok,"no equipped salvage")
 check(action("salvage",id).ok,"salvage optional duplicate")
 var old:=JSON.stringify(core.world)
 disk_ok=false;check(not action("unequip","module:starter").ok,"save failure rejected");check(JSON.stringify(core.world)==old,"save failure atomic");disk_ok=true
 check(persist(core.world),"save")
 check(FrontierUniverse.validate_world(saved).is_empty(),"JSON reload validation")
 var loaded:=FrontierCrewAuthority.new();check(loaded.start(saved,owner,persist),"reconnect world")
 check(JSON.parse_string(JSON.stringify(loaded.world.crew.members[actor].modules))==JSON.parse_string(JSON.stringify(core.world.crew.members[actor].modules)),"ownership/roll retained")
 print("MODULE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
