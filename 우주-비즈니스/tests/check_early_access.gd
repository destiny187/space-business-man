extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var source:=FrontierWorldStore.new("/tmp/first-automation-audit/world.json").read_state()
	var owner: Dictionary=source.crew.members[source.crew.owner_id].profile
	var core:=FrontierCrewAuthority.new()
	check(core.start(source,owner,persist),"load existing save")
	sequences[1]=int(core.world.crew.members[owner.character_id].last_sequence)
	check(request(core,1,"start_game").ok,"start")
	core.world.business.technologies=[]
	for key in FrontierEarlyAccess.config().open_technologies:check(FrontierEarlyAccess.available(core.world.business,key),"basic access "+key)
	var credits: int=core.world.business.credits
	check(not request(core,1,"business_technology",{"technology":"robotics"}).ok and credits==core.world.business.credits,"no basic purchase charge")
	var site: Dictionary=core.world.business.sites[core.world.location]
	core.world.crew.members[owner.character_id].position=site.buildings["fixture:factory"].position.duplicate()
	site.buildings["fixture:factory"].active=true
	var result:=request(core,1,"business_craft",{"building_id":"fixture:factory"})
	check(result.ok,"robot craft without technology: "+str(result.get("error","")))
	for i in 20:core.step_surface(1)
	site=core.world.business.sites[core.world.location]
	check(site.robots.size()==1,"robot output")
	var robot: Dictionary=site.robots.values()[0]
	check(not robot.auto_enabled and robot.phase=="idle" and robot.target=="","output waits")
	core.world.crew.members[owner.character_id].position=robot.position.duplicate()
	check(not request(core,1,"business_robot_auto",{"robot_id":robot.id,"resource":"iron","enabled":true}).ok,"undiscovered selection denied")
	FrontierRobotWork.discover(site,"iron")
	check(FrontierExpeditionBusiness.public_view(core.world,owner.character_id).discovered_resources==["iron"],"discovered list in snapshot")
	check(request(core,1,"business_robot_auto",{"robot_id":robot.id,"resource":"iron","enabled":true}).ok,"explicit selection starts")
	for i in 20:core.step_surface(1)
	robot=core.world.business.sites[core.world.location].robots.values()[0]
	check(robot.auto_enabled and robot.resource_filter=="iron","explicit mode retained")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"save validates")
	FrontierWorldStore.new("/tmp/early-checked-world.json").write(core.world)
	print("EARLY_ACCESS ",checks," FAILURES ",failures);quit(1 if failures else 0)
