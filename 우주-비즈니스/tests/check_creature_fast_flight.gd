extends SceneTree
class FlatField extends FrontierTerrainField:
 func height(_x: float,_z: float) -> float:return 0.
 func normal(_at: Vector3,_epsilon: float=.25) -> Vector3:return Vector3.UP
var checks:=0
func check(ok: bool,message: String) -> void:
 assert(ok,message);checks+=1;print("PASS ",message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var form:=FrontierEcologyCatalog.form("biota_bilateral_siphons_30")
 var actor:=preload("res://scripts/actors/creatures/bestiary_actor.gd").new()
 actor.load_far=false;actor.configure(form,{"scale":1.,"palette":form.palette});root.add_child(actor);actor.set_process(false)
 var view:=FrontierSurfaceEcology.new();view.body={"id":"fast-flight-fixture"};view.terrain=FrontierTerrainStreamer.new();view.terrain.field=FlatField.new()
 root.add_child(view);view.set_process(false)
 view.actors={"bird":actor};view.encounters={"bird":{"id":"bird","form_id":form.id,"point":Vector3.ZERO,"home_point":Vector3.ZERO,"yaw":0.,"status":"active"}}
 var seed_phase:=float(FrontierUniverse.derive(0,"flight:bird")%48000)/1000.
 for phase in [{"t":3.,"clip":"ground_idle_loop"},{"t":14.,"clip":"takeoff"},{"t":22.,"clip":"flight_loop"},{"t":46.,"clip":"landing"}]:
  view.flight_time=phase.t-seed_phase;view._update_flights(1./60.)
  actor.ground_motion.preview(1./60.);actor.ground_motion.tick(1./60.);actor.pose(true)
  check(actor.ground_motion.wanted_clip==phase.clip,"world path preserves "+str(phase.clip))
 view.flight_time=22.-seed_phase;view._update_flights(1./60.)
 var distance:=0.;var max_speed:=0.
 for frame in 60:
  var before:=actor.position;view.flight_time+=1./60.;view._update_flights(1./60.)
  distance+=actor.position.distance_to(before);max_speed=maxf(max_speed,actor.flight_speed)
  actor.ground_motion.preview(1./60.);actor.ground_motion.tick(1./60.);actor.pose(true)
 check(distance>.5 and max_speed<3. and not actor.ground_motion.driven,"world flight measures continuous displacement without ground follower")
 actor.flight_speed=float(actor.ground_motion.fast_profile.natural_speed)*1.18
 for i in 20:actor.ground_motion.preview(1./60.);actor.ground_motion.tick(1./60.);actor.pose(true)
 check(actor.ground_motion.wanted_clip=="sprint_loop","higher flight demand selects authored fast wing motion")
 view.encounters.bird.introduced=true
 view.flight_time=22.-seed_phase;view._update_flights(1./60.)
 check(actor.position.is_equal_approx(Vector3.ZERO) and not FrontierWildlifeCombat.Air.eligible(form,view.encounters.bird),"transported bird stays in its existing isolation plot without native combat")
 view.behavior_stopped=true;var clock: float=actor.ground_motion.phase
 view._update_flights(1./60.);actor.ground_motion.preview(1./60.);actor.ground_motion.tick(1./60.)
 check(actor.paused and actor.ground_motion.phase==clock,"pause freezes flight gait")
 view.actors.clear();view.terrain.free();view.free();actor.free()
 print("CREATURE_FAST_FLIGHT ",checks," FAILURES 0");quit()
