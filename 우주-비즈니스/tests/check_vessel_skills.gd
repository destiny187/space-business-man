extends "res://tests/check_pirate_rules.gd"
var fixture: Dictionary={}
func encounter_reset(hull: String="kestrel") -> Dictionary:
	var r:=FrontierSpaceCombat.record(world);r.encounter={};r.ships={};r.wrecks=[];stage()
	world.vessel.hull=hull
	FrontierSpaceCombat.begin(world,"crew","local_transit")
	var e: Dictionary=r.encounter;e.warning=100;e.resume=0
	var origin:=FrontierSpaceCombat.point(world.crew.navigation.position)
	while e.enemies.size()<4:
		var enemy: Dictionary=e.enemies[0].duplicate(true);enemy.id="check:"+str(e.enemies.size());e.enemies.append(enemy)
	for i in e.enemies.size():
		e.enemies[i].position=FrontierSpaceCombat.arr(origin+Vector3((i-1.5)*65,0,-260));e.enemies[i].hull=1000;e.enemies[i].shield=300
	return e
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("선체와 스킬 확인",0);actor=owner.character_id
	check(authority.start(FrontierUniverse.new_world(61739),owner,func(_w):return true),"host starts with current data")
	world=authority.world;authority.phase="playing"
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	if not world.has("vessel"):world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id)
	world.vessel.hulls=FrontierSpaceStation.config().hulls.keys();world.vessel.hull="kestrel";world.business.credits=4000000
	for index in range(1000,90000,1000):
		if FrontierSpaceCombat.tier(world,index)>=3 and not FrontierSpaceStation.definition(world.manifest,index).is_empty():system=index;break
	check(system>0,"tiered combat region and station exist")
	for hull in ["aster","peregrine","ox","orion","spectre","atlas"]:
		var vessel:Dictionary=world.vessel.duplicate();vessel.hull=hull
		check(FrontierVesselAccess.tier_for(FrontierVesselAccess.capabilities(vessel))==int(FrontierSpaceStation.config().hulls[hull].ship_tier),hull+" has matching navigation capability")
	check(FrontierVesselSkills.cargo_capacity({"hull":"atlas"})>FrontierVesselSkills.cargo_capacity({"hull":"ox"}) and FrontierVesselSkills.cargo_capacity({"hull":"ox"})>FrontierVesselSkills.cargo_capacity({"hull":"mule"}),"cargo role expands actual slots")
	check(not world.vessel.has("combat_skills") and FrontierVesselSkills.equipped(world.vessel).size()==2,"old saves read starter slots without mutating")
	var original:Dictionary=world.vessel.duplicate(true)
	check(not FrontierVesselSkills.apply(world,"station_skill_equip",{"item":"phase_lance","slot":1}).is_empty() and world.vessel==original,"unowned skill cannot mutate loadout")
	check(FrontierVesselSkills.apply(world,"station_skill_buy",{"item":"phase_lance"}).is_empty(),"another hull signature is separately acquired")
	check(FrontierVesselSkills.apply(world,"station_skill_equip",{"item":"phase_lance","slot":1}).is_empty(),"acquired signature equips on basic hull")
	check(not FrontierVesselSkills.apply(world,"station_skill_equip",{"item":"phase_lance","slot":2}).is_empty(),"same skill cannot stack in both slots")
	check(FrontierVesselSkills.apply(world,"station_skill_upgrade",{"item":"phase_lance"}).is_empty(),"acquired skill strengthens")
	world.vessel.hull="spectre"
	check(FrontierVesselSkills.level(world.vessel,FrontierVesselSkills.signature_skill(world.vessel))==1,"upgrade applies to embedded signature too")
	world.vessel.hull="kestrel"
	check(FrontierVesselSkills.equipped(world.vessel)[0]=="phase_lance","changing back restores hull loadout")
	var e:=encounter_reset();var r:=FrontierSpaceCombat.record(world)
	check(FrontierSpaceSkills.activate(world,actor,0,Vector3.FORWARD) and e.projectiles.size()==2 and e.projectiles[0].target_id!=e.projectiles[1].target_id,"base signature fires one missile at each of two targets")
	check(not FrontierSpaceSkills.activate(world,actor,0,Vector3.FORWARD),"shared skill cooldown rejects repeated activation")
	e=encounter_reset();world.vessel.combat_skills.levels["seeker_salvo"]=4
	check(FrontierSpaceSkills.activate(world,actor,0,Vector3.FORWARD) and e.projectiles.size()==12,"maximum reinforcement fires three missiles at four targets")
	var before:float=e.enemies[0].shield
	for i in 40:FrontierSpaceCombatPilot.projectiles(world,.05)
	check(e.enemies[0].shield<before,"guided missiles deliver damage through actual collision")
	e=encounter_reset("spectre");before=e.enemies[1].shield;e.enemies[1].position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(world.crew.navigation.position)+Vector3(0,0,-260))
	check(FrontierSpaceSkills.activate(world,actor,0,Vector3.FORWARD) and e.enemies[1].shield==before,"lance prepares before applying damage")
	FrontierSpaceSkills.tick_ship(world,1.2)
	check(e.enemies[1].shield<before,"charged lance fires into its committed direction")
	# Every effect family executes against actual host target records.
	for id in FrontierVesselSkills.definitions():
		e=encounter_reset();world.vessel.combat_skills.unlocked=FrontierVesselSkills.definitions().keys();world.vessel.combat_skills.loadouts.kestrel=[id,"forward_barrier"]
		FrontierSpaceSkills.stats(world).heat=.8
		e.enemies[0].position=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(world.crew.navigation.position)+Vector3(0,0,-180))
		check(FrontierSpaceSkills.activate(world,actor,1,Vector3.FORWARD),"activate "+id)
		FrontierSpaceSkills.tick_ship(world,.1)
		check(FrontierSpaceCombat.valid(JSON.parse_string(JSON.stringify(r))),"serialize runtime "+id)
	e=encounter_reset();world.vessel.combat_skills.loadouts.kestrel=["forward_barrier","wake_mines"]
	FrontierSpaceSkills.activate(world,actor,1,Vector3.FORWARD);var origin:=FrontierSpaceCombat.point(world.crew.navigation.position)
	before=FrontierSpaceSkills.stats(world).shield
	FrontierSpaceCombat.damage_ship(world,"crew",30,origin+Vector3.FORWARD*100)
	check(FrontierSpaceSkills.stats(world).shield==before,"front barrier intercepts forward damage")
	FrontierSpaceCombat.damage_ship(world,"crew",30,origin+Vector3.BACK*100)
	check(FrontierSpaceSkills.stats(world).shield==before-30,"rear attack bypasses directional barrier")
	FrontierSpaceSkills.activate(world,actor,2,Vector3.FORWARD)
	var mine:Dictionary=e.deployables[0];e.enemies[0].position=mine.position.duplicate();before=e.enemies[0].shield
	FrontierSpaceSkills.tick_ship(world,.9)
	check(e.enemies[0].shield<before and e.deployables.is_empty(),"armed physical mine hits once and is removed")
	e=encounter_reset("aster");world.vessel.combat_skills.loadouts.aster=["decoy_beacon","vector_burst"]
	FrontierSpaceSkills.activate(world,actor,1,Vector3.FORWARD)
	check(FrontierSpaceSkills.decoy_target(world,origin,origin+Vector3.FORWARD*50)!=origin+Vector3.FORWARD*50,"beacon redirects next enemy aiming")
	FrontierSpaceSkills.activate(world,actor,2,Vector3.FORWARD)
	check(FrontierSpaceSkills.movement(world).x>1 and FrontierSpaceSkills.movement(world).y>1,"boost skill changes speed and turn together")
	e=encounter_reset("ox");var victim:Dictionary=e.enemies[1]
	victim.shield=2.0;victim.mark_left=5.0;victim.mark_multiplier=1.3;before=victim.hull
	FrontierSpaceCombat.damage_enemy(world,victim,20,origin,FrontierSpaceCombat.point(victim.position),true)
	check(victim.shield==0 and victim.hull==before,"vulnerability cannot spill shield-only snare damage into hull")
	FrontierSpaceCombat.damage_ship(world,"crew",FrontierVesselSkills.shield_max(world),origin+Vector3.BACK*100)
	before=world.crew.navigation.hull;FrontierSpaceCombat.damage_ship(world,"crew",20,origin+Vector3.BACK*100)
	check(world.crew.navigation.hull==before-10 and FrontierSpaceSkills.stats(world).passive_cooldown>0,"cargo passive halves follow-up hull damage after shield breaks")
	e=encounter_reset("swift");FrontierSpaceSkills.stats(world).heat=.8;world.crew.navigation.boosting=true;FrontierSpaceSkills.tick_ship(world,1.6)
	world.crew.navigation.boosting=false;FrontierSpaceSkills.tick_ship(world,.1)
	check(FrontierSpaceSkills.stats(world).cooling_left>0 and FrontierSpaceSkills.stats(world).heat<.8,"speed passive cools after a sustained boost ends")
	e=encounter_reset();victim=e.enemies[1];victim.position=FrontierSpaceCombat.arr(origin+Vector3(0,0,-260));victim.mark_left=0.0;victim.mark_multiplier=1.3
	FrontierSpaceCombat.fire(world,actor,Vector3.FORWARD)
	check(is_equal_approx(float(victim.mark_multiplier),1.18),"expired active mark cannot become a stronger permanent passive mark")
	# Validate management after deliberately unrestricted effect fixtures are replaced.
	world.vessel.combat_skills.loadouts={"kestrel":["phase_lance","forward_barrier"],"aster":["decoy_beacon","vector_burst"]}
	check(FrontierVesselRefit.validate(JSON.parse_string(JSON.stringify(world.vessel)),int(world.manifest.seed),world.crew.world_id).is_empty(),"hulls and skill ownership survive serialized validation")
	var draft:=preload("res://scripts/persistence/world_draft.gd").request(world,actor,"station_skill_upgrade")
	check(is_same(draft.business.sites,world.business.sites) and not is_same(draft.vessel,world.vessel) and not is_same(draft.crew.members[actor],world.crew.members[actor]),"skill management copies only its write scope")
	var station:=FrontierSpaceStation.definition(world.manifest,system);var base:=FrontierSpaceStation.market(world.manifest,system)
	var old_stock:Dictionary=base.stock.duplicate()
	for id in old_stock.keys():
		if str(id).begins_with("hull:") and int(FrontierSpaceStation.config().hulls[str(id).trim_prefix("hull:")].ship_tier)>=3:old_stock.erase(id)
	var basic:String="hull:swift" if old_stock.has("hull:swift") else "hull:mule";old_stock[basic]=0
	world.station_markets={};world.station_markets[str(station.id)]=old_stock
	check(FrontierSpaceStation.validate(world).is_empty(),"legacy station inventory accepts only the missing new hull entries")
	var offer:=FrontierSpaceStation.Economy.project(world,station,base)
	check(offer.stock[basic]==0 and offer.stock["hull:aster"]==1,"new hull stock appears without replenishing a purchased old hull")
	world.vessel.hull="atlas";world.crew.navigation.position=station.position.duplicate();world.crew.navigation.speed=0;world.crew.cargo={"iron":FrontierItemInventory.stack_size("iron")*11};world.crew.rock=0
	draft=preload("res://scripts/persistence/world_draft.gd").request(world,actor,"station_equip")
	var refusal:=FrontierSpaceStation.apply(draft,actor,"station_equip",{"item":"kestrel"},authority.peers)
	check(refusal.contains("화물") and world.vessel.hull=="atlas" and world.crew.cargo.iron==FrontierItemInventory.stack_size("iron")*11,"cargo overflow rejects smaller hull in its isolated transaction")
	print("VESSEL_SKILL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
