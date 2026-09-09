extends SceneTree
class Basin extends FrontierTerrainField:
 var wall:=false
 func height(_x: float,_z: float) -> float:return 0.0
 func density(p: Vector3) -> float:return 1.0 if p.y<0 or (wall and p.z<-.8 and p.z> -1.2) else -1.0
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var field:=Basin.new();field.configure(42)
 var solver:=FrontierSurfaceWater.new();solver.configure(field);solver.original=field;solver.native=false;solver.record=FrontierSurfaceWater.create()
 for x in range(-4,5):
  for z in range(-4,5):
   for y in 2:solver.record.cells[FrontierSurfaceWater.key(Vector3i(x,y,z))]=[1.0,0.0]
 var hit:=solver.intersect(Vector3(0,3,0),Vector3(0,-1,-1).normalized(),8)
 check(not hit.is_empty() and absf(float(hit.position[1])-2)<.01 and hit.entering,"shot resolves first surface crossing to centimetres")
 field.wall=true;check(solver.intersect(Vector3(0,3,0),Vector3(0,-1,-1).normalized(),8).is_empty(),"rock before water suppresses splash")
 field.wall=false;check(solver.intersect(Vector3(0,3,0),Vector3.UP,8).is_empty(),"dry sky shot has no water hit")
 hit=solver.intersect(Vector3(0,1,0),Vector3.UP,8);check(not hit.is_empty() and not hit.entering,"underwater shot finds exit surface")
 solver.record=FrontierSurfaceWater.create();solver.rivers={"0:0":.12}
 check(is_equal_approx(solver.sample(Vector3(.2,.02,.2)),.1),"untouched shallow river uses analytic depth")
 var columns:=solver.columns_packet(Vector3.ZERO);check(columns.has("0:0") and columns.size()<=2401,"native column replica is bounded")
 var body:=CharacterBody3D.new();root.add_child(body);body.position=Vector3(100,10,100)
 var motion:=FrontierCrewLocomotion.create()
 FrontierCrewLocomotion.step(body,motion,Vector2.ZERO,6,14,0,.016,true,0)
 body.velocity.y=-8
 FrontierCrewLocomotion.step(body,motion,Vector2.RIGHT,6,14,0,.016,true,1.5)
 check(motion.state=="swim" and motion.water_serial==1 and motion.water_kind=="enter" and motion.water_impact>=8,"entry commits one contact with impact and swimming state")
 FrontierCrewLocomotion.step(body,motion,Vector2.ZERO,6,14,0,.1,true,1.0)
 check(motion.state=="tread" and motion.water_serial==1,"swim hysteresis keeps treading across small depth changes")
 for i in 20:FrontierCrewLocomotion.step(body,motion,Vector2.RIGHT,6,14,0,.016,true,2.0,-1.0)
 check(body.velocity.y<-.2,"looking down while moving dives against buoyancy")
 FrontierCrewLocomotion.step(body,motion,Vector2.ZERO,6,14,1,.016,true,2.0)
 check(body.velocity.y>2.5,"Space gives a swimming ascent impulse")
 FrontierCrewLocomotion.step(body,motion,Vector2.ZERO,6,14,1,.016,true,0)
 check(motion.water_serial==2 and motion.water_kind=="exit" and motion.state not in ["swim","tread"],"dry exit returns to ordinary locomotion once")
 check(FrontierCrewLocomotion.valid(motion),"water motion survives validated JSON transport")
 var bad:=motion.duplicate(true);bad.water_depth=-1;check(not FrontierCrewLocomotion.valid(bad),"invalid replicated depth rejected")
 bad=motion.duplicate(true);bad.water_shot={"serial":1,"point":[0,0,0],"entering":true};check(FrontierCrewLocomotion.valid(bad),"authoritative water shot event validates")
 var join:=FrontierCrewLocomotion.create();FrontierCrewLocomotion.step(body,join,Vector2.ZERO,6,14,0,.016,true,2)
 check(join.water_serial==0,"joining underwater does not fabricate an entry splash")
 var edge:=FrontierCrewLocomotion.create()
 for depth in [0.0,.03,.025,.02,.01,0.0]:FrontierCrewLocomotion.step(body,edge,Vector2.ZERO,6,14,0,.016,true,depth)
 check(edge.water_serial==0,"tiny waterline fluctuations do not fabricate entry or exit")
 var wade:=FrontierCrewLocomotion.create();wade.grounded=true
 FrontierCrewLocomotion.step(body,wade,Vector2.ZERO,6,14,1,.016,true,.3)
 for i in 5:FrontierCrewLocomotion.step(body,wade,Vector2.ZERO,6,14,1,.016,true,.3)
 check(wade.jump_serial==1,"shallow wading still allows a normal jump")
 body.queue_free();print("WATER_INTERACTIONS ",checks," FAILURES ",failures);quit(1 if failures else 0)
