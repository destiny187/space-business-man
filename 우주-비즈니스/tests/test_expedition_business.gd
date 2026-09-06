extends "res://tests/test_crew_surface.gd"
var core: FrontierCrewAuthority
var owner_id: String
func command(kind: String,args: Dictionary={}) -> Dictionary:
	core.advance_time(core.now+.6)
	return request(core,1,kind,args)
func mine_resource(resource: String,amount: int) -> void:
	var body:=FrontierUniverse.body_from_id(core.world.manifest,core.world.location)
	for vein in FrontierExpeditionBusiness.veins(body):
		if vein.resource!=resource:continue
		var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),vein.position[0],vein.position[2])
		if not p.is_finite():continue
		while int(FrontierExpeditionBusiness.site(core.world).inventory[resource])<amount and int(FrontierExpeditionBusiness.site(core.world).remaining[vein.id])>0:
			core.update_position(1,p+Vector3(0,0,2))
			var result:=command("business_mine",{"vein_id":vein.id})
			if not result.ok:printerr("FAIL: mining ",result);failures+=1;return
			core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
			if not command("business_deposit").ok:failures+=1;return
		if int(FrontierExpeditionBusiness.site(core.world).inventory[resource])>=amount:return
	check(false,"enough accessible seeded "+resource)
func build(kind: String) -> String:
	for x in range(-36,17,7):
		for z in range(-32,25,7):
			var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),x,z,float(FrontierCatalog.entry("buildings",kind).radius))
			if not p.is_finite():continue
			core.update_position(1,p+Vector3(0,0,7))
			if not FrontierExpeditionBusiness.placement(core.world,kind,p,core.peers).is_empty():continue
			var result:=command("business_build",{"building":kind,"position":FrontierExpeditionBusiness.array(p)})
			check(result.ok,"build "+kind+" from mined inventory: "+str(result.get("error","")))
			return FrontierExpeditionBusiness.site(core.world).buildings.keys().back() if result.ok else ""
	check(false,"safe building placement "+kind);return ""
