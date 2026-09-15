extends SceneTree
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures+=1;printerr("FAIL "+label)
 else:print("PASS "+label)
func run() -> void:
 var world:=FrontierWorldStore.new("/tmp/playtest-space-scan/world.json").read_state()
 if world.is_empty():quit(2);return
 var nav: Dictionary=world.crew.navigation;nav.erase("solar_opening");nav.mode="approach";nav.speed=2000;nav.energy=100;nav.hull=100
 var target: int=nav.target;var direction: Array=nav.direction.duplicate()
 FrontierCrewNavigation.steer(world,[0,0,0,1,0,0,0,0,0,0,0,0],.2)
 check(nav.boosting and nav.energy<100 and nav.mode=="approach","automatic approach accepts boost and charges energy")
 check(nav.target==target and nav.direction==direction,"boost retains target and guidance")
 var boost:=FrontierCrewNavigation.approach_speed(world,900,100000,500,.1)
 FrontierCrewNavigation.steer(world,[0,0,0,0,0,0,0,0,0,0,0,0],.2)
 var normal:=FrontierCrewNavigation.approach_speed(world,900,100000,500,.1)
 check(not nav.boosting and boost>normal,"release returns to regular approach speed")
 check(FrontierCrewNavigation.approach_speed(world,900,1,500,.1)<=sqrt(1000.0),"close arrival clamps braking even from high speed")
 check(not FrontierFlightTelemetry.speed_label({"mode":"jump","speed":700,"jump_left":8,"transit":{"progress":.5}}).contains("m/s"),"interstellar UI reports approximate multiples of light speed")
 print("APPROACH_BOOST failures ",failures);quit(1 if failures else 0)
