extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func run() -> void:
	var c := FrontierCampaign.new("user://test_onboarding.json")
	c.persistence_enabled = false
	check(c.new_campaign().is_empty(),"new guided profile validates")
	check(FrontierOnboarding.current(c.state).id == "contract","contract is first")
	check(c.buy_planet("basalt").is_empty(),"first contract")
	check(FrontierOnboarding.current(c.state).id == "move","landing precedes gathering")
	FrontierOnboarding.record(c.state,"travel",6)
	FrontierOnboarding.sync(c.state)
	check(FrontierOnboarding.current(c.state).id == "mine","actual travel unlocks gathering")
	var ore: Dictionary = c.planet.nodes[0]
	c.planet.player.position = ore.position.duplicate()
	c.mine(ore.id,16); c.mine(ore.id,16)
	check(FrontierOnboarding.current(c.state).id == "deposit","actual mined units advance tutorial")
	check(FrontierOnboarding.current(c.state).position == Vector2.ZERO,"guide leads cargo to base")
	c.planet.player.position = [0.0,5.0]
	c.deposit()
	check(FrontierOnboarding.current(c.state).id == "robotics","deposit then research")
	check(c.profile.onboarding.deposited == 32,"records only deposited units")
	c.deposit()
	check(c.profile.onboarding.deposited == 32,"empty deposit does not advance counters")
	c.buy_technology("robotics")
	check(FrontierOnboarding.current(c.state).id == "solar","power is the first construction lesson")
	check(FrontierOnboarding.current(c.state).target_label.contains("광맥"),"missing construction materials have navigation")
	c.persistence_enabled = true
	check(c.save().is_empty(),"persist guide")
	var loaded := FrontierCampaign.new("user://test_onboarding.json")
	check(loaded.load_campaign(),"reload guided campaign")
	check(loaded.profile.onboarding.completed == c.profile.onboarding.completed and int(loaded.profile.onboarding.mined) == int(c.profile.onboarding.mined) and int(loaded.profile.onboarding.deposited) == int(c.profile.onboarding.deposited) and is_equal_approx(loaded.profile.onboarding.travel,c.profile.onboarding.travel),"completed steps and counters survive reload")
	loaded.persistence_enabled = false
	check(loaded.set_guide(false).is_empty() and FrontierOnboarding.current(loaded.state).is_empty(),"hide guide without resetting progress")
	check(loaded.set_guide(true).is_empty() and FrontierOnboarding.current(loaded.state).id == "solar","resume guide at same step")
	var legacy: Dictionary = c.state.duplicate(true)
	legacy.profile.erase("onboarding")
	check(FrontierSaveSchema.validate(legacy).is_empty(),"legacy saves remain valid")
	check(FrontierOnboarding.current(legacy).is_empty(),"legacy players do not get forced into tutorial")
	for key in ["travel","mined","deposited","delivered"]:
		var bad: Dictionary = c.state.duplicate(true)
		bad.profile.onboarding[key] = -1
		check(not FrontierSaveSchema.validate(bad).is_empty(),"reject negative guide "+key)
	var duplicate: Dictionary = c.state.duplicate(true)
	duplicate.profile.onboarding.completed = ["mine","mine"]
	check(not FrontierSaveSchema.validate(duplicate).is_empty(),"reject repeated tutorial IDs")
	var civ: Dictionary = c.planet.events[3]
	var old_health: float = civ.health
	check(not c.pulse_attack(civ.id).is_empty() and civ.health == old_health,"neutral civilizations cannot be attacked")
	c.persistence_enabled = false
	c.planet.conflict = civ.id; c.planet.conflict_order = "destroy"
	civ.discovered = true; civ.choice = "destroy_pending"
	c.planet.player.position = [civ.position[0],civ.position[1]+10.0]
	check(c.pulse_attack(civ.id).is_empty(),"pulse supports an existing operation")
	check(FrontierCampaign.find_by_id(c.planet.events,civ.id).health == old_health-5,"pulse changes actual operation health")
	var far: Array = [-70.0,-70.0] if FrontierCampaign.point(civ.position).distance_to(Vector2(-70,-70)) > 25 else [70.0,70.0]
	c.planet.player.position = far
	check(not c.pulse_attack(civ.id).is_empty(),"pulse cannot damage beyond range")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists("user://test_onboarding.json"+suffix): DirAccess.remove_absolute("user://test_onboarding.json"+suffix)
	print("ONBOARDING_TESTS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
