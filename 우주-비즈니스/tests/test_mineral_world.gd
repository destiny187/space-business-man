extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var manifest:=FrontierUniverse.generate(71491)
	var earth:=FrontierUniverse.body(manifest,2)
	check(earth.planet_tier==1 and earth.mineral_profile.id=="weathered","Earth is a low-tier outer world")
	var averages: Array=[]
	var resources: Dictionary={}
	for band in 5:
		var total_tier:=0
		for sample in 40:
			var ordinal: int=band*200000+sample*311+8
			var body:=FrontierUniverse.body(manifest,ordinal)
			var system:=FrontierUniverse.system(manifest,int(body.system_ordinal))
			var distance:=Vector2(system.map_position[0],system.map_position[1]).length()
			check(distance<=500-band*80+.001 and distance>=420-band*80-.001,"Physical radius follows tier band")
			total_tier+=int(body.planet_tier)
			if not FrontierUniverse.landable(body):
				check(FrontierExpeditionBusiness.veins(body).is_empty(),"Gas/ice giants have no deposits");continue
			for row in FrontierMineralWorld.nearby(body):resources[row.resource]=true
		averages.append(float(total_tier)/40)
		if band>0:check(averages[band]>averages[band-1],"Tier frequency rises toward center")
	for id in FrontierMinerals.all():
		if id not in ["stone","crystal"]:check(resources.has(id),"Galaxy supplies "+id)
	var near:=FrontierMineralWorld.nearby(earth)
	var far:=FrontierMineralWorld.nearby(earth,Vector3(2400,0,-1600))
	check(near.size()<=63 and far.size()<=63 and near[0].id!=far[0].id,"Bounded streaming at distant region")
	check(near==FrontierMineralWorld.nearby(JSON.parse_string(JSON.stringify(earth))),"Reloaded manifest reproduces deposits")
	check(FrontierMineralWorld.find(earth,"ore1:999999:0:0").is_empty(),"Reject out-of-world deposit address")
	var legacy:=FrontierUniverse.config();legacy.erase("resource_rules")
	check(not FrontierMineralWorld.enabled(FrontierUniverse.body(FrontierUniverse.generate(71491,legacy),2)),"Old world keeps old generator")
	var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("자원 세계 검증",0)
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"Create host world")
	check(request(core,1,"start_game").ok,"Host begins world")
	ready_all(core);check(request(core,1,"land").ok,"Land on Earth")
	check(request(core,1,"business_register").ok,"Register site")
	var actor: String=owner.character_id
	check(request(core,1,"equipment_craft",{"definition":"miner_1"}).ok,"Build free initial collector")
	var member: Dictionary=core.world.crew.members[actor]
	var item: String=member.loadout.items.keys()[0]
	check(request(core,1,"equipment_equip",{"slot":0,"item_id":item}).ok,"Equip owned collector")
	var found: Dictionary={}
	var field:=FrontierCrewSurface.field(core.world)
	for x in range(-2,3):
		for z in range(-2,3):
			for row in FrontierMineralWorld.region(earth,x,z):
				if row.underground or row.resource not in ["aluminum","silicon","phosphate"]:continue
				var point:=FrontierMineralWorld.point(field,row)
				if point.is_finite():found=row;break
	check(not found.is_empty(),"New industrial resource exists on accessible ground")
	if not found.is_empty():
		var point:=FrontierMineralWorld.point(field,found)
		core.update_position(1,point+Vector3(0,0,1.5));core.advance_time(10)
		var mined:=request(core,1,"business_mine",{"vein_id":found.id})
		check(mined.ok,"Host mines new mineral: "+str(mined.get("error","")))
		var site:=FrontierExpeditionBusiness.site(core.world)
		check(site.remaining.size()==1 and int(site.remaining.get(found.id,found.capacity))<int(found.capacity),"Only modified deposit saved")
		check(FrontierExpeditionBusiness.bag(core.world,actor).get(found.resource,0)>0,"New material goes into bag")
		core.update_position(1,FrontierExpeditionBusiness.point(site.center))
		check(request(core,1,"business_deposit").ok,"Deposit new material to warehouse")
		var reloaded: Dictionary=JSON.parse_string(JSON.stringify(core.world))
		check(FrontierUniverse.validate_world(reloaded).is_empty(),"Sparse depletion + new inventory survives save roundtrip")
		check(FrontierUniverse.fingerprint(FrontierExpeditionBusiness.site(reloaded).remaining)==FrontierUniverse.fingerprint(FrontierExpeditionBusiness.site(core.world).remaining),"Save does not reroll depleted material")
	var cave:=FrontierExpeditionBusiness.find_vein(earth,"cave:gem:0")
	check(not cave.is_empty() and FrontierMineralWorld.point(field,cave).is_finite(),"Reachable underground cave gemstone")
	# Earn the existing Mk.2 recipe, then mine the exposed cave gemstone through the host.
	for resource in ["iron","copper"]:
		for row in FrontierExpeditionBusiness.veins(earth):
			if row.resource!=resource or row.get("underground",false):continue
			var p:=FrontierMineralWorld.point(field,row)
			if not p.is_finite():continue
			core.update_position(1,p+Vector3(0,0,1.5))
			for n in 3:
				core.advance_time(core.now+1)
				check(request(core,1,"business_mine",{"vein_id":row.id}).ok,"Mine upgrade material "+resource)
			break
	check(request(core,1,"equipment_craft",{"definition":"miner_2"}).ok,"Craft Mk.2 from mined materials")
	var upgraded: String=""
	for id in core.world.crew.members[actor].loadout.items:
		if core.world.crew.members[actor].loadout.items[id]=="miner_2":upgraded=id
	check(not upgraded.is_empty() and request(core,1,"equipment_equip",{"slot":0,"item_id":upgraded}).ok,"Equip crafted Mk.2")
	if not cave.is_empty():
		core.update_position(1,FrontierMineralWorld.point(field,cave)+Vector3(0,0,1.5));core.advance_time(core.now+1)
		var result:=request(core,1,"business_mine",{"vein_id":cave.id})
		check(result.ok,"Mine underground gemstone: "+str(result.get("error","")))
		check(FrontierExpeditionBusiness.bag(core.world,actor).get(cave.resource,0)>0,"Gemstone enters persistent bag")
	check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(core.world))).is_empty(),"Gemstone world validates after JSON save")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../test-results"))
	var output:=FileAccess.open("res://../test-results/mineral-world.json",FileAccess.WRITE);output.store_string(JSON.stringify(core.world));output.close()
	print("MINERAL WORLD ",checks," checks, ",failures," failures; band averages ",averages)
	quit(0 if failures==0 else 1)
