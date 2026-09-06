extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func run() -> void:
	var c := FrontierCampaign.new()
	c.persistence_enabled = false
	c.new_campaign()
	c.buy_planet("basalt")
	var original: Dictionary = c.state.duplicate(true)
	for pair in [["inventory",[]],["nodes",[null]],["robots",[1]],["buildings",[{}]],["events",["broken"]],["environment",{"water":INF}],["player",{"cargo":{},"position":[0,0]}],["jobs",[{}]]]:
		var invalid: Dictionary = original.duplicate(true)
		invalid.planet[pair[0]] = pair[1]
		check(not FrontierSaveStore.validate(invalid).is_empty(),"reject malformed "+pair[0])
	for pair in [["oxygen",NAN],["pressure",-1],["water",101],["temperature",-274],["ecology","10"],["stable_seconds",121]]:
		var invalid: Dictionary = original.duplicate(true)
		invalid.planet.environment[pair[0]] = pair[1]
		check(not FrontierSaveStore.validate(invalid).is_empty(),"reject invalid environment "+pair[0])
	var negative: Dictionary = original.duplicate(true)
	negative.planet.inventory.iron = -1
	check(not FrontierSaveStore.validate(negative).is_empty(),"reject negative materials")
	var valid_settings := {"sensitivity":0.0025,"volume":0.4,"fullscreen":false}
	FrontierInput.apply(valid_settings)
	check(FrontierInput.rebind(valid_settings,"forward",KEY_UP).is_empty(),"rebind valid key")
	check(not FrontierInput.rebind(valid_settings,"backward",KEY_UP).is_empty(),"reject duplicate key")
	check(not FrontierInput.rebind(valid_settings,"forward",KEY_ESCAPE).is_empty(),"preserve escape")
	c.profile.settings = valid_settings
	check(FrontierSaveStore.validate(c.state).is_empty(),"persist valid binding")
	for seed_value in range(100):
		var p: Dictionary = FrontierPlanetFactory.make(["basalt","glacial","sulfur"][seed_value%3],"seed_check",seed_value,seed_value)
		var clear: bool = true
		for i in range(p.nodes.size()):
			var point: Vector2 = FrontierCampaign.point(p.nodes[i].position)
			for j in range(i):
				if point.distance_to(FrontierCampaign.point(p.nodes[j].position)) < 6.49: clear = false
			for e in p.events:
				if point.distance_to(FrontierCampaign.point(e.position)) < 6.99: clear = false
		check(clear,"seed %d resource and discovery clearance" % seed_value)
		var sim := FrontierSimulation.new()
		sim._update_navigation(p)
		var reachable: bool = true
		for node in p.nodes:
			if not sim._reachable(Vector2(0,6),sim._approach(FrontierCampaign.point(node.position),Vector2(0,6),3)): reachable = false
		check(reachable,"seed %d accessible resources" % seed_value)
	for seed_value in range(8):
		c.new_campaign(71491+seed_value)
		c.buy_planet("basalt")
		c.buy_technology("robotics")
		c.planet.inventory = {"iron":2000,"copper":1000,"stone":1000}
		for kind in ["solar","charger","factory","storage","storage","storage"]: place(c,kind)
		var sim := FrontierSimulation.new()
		for i in range(3):
			sim.step(c,0.1)
			check(c.craft("miner").is_empty(),"multiple robot order")
			for tick in range(100): sim.step(c,0.25)
		c.planet.inventory = {}
		var charger: Dictionary = {}
		for b in c.planet.buildings:
			if b.type == "charger": charger = b
		var charging: Dictionary = {}
		var resumed: Dictionary = {}
		for r in c.planet.robots: r.battery = 22.0
		for tick in range(6000):
			sim.step(c,0.25)
			for r in c.planet.robots:
				if r.status == "충전 중": charging[r.id] = true
				if charging.has(r.id) and r.status == "채광 중": resumed[r.id] = true
		check(c.planet.robots.size() == 3,"three robots spawned seed %d" % seed_value)
		check(charging.size() == 3 and resumed.size() == 3,"all robots recharge and resume seed %d" % seed_value)
		check(FrontierCatalog.total(c.planet.inventory) > 1000,"long-run deliveries seed %d" % seed_value)
		check(FrontierSaveStore.validate(c.state).is_empty(),"long-run save valid seed %d" % seed_value)
	# Completion is transactional even when the atomic write cannot be created.
	c.new_campaign()
	c.buy_planet("basalt")
	c.buy_technology("robotics")
	c.planet.inventory = {"iron":1000,"copper":1000,"stone":1000}
	for kind in ["solar","factory"]: place(c,kind)
	var sim := FrontierSimulation.new()
	sim.step(c,0.1)
	c.craft("miner")
	c.planet.jobs[0].progress = c.planet.jobs[0].seconds-0.1
	var before: String = JSON.stringify(c.state)
	var accumulator: float = sim.accumulator
	var notices: Array[String] = []
	c.message.connect(func(value: String): notices.append(value))
	c.store = FrontierSaveStore.new("user://missing_directory_for_test/save.json")
	c.persistence_enabled = true
	sim.step(c,0.25)
	check(JSON.stringify(c.state) == before and sim.accumulator == accumulator,"failed completion restores state and clock")
	check(not notices.any(func(value: String): return value.contains("제작 완료")),"failed completion emits no success")
	c.persistence_enabled = false
	sim.step(c,0.25)
	check(c.planet.robots.size() == 1 and c.planet.jobs.is_empty(),"completion retry produces exactly one robot")
	var robot_id: String = c.planet.robots[0].id
	check(c.toggle_robot(robot_id).is_empty(),"pause robot")
	var paused_position: Array = c.planet.robots[0].position.duplicate()
	sim.step(c,1.0)
	check(c.planet.robots[0].position == paused_position and c.planet.robots[0].status == "수동 대기","paused robot stays still")
	check(c.toggle_robot(robot_id).is_empty() and c.planet.robots[0].enabled,"resume robot")
	c.planet.inventory = {"iron":c.capacity()}
	check(not c.discard_inventory("iron",-100).is_empty() and c.planet.inventory.iron == c.capacity(),"negative discard cannot add resources")
	check(c.discard_inventory("iron",100).is_empty() and c.planet.inventory.iron == c.capacity()-100,"discard frees warehouse capacity")
	c.planet.player.position = [0,5]
	c.planet.player.cargo = {"stone":20}
	check(c.deposit().is_empty() and c.planet.inventory.stone == 20,"another resource can be deposited after clearing space")
	print("RELIABILITY_TESTS checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func place(c: FrontierCampaign,kind: String) -> void:
	for y in range(-18,23,7):
		for x in range(-18,23,7):
			if c.placement_error(kind,Vector2(x,y)).is_empty():
				check(c.build(kind,Vector2(x,y)).is_empty(),"build "+kind)
				return
	check(false,"no place for "+kind)