func run() -> void:
	core=FrontierCrewAuthority.new()
	var owner:=FrontierPlayerProfile.new_character("사업 검증",0);owner_id=owner.character_id
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"fresh shared business world")
	navigate(core,15);ready_all(core);check(request(core,1,"land").ok,"land at freely selected planet")
	check(command("business_register").ok,"free development registration")
	check(core.world.business.credits==FrontierExpeditionBusiness.config().starting_credits and FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.site(core.world).inventory)==0,"registration has startup capital but grants no mined materials")
	check(not command("business_register").ok,"registration cannot repeat capital grant")
	var before:=FrontierUniverse.fingerprint(core.world)
	disk_ok=false
	check(not command("business_technology",{"technology":"robotics"}).ok and FrontierUniverse.fingerprint(core.world)==before,"failed purchase save preserves cash and technology")
	disk_ok=true
	var guest:=FrontierPlayerProfile.new_character("공동 지출 검증",1)
	check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"guest enters active business")
	core.update_position(2,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
	var initial_credits: int=core.world.business.credits
	for action in ["business_technology","business_supply","business_robot_rescue"]:
		check(not request(core,2,action,{"technology":"robotics","resource":"iron"}).ok and core.world.business.credits==initial_credits,"guest cannot spend shared credits: "+action)
	check(core.disconnect_member(2),"guest disconnect keeps business valid")
	for resource in ["iron","copper","stone","ice"]:mine_resource(resource,{"iron":550,"copper":220,"stone":220,"ice":200}[resource])
	check(failures==0,"all construction stock physically mined and carried")
	core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
	for key in ["robotics","atmosphere","thermal","water","biotech","recovery"]:check(command("business_technology",{"technology":key}).ok,"permanent technology "+key)
	var solar:=build("solar");var charger:=build("charger");var factory:=build("factory")
	check(not solar.is_empty() and not charger.is_empty() and not factory.is_empty(),"power charging and fabrication facilities exist")
	if failures:quit(1);return
	core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).buildings[factory].position)+Vector3(0,0,4))
	check(command("business_craft",{"building_id":factory}).ok,"reserve paid robot fabrication with stable result")
	check(not command("business_demolish",{"building_id":factory}).ok,"cannot refund factory while fabrication is pending")
	for tick in 20:FrontierExpeditionIndustry.tick(core.world,1)
	var site:=FrontierExpeditionBusiness.site(core.world)
	check(site.robots.size()==1 and site.jobs.is_empty(),"powered fabrication creates one unique robot")
	if site.robots.is_empty():quit(1);return
	var robot_id: String=site.robots.keys()[0]
	var vein_id: String=""
	for vein in FrontierExpeditionBusiness.veins(FrontierUniverse.body_from_id(core.world.manifest,core.world.location)):
		if vein.resource=="iron" and site.remaining[vein.id]>0 and FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),vein.position[0],vein.position[2]).is_finite():vein_id=vein.id;break
	check(command("business_assign",{"robot_id":robot_id,"vein_id":vein_id}).ok,"assign real finite vein")
	var delivered: int=FrontierExpeditionBusiness.site(core.world).delivered
	for tick in 180:
		FrontierExpeditionIndustry.tick(core.world,1)
		if FrontierExpeditionBusiness.site(core.world).delivered>delivered:break
	site=FrontierExpeditionBusiness.site(core.world)
	check(site.delivered>delivered,"robot follows terrain route and physically delivers mined cargo: "+str(site.robots[robot_id].status))
	check(site.production_paid,"automation milestone pays once")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"active industry state is persistable: "+FrontierUniverse.validate_world(core.world))
	# Force a low battery, then use the same route/charger system; this does not grant resources.
	site.robots[robot_id].battery=20
	for tick in 180:
		FrontierExpeditionIndustry.tick(core.world,1)
		if site.robots[robot_id].battery>=99:break
	check(site.robots[robot_id].battery>=99,"low battery robot returns to powered charger")
	build("solar");build("solar");build("atmosphere");build("thermal");build("water");build("biolab")
	for tick in 600:FrontierExpeditionIndustry.tick(core.world,1)
	site=FrontierExpeditionBusiness.site(core.world)
	check(site.environment.ecology>=20 and site.environment.stable_seconds>=30,"powered material-fed facilities stabilize a reclamation site")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"finished environment validates: "+FrontierUniverse.validate_world(core.world))
	var packet:=FrontierCrewSurfaceReplica.packet(core.world,owner_id)
	check(FrontierCrewSurfaceReplica.validate(packet,core.world.manifest),"current-planet industry replica validates")
	var malformed: Dictionary=core.world.business.duplicate(true);malformed.sites[core.world.location].remaining["vein:0"]+=9999
	check(not FrontierExpeditionBusiness.validate(malformed,core.world.manifest).is_empty(),"cannot restore more ore than seeded capacity")
	check(command("business_robot_return",{"robot_id":robot_id}).ok,"order robot to finish hauling and return for transport")
	for tick in 240:
		FrontierExpeditionIndustry.tick(core.world,1)
		if FrontierExpeditionBusiness.site(core.world).robots[robot_id].phase=="idle":break
	site=FrontierExpeditionBusiness.site(core.world)
	var grade: String=site.robots[robot_id].grade
	core.update_position(1,FrontierExpeditionBusiness.point(site.center))
	check(command("business_robot_recover",{"robot_id":robot_id}).ok,"recover empty returned robot into shared hangar")
	check(core.world.business.hangar.has(robot_id) and not FrontierExpeditionBusiness.site(core.world).robots.has(robot_id),"robot has one ownership location")
	var corrupt: Dictionary=core.world.business.duplicate(true)
	corrupt.sites[corrupt.active]="invalid"
	check(not FrontierExpeditionBusiness.validate(corrupt,core.world.manifest).is_empty(),"malformed active site fails without runtime error")
	core.update_position(1,FrontierExpeditionBusiness.point(site.center))
	check(command("business_settle").ok,"complete local restoration contract")
	var credits: int=core.world.business.credits
	check(not command("business_settle").ok and core.world.business.credits==credits,"settlement cannot pay twice")
	ready_all(core);check(command("launch").ok,"depart after business settlement")
	navigate(core,21);ready_all(core);check(command("land").ok,"arrive on next freely selected planet")
	check(command("business_register").ok and core.world.business.credits==credits,"profit and technologies fund next expedition without another startup grant")
	core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
	check(command("business_robot_deploy",{"robot_id":robot_id}).ok and FrontierExpeditionBusiness.site(core.world).robots[robot_id].grade==grade,"same robot ID and grade deploy on planet B")
	var failed_producer:=FrontierCrewAuthority.new()
	check(failed_producer.start(core.world,owner,persist),"production rollback world opens")
	var production_before:=FrontierUniverse.fingerprint(failed_producer.world)
	disk_ok=false;failed_producer.step_surface(1.0)
	check(failed_producer.stopped and FrontierUniverse.fingerprint(failed_producer.world)==production_before,"failed autonomous production save freezes world without publishing draft")
	disk_ok=true
	check(core.close(),"persistent multi-planet business closes cleanly")
	print("EXPEDITION_BUSINESS_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
