extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func run() -> void:
	var cfg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/underground.json"))
	for family in cfg.profiles:
		var definition: Dictionary=cfg.profiles[family].duplicate(true)
		for key in ["version","region_size","occupancy","maximum_depth"]:definition[key]=cfg[key]
		var traits: Dictionary={"underground":definition}
		var field:=FrontierTerrainField.new();field.configure(71491,[],24,traits)
		var graph:=field.caves.system_at(0,0)
		var copy:=FrontierTerrainField.new();copy.configure(71491,[],24,traits)
		copy.caves.system_at(900,900)
		check(graph==copy.caves.system_at(0,0),family+" deterministic after different region access order")
		var other:=FrontierTerrainField.new();other.configure(31415,[],24,traits)
		check(graph!=other.caves.system_at(0,0),family+" seed changes graph")
		var clearance:=true
		var floors:=true
		var walkable:=true
		var navigator:=FrontierTerrainNavigation.new()
		navigator.field=field;navigator.settings=FrontierSurfaceLogistics.config().navigation
		for segment in graph.segments:
			for i in range(1,32):
				var p: Vector3=segment.a.lerp(segment.b,float(i)/32)
				clearance=clearance and field.density(p)<-1.0
				var floor_y:=p.y-float(segment.radius)*.7
				# Main/branch joins may open into a larger room, but remain bounded below.
				floors=floors and field.density(Vector3(p.x,floor_y-16,p.z))>0
				if i%4==0:
					var foot:=navigator.support(p.x,p.z,floor_y)
					if walkable and not foot.is_finite():
						print("CAVE_WALK_DIAGNOSTIC ",family," point=",p," expected_floor=",floor_y," entrance=",segment.entrance)
						for j in range(0,30):
							var sample:=Vector3(p.x,floor_y+2-j*.5,p.z)
							if field.density(sample)>0:print("FIRST_ROCK ",sample," density=",field.density(sample));break
					walkable=walkable and foot.is_finite()
		check(clearance,family+" continuous person-height clearance on all connections")
		check(floors,family+" supported floors beneath passages")
		check(walkable,family+" game navigator finds supported walkable passage floors")
		var point:=Vector3(30,field.height(30,0)-200,0)
		field.add_edit({"center":[point.x,point.y,point.z],"radius":4})
		check(field.density(point-Vector3.UP)>0 and field.density(point+Vector3.UP)<0,family+" mixed dig clips at original-surface bedrock")
		check(field.is_bedrock(point),family+" host rejects repeat bedrock hit")
		var entrance: Vector3=graph.nodes[0]
		check(Vector2(entrance.x,entrance.z).length()>80,family+" entrance avoids starter resources and landing")
	var manifest:=FrontierUniverse.generate(71491)
	var ordinal:=8
	while not FrontierUniverse.landable(FrontierUniverse.body(manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(manifest,ordinal)
	check(body.terrain_traits.has("underground"),"new galaxy snapshots cave rules")
	manifest.settings.erase("underground_rules")
	body=FrontierUniverse.body(manifest,ordinal)
	check(not body.terrain_traits.has("underground"),"legacy galaxy retains legacy terrain")
	var legacy:=FrontierTerrainField.new();legacy.configure(71491)
	check(legacy.caves==null and legacy.density(Vector3(99,-20,0))<0,"legacy fixed chamber is preserved")
	robot_checks()
	print("SEEDED_CAVES_AUTOMATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
func robot_checks() -> void:
	var world:=FrontierUniverse.new_world(71491)
	world.location=FrontierUniverse.body_id(world.manifest,12)
	world.crew={"owner_id":"test","members":{"test":{"position":[0,2,0]}},"landing":{"body_id":world.location}}
	world.business=FrontierExpeditionBusiness.create()
	world.business.technologies=["robotics"]
	var factory: Dictionary={"id":"factory","type":"factory","position":[0,2,0],"tier":1,"active":true,"enabled":true}
	var stock: Dictionary={"iron":999,"copper":999,"stone":999,"reinforced_frame":20,"control_circuit":20,"heat_transfer_unit":20}
	var site: Dictionary={"state":"active","center":[0,2,0],"inventory":stock,"buildings":{"factory":factory},"jobs":{},"robots":{}}
	world.business.sites[world.location]=site;world.business.active=world.location
	var before:=FrontierUniverse.fingerprint(world)
	var error:=FrontierExpeditionBusiness.apply(world,"test","business_craft",{"building_id":"factory"},{})
	check(not error.is_empty() and FrontierUniverse.fingerprint(world)==before,"T1 factory cannot craft even with all components; no mutation")
	error=FrontierProductionTier2.apply(world,"test","business_facility_upgrade",{"building_id":"factory"})
	check(error.is_empty() and factory.tier==2,"manual-production parts unlock T2 factory without a robot")
	var remaining:=int(stock.reinforced_frame)
	error=FrontierExpeditionBusiness.apply(world,"test","business_craft",{"building_id":"factory"},{})
	check(error.is_empty() and site.jobs.size()==1 and int(site.jobs.values()[0].tier)==2,"T2 factory reserves first T2 robot")
	check(int(stock.reinforced_frame)==remaining-int(FrontierProductionTier2.robot_recipe().cost.reinforced_frame),"robot consumes T2 parts once")
	before=FrontierUniverse.fingerprint(world)
	error=FrontierExpeditionBusiness.apply(world,"test","business_craft",{"building_id":"factory"},{})
	check(not error.is_empty() and before==FrontierUniverse.fingerprint(world),"busy factory cannot double-reserve or spend")
	world.crew.world_id="automation-fixture"
	world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	site.time=0.0;site.delivered=0;site.production_paid=false
	site.environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":0.0,"ecology":0.0,"stable_seconds":0.0}
	site.buildings.solar={"id":"solar","type":"solar","position":[12,2,0],"active":true,"enabled":true,"work":0.0}
	FrontierExpeditionIndustry.tick(world,30)
	check(site.jobs.is_empty() and site.robots.size()==1 and int(site.robots.values()[0].tier)==2,"powered production spawns a T2 robot")
	if not site.robots.is_empty():
		var robot: Dictionary=site.robots.values()[0]
		check(FrontierExpeditionBusiness.valid_robot(JSON.parse_string(JSON.stringify(robot)),robot.id),"T2 robot round trip retains a valid saved state")
		check(FrontierProductionTier2.robot_capacity(robot)==64,"new robot uses T2 capacity")
