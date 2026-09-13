extends "res://tests/check_wildlife_combat.gd"
const Mobility=preload("res://scripts/domain/creature_mobility.gd")
const Attacks=preload("res://scripts/domain/wildlife_attacks.gd")
const IDS=["biota_spindle_armor_25","biota_lobopod_armor_26","bio_quill_amphora_01","biota_chain_armor_26","biota_ribbon_armor_26"]
func run() -> void:
 folder="/tmp/creature-fast-movement";DirAccess.make_dir_recursive_absolute(folder)
 check(fixture(),"host terrain fixture")
 if chosen.is_empty():quit(1);return
 var world: Dictionary=core.world;var member: Dictionary=world.crew.members[actor_id]
 var free:=func(_actor,_row,_from,_to,_radius,_height):return true
 var report: Array=[]
 for id in IDS:
  var row:=chosen.duplicate();row.form_id=id;row.look_id=FrontierEcologyCatalog.look_for_seed(id,0);row.combat_tier=5
  world.crew.wildlife_encounters={};world.crew.combat={}
  var info:=FrontierWildlifeCombat.profile(row);var p:=Mobility.profile(id)
  var scale_value:=float(FrontierEcologyCatalog.look(id,row.look_id).scale)
  var requested: Dictionary={"speed":12.,"behavior":"charge","charge_speed":24.,"charge_distance":8.}
  Mobility.apply(requested,id,scale_value)
  check(not p.is_empty() and requested.speed==12. and requested.charge_speed==24.,"animation preserves fast gameplay chase and charge speeds "+id)
  var live:=FrontierWildlifeCombat.ensure(world.crew,body.id,row);live.target=actor_id;live.yaw=0
  FrontierWildlifeCombat.set_phase(live,"chase")
  var previous:=home;var max_speed:=0.;var max_accel:=0.;var before_speed:=0.;var travel:=0.
  for frame in 24:
   FrontierWildlifeCombat.move(world,row,live,home+Vector3(0,0,16),info,field,.05,free,actor_id)
   var at:=FrontierCrewWorld.vector(live.position);var step:=Vector2(at.x-previous.x,at.z-previous.z).length()
   max_speed=maxf(max_speed,step/.05);max_accel=maxf(max_accel,(float(live.move_speed)-before_speed)/.05)
   before_speed=float(live.move_speed);travel+=step;previous=at
  check(travel>.15 and max_speed<=float(info.speed)+.015 and max_accel<=float(info.acceleration)+.015,"real chase respects gameplay speed and acceleration "+id)
  FrontierWildlifeCombat.set_phase(live,"flee")
  var max_turn:=0.
  for frame in 30:
   var yaw:=float(live.yaw)
   FrontierWildlifeCombat.move(world,row,live,home-Vector3(0,0,12),info,field,.05,free,actor_id)
   max_turn=maxf(max_turn,absf(wrapf(float(live.yaw)-yaw,-PI,PI)))
  check(max_turn<=float(info.turn_rate)*.05+.001 and cos(float(live.yaw))<-.5,"180-degree escape turns without instant reversal "+id)
  report.append({"species_id":id,"speed_cap":info.speed,"max_actual_mps":max_speed,"max_acceleration":max_accel,"max_turn_per_tick":max_turn})
 # Use the actual authored T5 charge profile, without overwriting it with old pattern defaults.
 var row:=chosen.duplicate();row.form_id=IDS[0];row.look_id=FrontierEcologyCatalog.look_for_seed(row.form_id,0);row.combat_tier=5
 world.crew.wildlife_encounters={};world.crew.combat={}
 var info:=FrontierWildlifeCombat.profile(row);var live:=FrontierWildlifeCombat.ensure(world.crew,body.id,row)
 live.target=actor_id;live.yaw=0;live.aim=[0,0,1]
 member.position=FrontierExplorationIncidents.array(home+Vector3(0,0,4));member.vitals.health=100;member.vitals.protection=0
 FrontierWildlifeCombat.set_phase(live,"attack");Attacks.begin(live,info,FrontierCrewWorld.vector(member.position),field,row)
 var prior:=home;var max_charge_speed:=0.
 for frame in ceili((float(info.windup)+float(info.active))/.025):
  FrontierWildlifeCombat._step(world,row,live,info,[actor_id],field,.025,free)
  var at:=FrontierCrewWorld.vector(live.position)
  max_charge_speed=maxf(max_charge_speed,Vector2(at.x-prior.x,at.z-prior.z).length()/.025);prior=at
  if member.vitals.health<100:break
 check(max_charge_speed<=float(info.charge_speed)+.03 and prior.distance_to(home)>.2 and member.vitals.health<100 and live.attack.blocked,"gameplay charge speed keeps actual swept hit and contact stop")
 check(absf(Attacks.charge_progress(info.active,info)-float(info.charge_distance))<.001,"ramped charge reaches previewed distance")
 live.motion_clock=2.;live.move_speed=1.
 var roundtrip: Dictionary=JSON.parse_string(JSON.stringify(world.crew))
 check(FrontierWildlifeCombat.valid(roundtrip),"new clocks and velocity survive JSON save/snapshot transport")
 FrontierWildlifeCombat.resume(roundtrip)
 var restored: Dictionary=roundtrip.wildlife_encounters.values()[0]
 check(restored.move_speed==0 and not restored.has("motion_clock") and not restored.has("attack"),"resume cancels transient charge and interpolation history")
 live.move_speed=-1
 check(not FrontierWildlifeCombat.valid(world.crew),"reject negative saved speed")
 FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"movement":report,"charge_max_mps":max_charge_speed,"charge_cap":info.charge_speed,"charge_contact_travel":prior.distance_to(home),"health_after_charge":member.vitals.health},"  "))
 print("CREATURE_FAST_MOVEMENT ",checks," FAILURES ",failures);quit(1 if failures else 0)
