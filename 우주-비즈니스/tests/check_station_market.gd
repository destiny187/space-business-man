extends SceneTree
var core: FrontierCrewAuthority
var disk_ok:=true
var checks:=0
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;printerr("FAIL: "+message)
func persist(world: Dictionary) -> bool:
 var error:=FrontierUniverse.validate_world(world)
 if not error.is_empty():printerr(error)
 return disk_ok and error.is_empty()
func request(kind: String,args: Dictionary={},peer: int=1) -> Dictionary:
 return core.request(peer,{"session_id":core.session_id,"sequence":int(core.world.crew.members[core.peers[peer]].last_sequence)+1,"revision":core.world.crew.revision,"kind":kind,"args":args})
func run() -> void:
 core=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(61739),FrontierPlayerProfile.new_character("정거장 검사"),persist),"world start")
 check(request("start_game").ok,"playing")
 var m: Dictionary=core.world.manifest
 check(FrontierSpaceStation.definition(m,0).is_empty(),"no solar station")
 check(FrontierSpaceStation.definition(m,FrontierUniverse.system_index(m,FrontierCrewNavigation.first_destination(m))).is_empty(),"no tutorial station")
 var index: int=-1
 for i in range(1,100):
  if not FrontierSpaceStation.definition(m,i).is_empty():index=i;break
 check(index>0,"station found")
 # Even a manually selected first interstellar destination suppresses its station.
 check(request("navigate",{"ordinal":FrontierUniverse.first_ordinal(m,index)}).ok,"select first route")
 request("ready",{"value":true});check(request("depart").ok,"first departure")
 FrontierCrewNavigation.step(core.world,12)
 check(core.snapshot().station.is_empty(),"actual first destination excludes station")
 for i in range(index+1,100):
  if not FrontierSpaceStation.definition(m,i).is_empty():index=i;break
 var nav: Dictionary=core.world.crew.navigation
 nav.system=index;nav.mode="idle";nav.manual=true;nav.speed=0
 var station:=FrontierSpaceStation.definition(m,index)
 nav.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(station.position)+Vector3(0,0,1100));core.world.flight_position=nav.position.duplicate()
 core.world.business=FrontierExpeditionBusiness.create();core.world.business.credits=20000
 var owner: String=core.peers[1]
 core.world.business.bags[owner]=FrontierExpeditionBusiness.inventory();core.world.business.bags[owner].iron=10
 check(request("station_buy",{"item":"iron","amount":3}).ok,"buy supply")
 check(int(FrontierExpeditionBusiness.bag(core.world,owner).iron)==13,"supply delivered")
 var stock:=int(core.snapshot().station.stock.iron)
 var credits:=int(core.world.business.credits)
 check(request("station_sell",{"item":"iron","amount":2}).ok,"sell supply")
 check(int(core.snapshot().station.stock.iron)==stock+2 and int(core.world.business.credits)>credits,"sale updates stock and funds")
 var receipt: Dictionary={"session_id":core.session_id,"sequence":int(core.world.crew.members[owner].last_sequence)+1,"revision":core.world.crew.revision,"kind":"station_buy","args":{"item":"iron","amount":1}}
 check(core.request(1,receipt).ok,"transaction committed")
 var committed:=FrontierUniverse.fingerprint(core.world)
 check(core.request(1,receipt).ok and committed==FrontierUniverse.fingerprint(core.world),"duplicate network request spends and grants only once")
 var original_bag: Dictionary=core.world.business.bags[owner].duplicate()
 core.world.business.bags[owner].stone=FrontierItemInventory.limit()
 var full:=FrontierUniverse.fingerprint(core.world)
 check(not request("station_buy",{"item":"iron","amount":1}).ok and full==FrontierUniverse.fingerprint(core.world),"full inventory rejects before charging")
 core.world.business.bags[owner]=original_bag
 var before:=FrontierUniverse.fingerprint(core.world)
 check(not request("station_buy",{"item":"iron","amount":-1}).ok and before==FrontierUniverse.fingerprint(core.world),"negative quantity is atomic")
 disk_ok=false
 check(not request("station_buy",{"item":"iron","amount":1}).ok and before==FrontierUniverse.fingerprint(core.world),"save failure rolls back trade")
 disk_ok=true
 var ship_id: String=""
 for id in core.snapshot().station.stock:
  if id.begins_with("hull:"):ship_id=id
 check(request("station_buy",{"item":ship_id}).ok,"buy ship")
 var hull_id:=ship_id.trim_prefix("hull:")
 check(core.world.vessel.hull=="kestrel" and hull_id in core.world.vessel.hulls,"ship stored before replacement")
 var module:=FrontierVesselRefit.add_module(core.world.vessel,"drive","standard");core.world.vessel.loadout.propulsion=module
 check(request("station_equip",{"item":hull_id}).ok,"replace ship")
 check(core.world.vessel.loadout.propulsion==module and is_equal_approx(FrontierVesselRefit.stats(core.world).speed,float(FrontierSpaceStation.config().hulls[hull_id].speed)*1.1),"module and actual performance preserved")
 var saved: Dictionary=JSON.parse_string(JSON.stringify(core.world))
 check(FrontierUniverse.validate_world(saved).is_empty(),"save format valid")
 check(FrontierUniverse.fingerprint(FrontierSpaceStation.snapshot(saved))==FrontierUniverse.fingerprint(core.snapshot().station),"reloading does not reroll market")
 var guest:=FrontierPlayerProfile.new_character("방문자",1)
 check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"guest admitted")
 check(not request("station_sell",{"item":"iron","amount":1},2).ok,"guest cannot spend common account")
 nav=core.world.crew.navigation;nav.position=[0,20000,40000];core.world.flight_position=nav.position.duplicate()
 check(not request("station_buy",{"item":"iron","amount":1}).ok,"remote trade denied")
 for member in core.world.crew.members.values():member.ready=true
 check(request("station_approach").ok and FrontierFlightTelemetry.read(m,core.world.crew.navigation).name==station.name,"approach station with matching distance target")
 for i in 1200:
  if FrontierCrewNavigation.step(core.world,.1):break
 check(FrontierSpaceStation.available(core.world),"approach reaches safe trade distance")
 print("STATION MARKET: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
