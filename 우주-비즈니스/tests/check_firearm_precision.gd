extends "res://tests/check_ground_combat.gd"
class Body extends Node3D:
	var models: Array[Node3D]=[]
const Targets=preload("res://scripts/domain/firearm_targets.gd")
func run() -> void:
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	var member: Dictionary=core.world.crew.members[actor_id]
	core.inputs[1]={"expires":10000.0,"controls_enabled":true,"direction":Vector2.ZERO}
	member.loadout.slots[2]="fixture:laser_2"
	var gun:=FrontierEquipment.active(member);var state:=FrontierFirearms.ensure(member,gun)
	var origin:=FrontierCrewWorld.vector(member.position)+Vector3.UP*FrontierFirearms.eye(member)
	core.shot_obstacle_provider=func(_actor,_origin,_direction,reach):return reach
	var before:=float(core.world.incidents.records[robot_key].shield)
	var result:=command("surface_fire",{"item_id":gun.item_id,"aim":aim(),"ads":true})
	check(result.get("ok",false) and result.get("beam",false) and state.ammo==59,"laser spends one cell quantum")
	check(core.ballistics.count()==0 and core.gun_events.size()==1 and float(core.world.incidents.records[robot_key].shield)<before,"continuous beam endpoint and damage are host owned")
	var replay:=core.request(1,{"session_id":core.session_id,"sequence":serial,"revision":core.world.crew.revision,"kind":"surface_fire","args":{"item_id":gun.item_id,"aim":aim(),"ads":true}})
	check(replay.get("ok",false) and state.ammo==59 and core.gun_events.size()==1,"duplicate quantum has no extra damage, heat or event")
	for i in 15:
		FrontierFirearms.tick(member,.101)
		command("surface_fire",{"item_id":gun.item_id,"aim":[0,1,0],"ads":true})
	check(state.overheated and is_equal_approx(state.heat,1.0),"sustained laser enters heat lock")
	var ammo:=int(state.ammo);FrontierFirearms.tick(member,.11)
	result=command("surface_fire",{"item_id":gun.item_id,"aim":[0,1,0],"ads":true})
	check(result.get("code")=="overheated" and state.ammo==ammo,"heat lock rejects without spending ammunition")
	FrontierFirearms.tick(member,4.0)
	check(not state.overheated and state.heat<=float(gun.heat_unlock),"cooling unlocks independently of reserve")
	var stock:=FrontierExpeditionBusiness.bag(core.world,actor_id);stock.ammo_energy=3
	result=command("surface_reload",{"item_id":gun.item_id})
	FrontierFirearms.tick(member,float(result.get("duration",0))+.1)
	check(result.get("ok",false) and state.ammo==ammo+3 and stock.ammo_energy==0,"laser reload consumes finite partial reserve")
	check(FrontierFirearms.validate(member.loadout).is_empty(),"heat and reload state persist validly")
	var history:=preload("res://scripts/domain/firearm_history.gd").new()
	var box: Dictionary={"kind":"robot","id":robot_key,"transform":Transform3D(Basis.IDENTITY,origin+Vector3(0,0,-10)),"bounds":AABB(Vector3(-.5,-.5,-.5),Vector3.ONE),"zone":"body","weak":false}
	history.frames[actor_id]=[{"time":10.0,"body":core.world.location,"origin":origin,"rows":[box]}];history.issue(9,10.0)
	check(not history.authorized(9,actor_id,core.world.location,10.0,10.12,origin).is_empty(),"only issued recent host pose can rewind")
	check(history.authorized(9,actor_id,core.world.location,9.99,10.12,origin).is_empty() and history.authorized(9,actor_id,core.world.location,10.0,10.3,origin).is_empty(),"forged and expired pose stamps fall back to current simulation")
	check(history.authorized(9,actor_id,"other-body",10.0,10.12,origin).is_empty() and history.authorized(9,actor_id,core.world.location,10.0,10.12,origin+Vector3.RIGHT*4).is_empty(),"body change and teleport cannot reuse history")
	history.frames[actor_id][0].time=9.97
	check(history.authorized(9,actor_id,core.world.location,10.0,10.18,origin).is_empty(),"sample rounding never extends the 200 ms rewind limit")
	history.frames[actor_id][0].time=10.0
	core.peers[9]=actor_id;core.inputs[9]=core.inputs[1];core.firearm_history=history;core.now=10.12
	state.ammo=60;state.reload_left=0;state.cooldown=0;state.heat=0;state.overheated=false
	serial+=1
	result=core.firearm_command(9,{"sequence":serial,"kind":"surface_fire","args":{"item_id":gun.item_id,"aim":[0,0,-1],"ads":true,"view_time":10.0}})
	check(result.get("ok",false) and is_equal_approx(float(result.get("rewind_seconds",0)),.12) and float(result.hits.shield)+float(result.hits.damage)>0,"delayed beam hits a historical moving target")
	state.cooldown=0;core.shot_obstacle_provider=func(_actor,_origin,_direction,reach):return minf(5,reach)
	serial+=1;result=core.firearm_command(9,{"sequence":serial,"kind":"surface_fire","args":{"item_id":gun.item_id,"aim":[0,0,-1],"ads":true,"view_time":10.0}})
	check(result.get("ok",false) and float(result.hits.shield)+float(result.hits.damage)==0,"current cover blocks rewound target")
	member.loadout.slots[2]="fixture:pulse_2";gun=FrontierEquipment.active(member);state=FrontierFirearms.ensure(member,gun);state.cooldown=0
	core.shot_obstacle_provider=func(_actor,_origin,_direction,reach):return reach
	serial+=1;result=core.firearm_command(9,{"sequence":serial,"kind":"surface_fire","args":{"item_id":gun.item_id,"aim":[0,0,-1],"ads":true,"view_time":10.0}})
	core.ballistics.history=history
	var impacts:=core.ballistics.step(core.world,.016,core.shot_obstacle_provider)
	check(result.get("ok",false) and impacts.size()==1 and core.ballistics.count()==0,"finite-speed bullet catches up through historical swept segments")
	# Shape extraction and animated bone transforms from a real exported skin.
	var rig: Node3D=load("res://assets/models/equipment/firearm_hand_left.glb").instantiate();root.add_child(rig)
	var meshes:=rig.find_children("*","MeshInstance3D",true,false);var skin: Skeleton3D=rig.find_children("*","Skeleton3D",true,false)[0]
	var boxes: Array=preload("res://scripts/domain/firearm_anatomy.gd")._build(meshes[0],skin)
	check(boxes.size()>=17 and boxes.any(func(b):return skin.get_bone_name(b.bone)=="upper_arm"),"generic hit volumes extracted from every weighted joint")

	var runtime: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/creature_remodel_runtime.json"))
	var form:=FrontierEcologyCatalog.form(runtime.enabled_ground_species[0])
	var critter:=Body.new();root.add_child(critter)
	var model: Node3D=load(preload("res://scripts/actors/creatures/remodel_registry.gd").path(form,"near")).instantiate()
	critter.add_child(model);critter.models.append(model)
	var anatomy=preload("res://scripts/domain/firearm_anatomy.gd")
	anatomy.register("review:animal",critter)
	var start_time:=Time.get_ticks_usec();var shapes: Array=anatomy.shapes("review:animal")
	print("ANIMAL_SHAPE_SCHEDULE_MS ",(Time.get_ticks_usec()-start_time)/1000.0)
	for attempt in 100:
		if not shapes.is_empty():break
		await create_timer(.01).timeout;shapes=anatomy.shapes("review:animal")
	print("ANIMAL_SHAPE_WORKER_COMPLETE_MS ",(Time.get_ticks_usec()-start_time)/1000.0," BONES ",shapes.size())
	check(shapes.size()>5,"actual animal skin yields separate anatomical hit volumes")
	var bones: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	bones.set_bone_pose_position(1,bones.get_bone_pose_position(1)+Vector3.RIGHT*.5)
	var moved: Array=anatomy.shapes("review:animal");var changed:=false
	for index in mini(shapes.size(),moved.size()):
		if shapes[index].transform.origin.distance_to(moved[index].transform.origin)>.2:changed=true
	check(changed,"animal damage shapes follow actual animated bone pose")
	anatomy.unregister("review:animal",critter)
	check(anatomy.shapes("review:animal").is_empty(),"unloaded creatures leave no stale target registration")
	critter.queue_free();rig.queue_free();await process_frame
	print("FIREARM_PRECISION_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
