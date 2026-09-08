extends "res://tests/test_crew_surface.gd"
## Focused two-site transaction/run check. Travel position and initial materials are fixtures.
var core: FrontierCrewAuthority
var actor: String
var metal: Dictionary
var cold: Dictionary
func command(kind: String,args: Dictionary={}) -> Dictionary:
	core.advance_time(core.now+.6)
	var result:=request(core,1,kind,args)
	if not result.ok:print("RESULT ",kind," ",result.get("error",""))
	return result
func visit(body: Dictionary) -> void:
	core.world.location=body.id;core.world.navigation_target=body.id
	core.world.crew.navigation.target=int(body.ordinal);core.world.crew.navigation.system=int(body.system_ordinal)
	core.world.crew.landing={"body_id":body.id,"epoch":1}
	core.world.crew.members[actor].aboard=false;core.world.crew.members[actor].area="surface"
	FrontierEcology.ensure_planet(core.world.ecology,body)
	FrontierExpeditionBusiness.ensure_site(core.world)
	move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
func move(p: Vector3) -> void:core.world.crew.members[actor].position=FrontierExpeditionBusiness.array(p)
func site() -> Dictionary:return FrontierExpeditionBusiness.site(core.world)
func factory() -> Dictionary:return site().buildings.get("fixture:factory",{})
func add_factory() -> void:
	for x in range(-35,30,5):
		for z in range(-30,30,5):
			var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),x,z,2)
			if not p.is_finite():continue
			if not FrontierExpeditionBusiness.placement(core.world,"factory",p,core.peers).is_empty():continue
			site().buildings["fixture:factory"]={"id":"fixture:factory","type":"factory","position":FrontierExpeditionBusiness.array(p),"yaw":0.0,"enabled":true,"active":true,"status":"가동 중","work":0.0,"tier":2}
			return
	check(false,"factory supported placement fixture")
func produce(id: String) -> void:
	move(FrontierCrewWorld.vector(factory().position)+Vector3(0,0,3))
	check(command("business_produce",{"building_id":"fixture:factory","product":id}).ok,"reserve "+id)
	# Product tick uses current powered factory; terrain/power is separately checked in the live scene.
	factory().active=true
	FrontierProductionTier2.tick(site(),30)
	check(factory().get("production",{}).is_empty(),"complete "+id)
func freight_to_ship(id: String,amount: int) -> void:
	move(FrontierCrewWorld.vector(site().center))
	check(command("business_withdraw",{"resource":id,"amount":amount}).ok,"withdraw local "+id)
	move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	check(command("deposit",{"resource":id,"amount":amount}).ok,"load shared ship "+id)
