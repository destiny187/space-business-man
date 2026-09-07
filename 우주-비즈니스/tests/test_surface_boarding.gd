extends SceneTree
var failures:=0
var disk_ok:=true
var sequences: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func persist(world: Dictionary) -> bool:
 return disk_ok and FrontierUniverse.validate_world(world).is_empty()
func request(core: FrontierCrewAuthority,peer: int,kind: String) -> Dictionary:
 sequences[peer]=int(sequences.get(peer,0))+1
 return core.request(peer,{"session_id":core.session_id,"sequence":sequences[peer],"kind":kind,"args":{},"revision":core.world.crew.revision})
func run() -> void:
 var owner:=FrontierPlayerProfile.new_character("호스트",0)
 var guest:=FrontierPlayerProfile.new_character("승무원",1)
 var core:=FrontierCrewAuthority.new()
 check(core.start(FrontierUniverse.new_world(71491),owner,persist),"host world opens")
 var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
 check(admitted.ok and core.acknowledge(2,core.session_id).ok,"second crew admitted")
 core.phase="playing"
 var world: Dictionary=core.world
 var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
 while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
 var body:=FrontierUniverse.body(world.manifest,ordinal)
 world.location=body.id;world.navigation_target=body.id
 world.crew.navigation.system=23;world.crew.navigation.target=ordinal
 world.crew.landing={"body_id":body.id,"epoch":1}
 world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));world.terrain_settings_hash=FrontierUniverse.fingerprint(world.terrain_settings)
 if not world.has("ecology"):world.ecology=FrontierEcology.create()
 FrontierEcology.ensure_planet(world.ecology,body)
 for id in core.peers.values():FrontierCrewSurface.spawn_member(world,world.crew.members[id],0)
 var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
 core.update_position(1,ship+Vector3(100,0,0))
 check(not request(core,1,"surface_board").ok,"remote boarding rejected")
 core.update_position(1,ship)
 disk_ok=false
 check(not request(core,1,"surface_board").ok and not core.world.crew.members[owner.character_id].aboard,"failed save does not board or launch")
 disk_ok=true
 core.world.crew.pilot_id=guest.character_id
 check(request(core,1,"surface_board").ok and FrontierCrewSurface.landed(core.world),"host boarding waits for remaining crew")
 check(core.world.crew.pilot_id==owner.character_id,"returning host regains helm")
 check(not request(core,1,"surface_attack").ok,"boarded crew cannot perform surface actions")
 check(request(core,1,"surface_unboard").ok and not core.world.crew.members[owner.character_id].aboard,"boarding can be cancelled before launch")
 check(request(core,1,"surface_board").ok,"host boards again")
 core.update_position(2,ship)
 var profile: Dictionary=core.world.crew.members[owner.character_id].profile.duplicate(true)
 check(request(core,2,"surface_board").ok and not FrontierCrewSurface.landed(core.world),"last guest boarding launches automatically")
 check(core.world.crew.navigation.manual and core.world.crew.navigation.speed==0 and core.world.crew.navigation.system==23,"return is stationary manual flight in same system")
 check(core.world.crew.members[owner.character_id].profile==profile,"personal character and equipment retained")
 check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(core.world))).is_empty(),"launched world survives serialized validation")
 var point:=FrontierCrewWorld.vector(core.world.crew.navigation.position)
 FrontierCrewNavigation.steer(core.world,[1.0,0.0,0.0],.5)
 check(FrontierCrewWorld.vector(core.world.crew.navigation.position).distance_to(point)>1,"host can drive shared ship")
 # Remaining boarded crew can depart when an unboarded guest disconnects.
 core.world.crew.landing={"body_id":body.id,"epoch":2}
 for id in core.peers.values():FrontierCrewSurface.spawn_member(core.world,core.world.crew.members[id],0)
 core.update_position(1,ship);request(core,1,"surface_board")
 check(core.disconnect_member(2) and not FrontierCrewSurface.landed(core.world),"disconnected unboarded guest does not strand host")
 point=FrontierCrewWorld.vector(core.world.crew.navigation.position)
 FrontierCrewNavigation.steer(core.world,[1.0,0.0,0.0],.5)
 check(FrontierCrewWorld.vector(core.world.crew.navigation.position).distance_to(point)>1,"disconnected member does not block manual thrust")
 print("SURFACE BOARDING failures ",failures);quit(1 if failures else 0)
