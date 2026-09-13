extends "res://tests/check_ground_combat.gd"
const Targets=preload("res://scripts/domain/firearm_targets.gd")
const Draft=preload("res://scripts/persistence/world_draft.gd")
func run() -> void:
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	core.inputs[1]={"expires":10000.0,"controls_enabled":true,"direction":Vector2.ZERO}
	var member: Dictionary=core.world.crew.members[actor_id]
	var stock:=FrontierExpeditionBusiness.bag(core.world,actor_id)
	stock.copper=20;stock.crystal=10;stock["refined_iron"]=5
	for id in FrontierFirearms.config().ammunition:
		var recipe: Dictionary=FrontierFirearms.config().ammunition[id]
		check(not FrontierCatalog.entry("resources",id).is_empty(),"ammunition is transferable cargo "+id)
		for ingredient in recipe.cost:check(not FrontierCatalog.entry("resources",ingredient).is_empty(),"valid ammunition ingredient "+ingredient)
	var draft:=Draft.request(core.world,actor_id,"equipment_ammo_craft")
	check(is_same(draft.ecology,core.world.ecology) and is_same(draft.business.sites,core.world.business.sites) and not is_same(draft.business.bags[actor_id],stock),"ammo draft only copies owner and bag")
	var before_iron:=int(stock.iron)
	var result:=command("equipment_ammo_craft",{"ammunition":"ammo_light","batches":1})
	check(result.get("ok",false),"ammo crafted through durable host command: "+str(result))
	member=core.world.crew.members[actor_id];stock=FrontierExpeditionBusiness.bag(core.world,actor_id)
	check(stock.ammo_light==60 and stock.iron==before_iron-2,"recipe consumes exact materials and gives 60 rounds")
	var duplicate:=core.request(1,{"session_id":core.session_id,"sequence":serial,"revision":result.get("revision",core.world.crew.revision),"kind":"equipment_ammo_craft","args":{"ammunition":"ammo_light","batches":1}})
	check(not duplicate.get("ok",false) and stock.ammo_light==60,"changed duplicate cannot grant ammunition")
	var gun:=FrontierEquipment.active(member);var state:=FrontierFirearms.ensure(member,gun)
	check(state.ammo==gun.magazine,"legacy owned magazine preserved")
	state.ammo=0;stock.ammo_light=3
	result=command("surface_reload",{"item_id":gun.item_id})
	check(result.get("reload",false) and state.reload_rounds==3 and stock.ammo_light==0,"partial reload reserves only available three rounds")
	member.loadout.selected=0;FrontierFirearms.tick(member,.2)
	check(state.reload_left==0 and state.ammo==0 and state.reload_rounds==3,"switch cancels insertion and preserves reserved rounds")
	member.loadout.selected=2
	result=command("surface_reload",{"item_id":gun.item_id});FrontierFirearms.tick(member,result.get("duration",0)*.65)
	check(state.ammo==3 and state.reload_rounds==0 and state.reload_left>0,"magazine contact inserts reserved rounds before bolt finishes")
	FrontierFirearms.tick(member,3)
	check(state.ammo==3 and not command("surface_reload",{"item_id":gun.item_id}).get("ok",false),"reload cannot create finite ammo")
	# A buffered trigger must survive a pending checkpoint once, and still recheck controls.
	core._hold_candidate(core.world.duplicate(true))
	core.poll_autonomous=func():return 0
	core.finish_autonomous=func():return 1
	result=command("surface_fire",{"item_id":gun.item_id,"aim":aim(),"ads":true})
	check(result.get("pending",false) and core.queued_requests.size()==1,"pending save preserves one trigger")
	check(core.resolve_autonomous(true),"pending checkpoint resolves")
	core.pump_requests();member=core.world.crew.members[actor_id];state=member.loadout.weapon_states[gun.item_id]
	check(core.completed_requests.back().result.get("ok",false) and state.ammo==2,"buffered trigger consumes exactly one round after commit")
	var shield:=float(core.world.incidents.records[robot_key].shield)
	check(core.ballistics.count()==1,"host retains a travelling round")
	var impacts: Array=core.ballistics.step(core.world,.08,Callable())
	check(float(core.world.incidents.records[robot_key].shield)<shield and not impacts.is_empty(),"travel then swept robot shield impact")
	check(core.ballistics.count()==0,"impacted round retires")
	# Zone geometry is separated: empty space between legs is not a spherical body hit.
	var robot: Dictionary=core.world.incidents.records[robot_key];robot.shield=0
	var rows: Array=Targets.candidates(core.world,actor_id).filter(func(r):return r.id==robot_key)
	var transform:=Transform3D(Basis(Vector3.UP,float(robot.yaw)),FrontierCrewWorld.vector(robot.position))
	var head:=Targets.intersect(rows,transform*Vector3(0,1.95,3),-transform.basis.z,5)
	var limb:=Targets.intersect(rows,transform*Vector3(.34,.5,3),-transform.basis.z,5)
	var gap:=Targets.intersect(rows,transform*Vector3(0,.5,3),-transform.basis.z,5)
	check(head.get("zone")=="head" and limb.get("zone")=="limb" and gap.is_empty(),"distinct head/limb/gap intersections")
	robot.hp=100
	var h:=FrontierFirearms._damage(core.world,actor_id,head,10,gun,true)
	var l:=FrontierFirearms._damage(core.world,actor_id,limb,10,gun,true)
	check(h.damage==14 and l.damage==7.5,"head and limb damage differ")
	var plasma_id:="fixture:plasma_3";member.loadout.slots[2]=plasma_id
	var plasma:=FrontierEquipment.active(member);FrontierFirearms.ensure(member,plasma)
	var event:=FrontierFirearms.fire(core.world,actor_id,{"item_id":plasma_id,"aim":aim(),"ads":true,"ballistic":true,"serial":991})
	check(event.get("ok",false) and event.projectiles[0].gravity>0,"plasma is a finite-speed ballistic projectile")
	if event.get("ok",false):
		core.ballistics.launch(core.world,actor_id,plasma,event,true)
		check(core.ballistics.step(core.world,.05,Callable()).is_empty() and core.ballistics.count()>0,"plasma has visible travel delay")
		var point: Vector3=core.ballistics.shots[0].rounds[0].point
		check(point.y<FrontierCrewWorld.vector(event.origin).y+FrontierCrewWorld.vector(event.projectiles[0].velocity).y*.05,"gravity bends projectile")
		core.ballistics.shots.clear()
	member.loadout.slots[2]="fixture:pistol_1"
	var pistol:=FrontierEquipment.active(member);var pistol_state:=FrontierFirearms.ensure(member,pistol);pistol_state.ammo=0
	result=FrontierFirearms.begin_reload(member,pistol,{})
	FrontierFirearms.tick(member,4)
	check(result.get("reserve")==-1 and pistol_state.ammo==pistol.magazine and pistol.damage<gun.damage,"weak pistol reloads from infinite reserve")
	member.loadout.slots[2]=gun.item_id;state.ammo=1;FrontierFirearms.tick(member,2)
	var shot_args: Dictionary={"item_id":gun.item_id,"aim":aim(),"ads":true,"ballistic":true,"serial":992}
	event=FrontierFirearms.fire(core.world,actor_id,shot_args)
	core.ballistics.launch(core.world,actor_id,gun,event,true)
	shield=float(robot.hp)
	var wall:=func(_actor,origin,direction,reach):
		var plane:=FrontierCrewWorld.vector(event.origin)+FrontierCrewWorld.vector(event.projectiles[0].velocity).normalized()*1.0
		var normal:=FrontierCrewWorld.vector(event.projectiles[0].velocity).normalized()
		var distance: float=(plane-origin).dot(normal)/maxf(.001,direction.dot(normal))
		return distance if distance>=0 and distance<reach else reach
	impacts=core.ballistics.step(core.world,.1,wall)
	check(not impacts.is_empty() and robot.hp==shield and core.ballistics.count()==0,"fast bullet cannot tunnel through thin wall")
	stock=FrontierExpeditionBusiness.bag(core.world,actor_id);stock.ammo_light=2
	FrontierFirearms.tick(member,2);result=FrontierFirearms.begin_reload(member,gun,stock)
	DirAccess.make_dir_recursive_absolute("/tmp/firearm-upgrade-rules")
	var store:=FrontierWorldStore.new("/tmp/firearm-upgrade-rules/world.json")
	check(store.write(core.world),"save reserved ammunition: "+store.last_error)
	var saved:=store.read_state()
	check(not saved.is_empty() and saved.crew.members[actor_id].loadout.weapon_states[gun.item_id].reload_rounds==2,"reserved ammunition survives save/reload")
	print("FIREARM_UPGRADE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