func freight_from_ship(id: String,amount: int) -> void:
	move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	check(command("withdraw",{"resource":id,"amount":amount}).ok,"unload shared ship "+id)
	move(FrontierCrewWorld.vector(site().center))
	check(command("business_deposit",{"resource":id,"amount":amount}).ok,"deliver destination "+id)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/planet-supply-20260908")
	core=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("공급 거점 검증",0);actor=owner.character_id
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"start")
	check(command("start_game").ok,"host starts session")
	core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"))
	core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
	core.world.ecology=FrontierEcology.create()
	var covered: Dictionary={}
	for i in range(8,220):
		var b:=FrontierUniverse.body(core.world.manifest,i)
		covered[b.traits.id]=true
		if b.get("mineral_profile",{}).get("id","")=="metallic" and metal.is_empty():metal=b
		if b.get("mineral_profile",{}).get("id","")=="cryogenic" and cold.is_empty():cold=b
	check(not metal.is_empty() and not cold.is_empty(),"seed provides both supply roles")
	if failures:quit(1);return
	visit(metal)
	check(command("business_register").ok,"one restoration contract")
	var before:=FrontierUniverse.fingerprint(core.world);disk_ok=false
	check(not command("business_lease").ok and FrontierUniverse.fingerprint(core.world)==before,"failed save rolls back lease and fee")
	disk_ok=true
	check(command("business_lease").ok,"metal lease")
	check(not command("business_lease").ok,"no duplicate purchase")
	add_factory();FrontierExpeditionBusiness.transfer(site().inventory,{"nickel":16,"titanium":8,"reinforced_frame":5,"control_circuit":2,"lithium":12,"ice":24,"refined_copper":4},1)
	produce("alloy_frame");produce("alloy_frame")
	move(FrontierCrewWorld.vector(factory().position))
	check(not command("business_produce",{"building_id":"fixture:factory","product":"cryo_cell"}).ok,"imported inputs do not bypass native processing role")
	freight_to_ship("alloy_frame",2)
	var metal_stock: Dictionary=site().inventory.duplicate(true)
	visit(cold)
	check(command("business_lease").ok and core.world.business.active==metal.id,"second production site preserves first restoration contract")
	add_factory();FrontierExpeditionBusiness.transfer(site().inventory,{"lithium":12,"ice":24,"refined_copper":4,"control_circuit":2,"reinforced_frame":2},1)
	produce("cryo_cell");produce("cryo_cell")
	check(core.world.business.sites[metal.id].inventory==metal_stock,"remote stock unchanged")
	freight_from_ship("alloy_frame",2)
	produce("industrial_core")
	move(FrontierCrewWorld.vector(factory().position))
	check(command("business_facility_upgrade",{"building_id":"fixture:factory"}).ok and int(factory().tier)==3,"two-site products install factory Mk.3")
	check(FrontierProductionTier2.factor(factory())==2.0,"Mk.3 actual production factor")
	var store:=FrontierWorldStore.new("/tmp/planet-supply-20260908/world.json")
	check(store.write(core.world),"save both sites and transported inventory: "+store.last_error)
	var loaded:=store.read_state();check(not loaded.is_empty() and FrontierUniverse.fingerprint(loaded)==FrontierUniverse.fingerprint(core.world),"reload preserves ledger exactly")
	if loaded.is_empty():quit(1);return
	core.world=loaded
	visit(metal)
	check(FrontierUniverse.fingerprint(site().inventory)==FrontierUniverse.fingerprint(metal_stock) and int(core.world.business.sites[cold.id].buildings["fixture:factory"].tier)==3,"revisit preserves separate factories and warehouses")
	# Restore-ready fixture exercises payout and transfer ownership without waiting for full terraforming.
	site().environment={"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":70.0,"ecology":70.0,"stable_seconds":40.0}
	if site().has("restoration2"):site().restoration2.salinity=10;site().restoration2.soil=70
	var credits:=int(core.world.business.credits);var payment:=FrontierPlanetSupply.settlement_payment(site(),int(metal.planet_tier),true)
	check(command("business_settle",{"retain":true}).ok,"settle retaining production assets")
	check(site().state=="supply" and not site().buildings.is_empty() and core.world.business.active.is_empty() and int(core.world.business.credits)==credits+payment,"retention pays reduced reward once and releases contract")
	check(not command("business_settle",{"retain":true}).ok and not command("business_register").ok,"retained contract cannot pay or register twice")
	var view:=core.snapshot();check(view.supply_sites.size()==2,"shared navigation lists both supply sites")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"final valid world")
	# Preserve scene-ready representative world for visual verification.
	visit(cold);move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	for x in range(-35,30,5):
		for z in range(-30,30,5):
			var p:=FrontierExpeditionBusiness.ground(FrontierCrewSurface.field(core.world),x,z,2.2)
			if not p.is_finite() or not FrontierExpeditionBusiness.placement(core.world,"solar",p,core.peers).is_empty():continue
			site().buildings["fixture:solar"]={"id":"fixture:solar","type":"solar","position":FrontierExpeditionBusiness.array(p),"yaw":0.0,"enabled":true,"active":true,"status":"발전 중","work":0.0}
			break
		if site().buildings.has("fixture:solar"):break
	check(site().buildings.has("fixture:solar"),"fixture generator")
	site().inventory.iron=80;site().inventory.lithium=12;site().inventory.ice=24;site().inventory.refined_copper=4
	FrontierExpeditionIndustry.tick(core.world,1)
	check(factory().active,"supported generator powers supply factory through actual industry tick")
	move(FrontierCrewWorld.vector(factory().position))
	check(command("business_produce",{"building_id":"fixture:factory","product":"cryo_cell"}).ok,"queue current-site work before leaving")
	var progress: float=factory().production.progress
	visit(metal);core.step_surface(1)
	check(float(core.world.business.sites[cold.id].buildings["fixture:factory"].production.progress)>progress,"offsite queued work continues")
	var remote_factory: Dictionary=core.world.business.sites[cold.id].buildings["fixture:factory"]
	var remote_progress:=float(remote_factory.production.progress)
	core.world.crew.landing={}
	core.step_surface(1)
	check(float(core.world.business.sites[cold.id].buildings["fixture:factory"].production.progress)>remote_progress,"industry continues during flight")
	var saved_progress:=float(core.world.business.sites[cold.id].buildings["fixture:factory"].production.progress)
	check(store.write(core.world),"persist remote progress in flight")
	core.world=store.read_state()
	check(float(core.world.business.sites[cold.id].buildings["fixture:factory"].production.progress)==saved_progress,"reload does not award elapsed real time")
	var before_failure:=FrontierUniverse.fingerprint(core.world)
	disk_ok=false;core.step_surface(1)
	check(core.stopped and FrontierUniverse.fingerprint(core.world)==before_failure,"failed production save freezes without exposing output")
	disk_ok=true;core.stopped=false
	visit(cold);core.step_surface(1)
	check(float(factory().production.progress)>progress,"return resumes actual industry work")
	factory().production={};move(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	check(store.write(core.world),"write live scene fixture")
	var profile_store:=FrontierPlayerProfile.new("/tmp/planet-supply-20260908/profile.json")
	profile_store.data={"version":1,"character":owner,"sessions":{}};check(profile_store.save(),"write isolated profile")
	print("SUPPLY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
