extends "res://tests/check_planet_supply.gd"
func check(condition: bool,label: String) -> void:
	super.check(condition,label)
	if condition:print("PASS ",label)
func args() -> Dictionary:return {"project":"deep_mining","building_id":"fixture:factory","expected_stage":core.world.expedition_research.projects.deep_mining.stage}
func reject(label: String) -> void:
	var before:=FrontierUniverse.fingerprint(core.world)
	check(not command("equipment_research_prototype",args()).ok and before==FrontierUniverse.fingerprint(core.world),label)
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("시제품 제작자",0);actor=owner.character_id
	core=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,persist),"host starts")
	request(core,1,"start_game")
	core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
	core.world.ecology=FrontierEcology.create();core.world.business=FrontierExpeditionBusiness.create()
	var body:=FrontierUniverse.body(core.world.manifest,FrontierCrewNavigation.first_destination(core.world.manifest));visit(body)
	site().state="active";core.world.business.active=body.id;add_factory();move(FrontierCrewWorld.vector(factory().position))
	core.world.business.bags[actor]=FrontierExpeditionBusiness.inventory();core.world.business.bags[actor].merge({"reinforced_frame":2,"control_circuit":2})
	reject("analysis required before assembly")
	FrontierExpeditionResearch.record(core.world,body.id,"sapphire","fixture:sample",2,"extraction",actor)
	core.world.expedition_research.projects.deep_mining.contributions={actor:{"sapphire":3}};core.world.expedition_research.projects.deep_mining.stage="analyzed"
	var old:=core.world.duplicate(true);old.expedition_research.version=1;old.expedition_research.projects.deep_mining.erase("prototype")
	check(FrontierUniverse.validate_world(old).is_empty(),"A05 schema remains readable")
	FrontierExpeditionResearch.ensure(old)
	check(old.expedition_research.version==2 and old.expedition_research.projects.deep_mining.stage=="analyzed" and old.expedition_research.projects.deep_mining.prototype.is_empty(),"A05 migration preserves analysis without inventing a tool")
	factory().active=false;reject("unpowered assembly rejected");factory().active=true
	move(FrontierCrewWorld.vector(factory().position)+Vector3(20,0,0));reject("remote assembly rejected");move(FrontierCrewWorld.vector(factory().position))
	factory().production={"product":"refined_iron","progress":0.0};reject("busy factory rejected");factory().production={}
	var request_data:=envelope(core,1,"equipment_research_prototype",args());var before:=FrontierUniverse.fingerprint(core.world)
	disk_ok=false;check(not core.request(1,request_data).ok and before==FrontierUniverse.fingerprint(core.world),"save failure rolls back parts, item and project");disk_ok=true
	var result:=core.request(1,request_data)
	check(result.ok,"host assembles probe")
	if not result.ok:print(result);quit(1);return
	var item: String=result.research.item_id
	check(core.world.crew.members[actor].loadout.items[item]=="miner_probe" and core.world.business.bags[actor].reinforced_frame==1 and core.world.expedition_research.projects.deep_mining.stage=="prototyped","own components become one persistent equipment item")
	before=FrontierUniverse.fingerprint(core.world);check(core.request(1,request_data)==result and before==FrontierUniverse.fingerprint(core.world),"retry never duplicates the prototype")
	check(command("equipment_equip",{"item_id":item,"slot":1}).ok and command("equipment_select",{"slot":1}).ok and FrontierEquipment.active(core.world.crew.members[actor]).tier==2,"prototype equips as T2 and cannot gather T3")
	var cargo:=FrontierItemInventory.ship_site(core.world.crew)
	check(FrontierItemInventory.warehouse_equipment(core.world,actor,{"item_id":item},cargo).is_empty() and not core.world.crew.members[actor].loadout.items.has(item),"probe enters existing cargo equipment storage")
	check(FrontierItemInventory.warehouse_equipment(core.world,actor,{"item_id":item,"withdraw":true},cargo).is_empty() and core.world.crew.members[actor].loadout.items[item]=="miner_probe","cargo retrieval restores identical item ID and definition")
	check(not FrontierExpeditionResearch.licensed(core.world,"miner_3") and not FrontierEquipment.apply(core.world,actor,"equipment_craft",{"definition":"miner_probe"}).is_empty(),"prototype grants no Mk3 license and has no portable craft bypass")
	check(persist(core.world),"assembled world validates")
	var reopened:=FrontierCrewAuthority.new();check(reopened.start(saved,owner,persist) and reopened.world.crew.members[actor].loadout.items[item]=="miner_probe" and reopened.world.expedition_research.projects.deep_mining.stage=="prototyped","resume keeps probe and shared project")
	print("RESEARCH_PROTOTYPE_A06 ",checks," FAILURES ",failures);quit(1 if failures else 0)
