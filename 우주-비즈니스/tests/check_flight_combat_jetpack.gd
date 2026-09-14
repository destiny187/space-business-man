extends "res://tests/check_wildlife_combat.gd"
const Air=preload("res://scripts/domain/flying_wildlife.gd")
const BIRD="biota_bilateral_siphons_30"
func run() -> void:
 folder="/tmp/flight-combat-jetpack";DirAccess.make_dir_recursive_absolute(folder)
 check(fixture(),"isolated terrain fixture")
 if chosen.is_empty():quit(1);return
 var world: Dictionary=core.world;var member: Dictionary=world.crew.members[actor_id]
 var before_slots: Array=member.loadout.slots.duplicate()
 world.business.bags[actor_id]=FrontierExpeditionBusiness.inventory()
 var stock:=FrontierExpeditionBusiness.bag(world,actor_id)
 for id in FrontierEquipment.config().items.jetpack_2.cost:stock[id]=10
 var craft_reason:=FrontierEquipment.apply(world,actor_id,"equipment_craft",{"definition":"jetpack_2"})
 check(craft_reason.is_empty(),"T2 backpack recipe crafts with valid processed materials "+craft_reason)
 var pack: String="crafted:"+str(int(member.loadout.counter))
 check(FrontierEquipment.apply(world,actor_id,"equipment_equip",{"item_id":pack,"slot":0,"back":true}).is_empty() and FrontierEquipment.jetpack(member) and member.loadout.slots==before_slots,"back slot preserves equipped weapon slots")
 check(FrontierEquipment.validate(member.loadout).is_empty(),"owned back slot survives equipment validation")
 check(not FrontierEquipment.apply(world,actor_id,"equipment_equip",{"item_id":pack,"slot":0}).is_empty(),"backpack cannot replace a handheld tool")
 var saved: Dictionary=JSON.parse_string(JSON.stringify(member.loadout));saved.back_slot="not-owned"
 check(not FrontierEquipment.validate(saved).is_empty(),"reject unowned backpack in save")
 await jetpack_checks()
 var row:=chosen.duplicate();row.form_id=BIRD;row.look_id=FrontierEcologyCatalog.look_for_seed(BIRD,0);row.combat_tier=2
 row.point=home+Vector3(0,6,7);row.home_point=home
 world.crew.wildlife_encounters={};world.crew.combat={};world.crew.wildlife_stops={}
 var info:=FrontierWildlifeCombat.profile(row);info.nature="proactive"
 check(info.pattern=="aerial" and Air.eligible(FrontierEcologyCatalog.form(BIRD),row),"surface-air species enters host aerial combat")
 var live:=FrontierWildlifeCombat.ensure(world.crew,body.id,row);live.target=actor_id;live.yaw=0
 member.position=FrontierExplorationIncidents.array(home+Vector3(0,3,0));member.vitals.health=100;member.vitals.protection=0;member.vitals.shield=0
 FrontierWildlifeCombat.set_phase(live,"warning")
 var free:=func(_actor,_row,_from,_to,_radius,_height):return true
 # Crossing +PI during warning previously invalidated an otherwise valid save.
 live.yaw=3.13;member.position=FrontierExplorationIncidents.array(row.point+Vector3(.1,0,5))
 FrontierWildlifeCombat._step(world,row,live,info,[actor_id],field,.05,free)
 check(FrontierWildlifeCombat.valid(world.crew),"warning rotation across PI remains save-valid")
 member.position=FrontierExplorationIncidents.array(home+Vector3(0,3,0));live.yaw=0
 FrontierWildlifeCombat.set_phase(live,"warning")
 var phases: Dictionary={};var min_y:=INF;var max_y:=-INF;var attack_hits:=0;var last_serial:=-1;var damaged_serials: Dictionary={}
 var trace: Array=[]
 for frame in 480:
  var hp: float=member.vitals.health
  FrontierWildlifeCombat._step(world,row,live,info,[actor_id],field,.05,free)
  phases[live.phase]=true;var at:=FrontierCrewWorld.vector(live.position)
  min_y=minf(min_y,at.y);max_y=maxf(max_y,at.y)
  if member.vitals.health<hp:
   attack_hits+=1;damaged_serials[live.serial]=int(damaged_serials.get(live.serial,0))+1
  trace.append({"phase":live.phase,"at":live.position.duplicate(),"time":live.time,"health":member.vitals.health})
  if attack_hits>=2:break
 check(phases.has("chase") and phases.has("attack") and attack_hits>0,"warn approach and swept contact damage an airborne player")
 check(damaged_serials.values().all(func(n):return n==1),"one damage result per committed aerial attack")
 check(min_y>=home.y-.25 and max_y>home.y+3,"flight stays above terrain and reaches player height")
 # Cover callback blocks physical movement as well as the damage line.
 live.position=FrontierExplorationIncidents.array(home+Vector3(0,6,7));live.yaw=0;live.target=actor_id
 FrontierWildlifeCombat.set_phase(live,"chase");var hp: float=member.vitals.health
 for frame in 80:FrontierWildlifeCombat._step(world,row,live,info,[actor_id],field,.05,func(_a,_r,_f,_t,_w,_h):return false)
 check(member.vitals.health==hp,"blocked approach cannot damage through cover")
 info.nature="flee";FrontierWildlifeCombat.set_phase(live,"hurt")
 for frame in 8:FrontierWildlifeCombat._step(world,row,live,info,[actor_id],field,.05,free)
 check(live.phase=="flee","passive flier escapes after being hurt")
 FrontierWildlifeCombat.hit(world,actor_id,row,100000.)
 for frame in 160:FrontierWildlifeCombat._step(world,row,live,info,[actor_id],field,.05,free)
 var stopped:=FrontierCrewWorld.vector(live.position)
 check(live.phase=="down" and absf(stopped.y-Air.floor_at(field,stopped))<.02,"downed flier falls to terrain and stays down")
 var roundtrip: Dictionary=JSON.parse_string(JSON.stringify(world.crew))
 check(FrontierWildlifeCombat.valid(roundtrip),"aerial attack and landing records validate after JSON transport")
 FrontierWildlifeCombat.resume(roundtrip)
 check(roundtrip.wildlife_encounters.values()[0].phase=="down" and FrontierCrewWorld.vector(roundtrip.wildlife_stops.values()[0].position).distance_to(FrontierCrewWorld.vector(live.position))<.001,"save resume preserves downed location")
 FileAccess.open(folder+"/evidence.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"air_hits":attack_hits,"phases":phases,"trace":trace},"  "))
 print("FLIGHT_JETPACK ",checks," FAILURES ",failures);quit(1 if failures else 0)
func jetpack_checks() -> void:
 var floor_body:=StaticBody3D.new();root.add_child(floor_body);floor_body.position=Vector3(0,-.5,0)
 var ground_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,1,20);ground_shape.shape=box;floor_body.add_child(ground_shape)
 var pawn:=CharacterBody3D.new();root.add_child(pawn);pawn.position=Vector3(0,.02,0)
 var collider:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.height=1.8;capsule.radius=.3;collider.shape=capsule;collider.position.y=.9;pawn.add_child(collider)
 var motion:=FrontierCrewLocomotion.create();var gravity:=float(FrontierCrewSurface.config().gravity)
 for frame in 8:
  await physics_frame;FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,0,1./60.,true,0,0,1,false,true)
 for frame in 20:
  await physics_frame;FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,1,1./60.,true,0,0,1,true,true)
 check(not motion.jet_active and not motion.grounded,"holding initial jump does not engage jetpack")
 FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,1,1./60.,true,0,0,1,false,true)
 var start:=pawn.position.y
 for frame in 50:
  await physics_frame;FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,2,1./60.,true,0,0,1,true,true)
 check(motion.jet_active and pawn.position.y>start+1 and pawn.velocity.y>0,"second press and hold rises with collision movement")
 var charge: float=motion.jet_charge
 FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,2,1./60.,true,0,0,1,false,true)
 check(not motion.jet_active and motion.jet_charge==charge,"release immediately stops powered ascent and battery drain")
 FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,3,1./60.,false,0,0,1,true,true)
 check(not motion.jet_active,"disabled input cannot keep thrust active")
 FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,4,1./60.,true,0,0,1,true,false)
 check(not motion.jet_active,"removing backpack disables thrust")
 motion.jet_charge=0.;motion.jet_armed=true
 FrontierCrewLocomotion.step(pawn,motion,Vector2.ZERO,4,gravity,5,1./60.,true,0,0,1,true,true)
 check(not motion.jet_active and FrontierCrewLocomotion.valid(JSON.parse_string(JSON.stringify(motion))),"empty battery and new movement fields validate")
 pawn.queue_free();floor_body.queue_free()
