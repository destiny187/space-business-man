extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL: "+label)

func fixture() -> FrontierCampaign:
	var c := FrontierCampaign.new("user://event_test.json")
	c.persistence_enabled = false
	c.new_campaign(993)
	c.buy_planet("basalt")
	return c

func discover(c: FrontierCampaign,index: int) -> Dictionary:
	var event: Dictionary = c.planet.events[index]
	c.planet.player.position = event.position.duplicate()
	check(c.discover(event.id).is_empty(),"discover "+event.kind)
	return FrontierCampaign.find_by_id(c.planet.events,event.id)

func run() -> void:
	for choice in ["preserve","extract","analyze"]:
		var c: FrontierCampaign = fixture()
		var event: Dictionary = discover(c,0)
		if choice == "analyze":
			check(not c.choose_event(event.id,choice).is_empty(),"analysis requires technology")
			c.buy_technology("robotics")
			c.buy_technology("analysis")
		var cash: int = c.profile.credits
		check(c.choose_event(event.id,choice).is_empty(),"ruin choice "+choice)
		var report: Dictionary = FrontierEvaluator.report(c.planet)
		if choice == "preserve": check(report.discoveries == 1600 and c.profile.credits == cash,"preserved ruin only raises planet value")
		if choice == "extract": check(report.discoveries == 0 and c.profile.credits == cash+1800,"exported artifact not counted in planet value")
		if choice == "analyze": check(c.has_tech("ancient"),"ancient technology unlocked")
		cash = c.profile.credits
		check(not c.choose_event(event.id,choice).is_empty() and c.profile.credits == cash,"ruin reward once")
	var micro: FrontierCampaign = fixture()
	var event: Dictionary = discover(micro,1)
	check(micro.choose_event(event.id,"cultivate").is_empty(),"microbe cultivation")
	var before_toxic: float = micro.planet.environment.toxicity
	var simulation := FrontierSimulation.new()
	for i in range(10): simulation.step(micro,1)
	check(micro.planet.environment.toxicity < before_toxic and micro.planet.environment.oxygen > 0.025,"adapted microbes change environment")
	for choice in ["protect","capture"]:
		var c: FrontierCampaign = fixture()
		event = discover(c,2)
		var cash: int = c.profile.credits
		check(c.choose_event(event.id,choice).is_empty(),"animal choice "+choice)
		check((c.profile.credits == cash+900 and FrontierEvaluator.report(c.planet).discoveries == 0) if choice == "capture" else (FrontierEvaluator.report(c.planet).discoveries == 800),"animal benefit not duplicated")
	var protected: FrontierCampaign = fixture()
	event = discover(protected,3)
	check(protected.choose_event(event.id,"protect").is_empty(),"civilization protection")
	check(FrontierEvaluator.report(protected.planet).civilization == 0.45,"protection meaningfully reduces sale price")
	check(not protected.choose_event(event.id,"destroy").is_empty(),"protection reward cannot be followed by destruction")
	for choice in ["destroy","enslave"]:
		var c: FrontierCampaign = fixture()
		event = discover(c,3)
		check(not c.choose_event(event.id,choice).is_empty(),"combat action requires AI robot")
		var guard: Dictionary = {"id":"test_guard", "model":"guardian", "name":"WARD", "grade":"rare", "traits":["sturdy","efficient"], "health":100.0}
		FrontierCampaign._reset_robot(guard,[30.0,28.0])
		c.planet.robots.append(guard)
		check(c.choose_event(event.id,choice).is_empty(),"start civilization operation "+choice)
		check(not c.sell_planet(c.planet.id).is_empty(),"cannot sell during unresolved combat")
		var sim := FrontierSimulation.new()
		for i in range(1500): sim.step(c,0.1)
		check(c.planet.conflict.is_empty() and c.planet.conflict_resolved == choice,"combat resolves "+choice)
		var report: Dictionary = FrontierEvaluator.report(c.planet)
		check(report.cleanup == 600 if choice == "destroy" else report.civilization == 0.8,"combat choice valuation "+choice)
	var rollback: FrontierCampaign = fixture()
	rollback.buy_technology("robotics")
	var old_state: Dictionary = rollback.state.duplicate(true)
	rollback.store = FrontierSaveStore.new("/does-not-exist/space-business/campaign.json")
	rollback.persistence_enabled = true
	check(not rollback.buy_technology("atmosphere").is_empty(),"failed transaction reports save error")
	check(rollback.profile.credits == old_state.profile.credits and not rollback.has_tech("atmosphere"),"failed purchase cannot spend funds")
	var planet_id: String = rollback.planet.id
	check(not rollback.sell_planet(planet_id).is_empty(),"failed sale reports save error")
	check(rollback.planet.id == planet_id and rollback.profile.credits == old_state.profile.credits,"failed sale preserves world and funds")
	rollback.persistence_enabled = false
	check(rollback.restart_business().is_empty(),"restart restores safe checkpoint")
	check(rollback.planet.is_empty() and rollback.profile.credits == 12000 and not rollback.has_tech("robotics"),"restart rolls back technology and credits together")
	print("EVENT_TESTS checks=%d failures=%d" % [checks,failures.size()])
	for failure in failures: print("  ",failure)
	quit(0 if failures.is_empty() else 1)
