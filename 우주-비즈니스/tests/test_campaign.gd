extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: " + label)

func run() -> void:
	var c := FrontierCampaign.new("user://test_campaign.json")
	c.persistence_enabled = false
	check(c.new_campaign().is_empty(), "new campaign")
	check(c.buy_planet("basalt").is_empty(), "buy first moon")
	check(not c.craft("miner").is_empty(), "unowned technology blocks craft")
	var node: Dictionary = c.planet.nodes[0]
	c.planet.player.position = node.position.duplicate()
	var initial: int = node.amount
	check(c.mine(node.id).is_empty(), "manual resource extraction")
	check(initial - int(node.amount) == FrontierCatalog.total(c.planet.player.cargo), "extraction conserves resources")
	c.planet.player.position = [0,5]
	check(c.deposit().is_empty(), "deposit at base")
	check(FrontierCatalog.total(c.planet.player.cargo) == 0, "cargo transferred once")
	check(c.buy_technology("robotics").is_empty(), "buy initial technology")
	var cash: int = c.profile.credits
	check(not c.buy_technology("robotics").is_empty() and c.profile.credits == cash, "duplicate purchase rejected")
	c.planet.inventory = {"iron": 5000,"copper":5000,"stone":5000,"ice":5000,"crystal":100}
	var sim := FrontierSimulation.new()
	var places: Dictionary = {}
	for kind in ["solar","charger","factory"]:
		places[kind] = place(c,kind)
	sim.step(c,0.1)
	check(c.craft("miner").is_empty(), "powered factory accepts craft")
	var roll: Dictionary = c.planet.jobs[0].result.duplicate(true)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.state))
	c.state = saved
	check(c.planet.jobs[0].result.grade == roll.grade and c.planet.jobs[0].result.traits == roll.traits, "pending randomized result survives serialization")
	for i in range(220): sim.step(c,0.1)
	check(c.planet.robots.size() == 1 and c.planet.jobs.is_empty(), "craft completes once")
	for i in range(100): sim.step(c,0.1)
	check(c.planet.robots.size() == 1, "completed craft does not duplicate")
	check(c.craft("miner").is_empty(), "second craft")
	var before_refund: int = c.planet.inventory.iron
	var job_id: String = c.planet.jobs[0].id
	check(c.cancel_craft(job_id).is_empty(), "cancel craft")
	check(c.planet.inventory.iron == before_refund + 100, "cancel returns reserved materials")
	check(not c.cancel_craft(job_id).is_empty(), "cancel cannot refund twice")
	c.planet.inventory = {"iron":0,"copper":0,"stone":0,"ice":0,"crystal":0}
	var robot: Dictionary = c.planet.robots[0]
	c.assign_robot(robot.id,"iron")
	for i in range(2400): sim.step(c,0.1)
	check(c.planet.inventory.get("iron",0) > 0, "robot mines and delivers through world pathfinding")
	robot.battery = 1.0
	for i in range(1800): sim.step(c,0.1)
	check(robot.battery > 20 or robot.status == "배터리 고갈 · 구조 필요", "battery lifecycle remains explicit")
	check(c.rescue_robot(robot.id).is_empty(), "robot recovery from blocked state")
	for key in ["atmosphere","thermal","water","biotech","recovery"]:
		check(c.buy_technology(key).is_empty(), "technology path: "+key)
	check(c.upgrade_ship().is_empty(), "purchase recovery ship")
	c.planet.inventory = {"iron":5000,"copper":5000,"stone":5000,"ice":5000,"crystal":100}
	for kind in ["solar","solar","atmosphere","thermal","water","biolab"]: place(c,kind)
	for i in range(10000): sim.step(c,0.1)
	var evaluation: Dictionary = FrontierEvaluator.report(c.planet)
	check(evaluation.grade in ["S","A","B"], "powered industrial loop achieves habitable grade")
	var unsafe: Dictionary = c.planet.duplicate(true)
	unsafe.environment.toxicity = 90
	check(FrontierEvaluator.report(unsafe).grade not in ["S","A","B"], "toxic environment gates habitability")
	var ruin: Dictionary = c.planet.events[0]
	c.planet.player.position = ruin.position.duplicate()
	check(c.discover(ruin.id).is_empty(), "ruin discovery")
	check(c.choose_event(ruin.id,"preserve").is_empty(), "ruin preservation")
	check(not c.choose_event(ruin.id,"extract").is_empty(), "discovery choice cannot pay twice")
	var id: String = c.planet.id
	var robot_id: String = c.planet.robots[0].id
	var full_value: int = FrontierEvaluator.report(c.planet).residual
	check(FrontierEvaluator.report(c.planet,[robot_id]).residual < full_value, "recovered robots excluded from sale price")
	check(c.sell_planet(id,[robot_id]).is_empty(), "sale with robot recovery")
	cash = c.profile.credits
	check(c.planet.is_empty() and c.profile.hangar.size() == 1, "sale transfers ownership to earth")
	check(not c.sell_planet(id,[robot_id]).is_empty() and c.profile.credits == cash, "duplicate sale cannot issue funds")
	check(c.buy_planet("basalt",[robot_id]).is_empty(), "next planet expedition")
	check(c.planet.robots[0].id == robot_id and c.profile.hangar.is_empty(), "same robot moves to next planet")
	check(c.planet.robots[0].grade == roll.grade and c.planet.robots[0].traits == roll.traits, "robot identity and randomized attributes preserved")
	c.persistence_enabled = true
	check(c.save().is_empty(), "atomic save writes")
	var loaded := FrontierCampaign.new("user://test_campaign.json")
	check(loaded.load_campaign(), "atomic save loads")
	check(loaded.planet.robots[0].id == robot_id, "saved ownership restored")
	var duplicate: Dictionary = loaded.state.duplicate(true)
	duplicate.profile.hangar.append(duplicate.planet.robots[0].duplicate(true))
	check(not FrontierSaveStore.validate(duplicate).is_empty(), "duplicate robot ownership invalid")
	var missing: Dictionary = loaded.state.duplicate(true)
	missing.erase("profile")
	check(not FrontierSaveStore.validate(missing).is_empty(), "malformed save rejected")
	check(c.save().is_empty(), "backup saved")
	var corrupt := FileAccess.open("user://test_campaign.json",FileAccess.WRITE)
	corrupt.store_string("broken")
	corrupt.close()
	check(loaded.load_campaign(), "corrupt primary falls back to backup")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists("user://test_campaign.json"+suffix): DirAccess.remove_absolute("user://test_campaign.json"+suffix)
	print("CAMPAIGN_TESTS checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: print("  ",failure)
	quit(0 if failures.is_empty() else 1)

func place(c: FrontierCampaign, kind: String) -> Vector2:
	for y in range(-18,20,7):
		for x in range(-18,20,7):
			var location := Vector2(x,y)
			if c.placement_error(kind,location).is_empty():
				check(c.build(kind,location).is_empty(), "build "+kind)
				return location
	check(false,"no valid site for "+kind)
	return Vector2.ZERO
