extends SceneTree

var c := FrontierCampaign.new("user://test_workflow.json")
var sim := FrontierSimulation.new()
var checks: int = 0
var failures: Array[String] = []
var mined: int = 0

func _initialize() -> void: call_deferred("run")
func check(condition: bool,label: String) -> void:
	checks += 1
	if not condition: failures.append(label); push_error(label)

func run() -> void:
	c.persistence_enabled = false
	check(c.new_campaign().is_empty(),"new business without granted resources")
	var retained_id: String = ""
	var retained_grade: String = ""
	var retained_traits: Array = []
	for kind in ["basalt","glacial","sulfur"]:
		check(c.buy_planet(kind,[] if retained_id.is_empty() else [retained_id]).is_empty(),"purchase "+kind)
		for tech in ["robotics","atmosphere","thermal","water","biotech","recovery"]:
			if not c.has_tech(tech): check(c.buy_technology(tech).is_empty(),"purchase essential technology "+tech)
		if c.profile.ship == 0: check(c.upgrade_ship().is_empty(),"buy recovery transport")
		for building in ["solar","charger","factory"]: construct(building)
		sim.step(c,0.1)
		if retained_id.is_empty():
			gather(FrontierCatalog.entry("robots","miner").cost)
			check(c.craft("miner").is_empty(),"manufacture from mined materials")
			advance(24)
			check(c.planet.robots.size() == 1,"first robot leaves factory")
			if c.planet.robots.is_empty(): break
			retained_id = c.planet.robots[0].id
			retained_grade = c.planet.robots[0].grade
			retained_traits = c.planet.robots[0].traits.duplicate()
		else:
			check(c.planet.robots[0].id == retained_id and c.planet.robots[0].grade == retained_grade and c.planet.robots[0].traits == retained_traits,"same recovered robot on "+kind)
		check(c.assign_robot(retained_id,"iron").is_empty(),"assign mining")
		for building in ["storage","solar","atmosphere","thermal","water","biolab"]: construct(building)
		gather({"ice":100})
		var discovered: Dictionary = c.planet.events[0]
		move_to(FrontierCampaign.point(discovered.position)+Vector2(0,4))
		check(c.discover(discovered.id).is_empty(),"explore ruins")
		check(c.choose_event(discovered.id,"preserve").is_empty(),"preserve discovery value")
		advance(70)
		c.persistence_enabled = true
		check(c.save().is_empty(),"save active production")
		var saved_state: Dictionary = c.state.duplicate(true)
		var resumed := FrontierCampaign.new("user://test_workflow.json")
		check(resumed.load_campaign(),"resume active business")
		check(equivalent(resumed.state,saved_state),"restore production inventory environment")
		c = resumed
		c.persistence_enabled = false
		sim = FrontierSimulation.new()
		advance(1100)
		var report: Dictionary = FrontierEvaluator.report(c.planet,[retained_id])
		check(report.grade in ["S","A","B"],"habitable grade on "+kind)
		var old_id: String = c.planet.id
		var money: int = c.profile.credits
		check(c.sell_planet(old_id,[retained_id]).is_empty(),"sell and recover "+kind)
		check(c.profile.credits == money+report.price and c.profile.hangar.size() == 1,"settlement and custody exact")
		check(not c.sell_planet(old_id,[retained_id]).is_empty(),"duplicate settlement rejected")
		check(c.profile.credits > 10000,"business funds next expedition")
		print("WORKFLOW_ROUND ",kind," grade=",report.grade," sale=",report.price," cash=",c.profile.credits)
	check(c.profile.round == 3 and mined > 500,"three organic resource-funded rounds completed")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists("user://test_workflow.json"+suffix): DirAccess.remove_absolute("user://test_workflow.json"+suffix)
	print("WORKFLOW_TESTS checks=%d failures=%d manual_units=%d" % [checks,failures.size(),mined])
	quit(0 if failures.is_empty() else 1)

func advance(seconds: float) -> void:
	for i in range(ceili(seconds/0.25)): sim.step(c,0.25)

func equivalent(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	if a is float and b is float: return absf(a-b) <= 1e-9
	return a == b

func move_to(destination: Vector2) -> void:
	var distance: float = FrontierCampaign.point(c.planet.player.position).distance_to(destination)
	advance(distance/5.5)
	c.planet.player.position = [destination.x,destination.y]

func gather(cost: Dictionary) -> void:
	for resource in cost:
		var limit: int = 0
		while int(c.planet.inventory.get(resource,0)) < int(cost[resource]) and limit < 500:
			limit += 1
			if FrontierCatalog.total(c.planet.inventory) >= c.capacity()-140:
				var largest: String = ""
				for key in c.planet.inventory:
					if key != resource and (largest.is_empty() or c.planet.inventory[key] > c.planet.inventory[largest]): largest = key
				if not largest.is_empty(): c.discard_inventory(largest,mini(140,c.planet.inventory[largest]))
			var candidate: Dictionary = {}
			for node in c.planet.nodes:
				if node.resource == resource and node.amount > 0: candidate = node; break
			if candidate.is_empty(): check(false,"available reserve "+resource); return
			move_to(FrontierCampaign.point(candidate.position)+Vector2(0,3.5))
			var needed: int = mini(140,int(cost[resource])-int(c.planet.inventory.get(resource,0)))
			while needed > 0 and candidate.amount > 0:
				var amount: int = mini(16,needed)
				var before: int = candidate.amount
				var error: String = c.mine(candidate.id,amount)
				if not error.is_empty(): check(false,error); break
				mined += before-int(candidate.amount)
				needed -= amount
				advance(0.35)
			move_to(Vector2(0,5))
			check(c.deposit().is_empty(),"deposit mined "+resource)
		check(c.planet.inventory.get(resource,0) >= cost[resource],"fund resource "+resource)

func construct(kind: String) -> void:
	gather(FrontierCatalog.entry("buildings",kind).cost)
	for y in range(-20,25,6):
		for x in range(-20,25,6):
			if c.placement_error(kind,Vector2(x,y)).is_empty():
				check(c.build(kind,Vector2(x,y)).is_empty(),"construct "+kind)
				return
	check(false,"placement available "+kind)
