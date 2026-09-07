extends SceneTree
var failures:=0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL ",label)
	else:print("PASS ",label)
func _initialize() -> void:
	var profile:=FrontierPlayerProfile.new_character("직접 채광")
	var actor: String=profile.character_id
	var world:=FrontierUniverse.new_world(71491)
	world.crew=FrontierCrewWorld.create(profile)
	world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	var member: Dictionary=world.crew.members[actor];member.loadout=FrontierEquipment.create(profile);member.area="surface"
	var ordinal:=FrontierUniverse.first_ordinal(world.manifest,23)
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal)
	world.location=body.id;world.crew.landing={"body_id":body.id,"epoch":1}
	var row:=FrontierExpeditionBusiness.find_vein(body,"landing:iron")
	var ground:=FrontierMineralWorld.point(FrontierCrewSurface.field(world),row)
	member.position=FrontierExpeditionBusiness.array(ground+Vector3(0,.1,2))
	var error:=FrontierExpeditionBusiness.apply(world,actor,"business_mine",{"vein_id":row.id},{1:actor})
	check(error.is_empty(),"mine with no registration or research: "+error)
	check(world.business.active.is_empty() and world.business.sites[body.id].state=="exploration","mining does not open a contract")
	check(int(world.business.bags[actor].iron)==3,"starter miner receives iron")
	check(FrontierExpeditionBusiness.validate(world.business,world.manifest).is_empty(),"exploration save schema")
	var copy: Dictionary=JSON.parse_string(JSON.stringify(world))
	check(copy.business.sites[body.id].remaining[row.id]==397,"depletion survives serialization")
	# Another ongoing contract must not prevent this planet's mining.
	var other:=FrontierUniverse.body(world.manifest,ordinal+1)
	world.location=other.id;world.crew.landing.body_id=other.id
	var site:=FrontierExpeditionBusiness.ensure_site(world);site.state="active";world.business.active=other.id
	world.location=body.id;world.crew.landing.body_id=body.id
	error=FrontierExpeditionBusiness.apply(world,actor,"business_mine",{"vein_id":row.id},{1:actor})
	check(error.is_empty() and world.business.bags[actor].iron==6,"mine while another contract remains active: "+error)
	member.position=FrontierCrewSurface.config().ship_position.duplicate()
	error=FrontierExpeditionBusiness.apply(world,actor,"business_technology",{"technology":"robotics"},{1:actor})
	check(error.is_empty() and "robotics" in world.business.technologies,"research independent of contract: "+error)
	check(world.business.active==other.id,"research preserves active contract")
	print("DIRECT_MINING_FAILURES ",failures);quit(1 if failures else 0)
