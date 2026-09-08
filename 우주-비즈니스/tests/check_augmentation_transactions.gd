extends "res://tests/test_crew_surface.gd"
var station: Dictionary={}
func args_for(field: String="mobility",expected: int=0) -> Dictionary:
	return {"station_id":"ship:augmentation","field":field,"expected_level":expected}
func denied(core: FrontierCrewAuthority,peer: int,args: Dictionary,label: String) -> void:
	var before:=FrontierUniverse.fingerprint(core.world)
	var result:=request(core,peer,"augmentation_upgrade",args)
	check(not result.ok and before==FrontierUniverse.fingerprint(core.world),label)
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("증강 거래 호스트",0)
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"host starts")
	check(request(core,1,"start_game").ok,"start play")
	core.world.business=FrontierExpeditionBusiness.create()
	core.world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory()
	var bag: Dictionary=core.world.business.bags[owner.character_id]
	bag.sapphire=9;bag.ruby=9;bag.emerald=9
	core.world.crew.members[owner.character_id].vitals.health=80.0
	denied(core,1,args_for(),"unconnected physical station rejects without charge")
	station={"enabled":true,"area":"cabin","position":FrontierCrewWorld.vector(core.world.crew.members[owner.character_id].position)}
	core.augmentation_station_provider=func(_actor: String,_station: String):return station
	check(FrontierCrewAugmentation.cost("mobility",0)=={"sapphire":3} and FrontierCrewAugmentation.cost("mobility",4)=={"sapphire":15},"gem costs follow target level")
	var forged:=args_for();forged.character_id="someone_else"
	denied(core,1,forged,"cannot choose another character")
	forged=args_for();forged.price=0
	denied(core,1,forged,"cannot override price")
	forged=args_for();forged.station_id="remote:augmentation"
	denied(core,1,forged,"unknown station rejected")
	denied(core,1,args_for("unknown"),"unknown field rejected")
	forged=args_for();forged.expected_level="0"
	denied(core,1,forged,"non-numeric expected level rejected")
	station.enabled=false;denied(core,1,args_for(),"inactive station rejected");station.enabled=true
	station.position+=Vector3(20,0,0);denied(core,1,args_for(),"host checks interaction distance");station.position-=Vector3(20,0,0)
	station.area="surface";denied(core,1,args_for(),"different space rejected");station.area="cabin"
	var retry:=envelope(core,1,"augmentation_upgrade",args_for())
	var before:=FrontierUniverse.fingerprint(core.world)
	disk_ok=false
	var result:=core.request(1,retry)
	check(not result.ok and not result.has("augmentation") and before==FrontierUniverse.fingerprint(core.world),"save failure rolls back gems, level and receipt")
	disk_ok=true;result=core.request(1,retry)
	check(result.ok and result.augmentation.spent=={"sapphire":3} and result.augmentation.level==1,"same failed request can commit once after storage recovers")
	check(core.world.business.bags[owner.character_id].sapphire==6 and core.world.crew.members[owner.character_id].augmentation.levels.mobility==1,"charge and growth committed together")
	before=FrontierUniverse.fingerprint(core.world)
	check(core.request(1,retry)==result and before==FrontierUniverse.fingerprint(core.world),"exact replay returns durable result without second charge")
	var altered:=retry.duplicate(true);altered.args.field="combat"
	check(not core.request(1,altered).ok,"same sequence cannot change augmentation")
	denied(core,1,args_for(),"new sequence with old expected level cannot consume next tier")
	var stale:=envelope(core,1,"augmentation_upgrade",args_for("mobility",1));stale.revision-=1
	check(not core.request(1,stale).ok,"stale world revision rejected")
	result=request(core,1,"augmentation_upgrade",args_for("mobility",1))
	check(result.ok and core.world.business.bags[owner.character_id].sapphire==0 and result.augmentation.spent=={"sapphire":6},"second tier costs six gems")
	denied(core,1,args_for("mobility",2),"insufficient personal gems rejected")
	var health: float=core.world.crew.members[owner.character_id].vitals.health
	result=request(core,1,"augmentation_upgrade",args_for("vitality"))
	check(result.ok and result.augmentation.maximum_health==120.0 and core.world.crew.members[owner.character_id].vitals.health==health,"health upgrade preserves current health")
	result=request(core,1,"augmentation_upgrade",args_for("combat"))
	check(result.ok and core.world.business.bags[owner.character_id].ruby==6,"combat consumes ruby")
	core.world.crew.members[owner.character_id].augmentation.levels.combat=5
	denied(core,1,args_for("combat",5),"maximum level cannot spend gems")
	var guest:=FrontierPlayerProfile.new_character("증강 동료",1)
	var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok,"second player joins")
	core.world.crew.members[guest.character_id].position=FrontierExpeditionBusiness.array(station.position)
	core.world.crew.cargo={"ruby":99}
	denied(core,2,args_for("combat"),"guest cannot spend ship cargo or host gems")
	core.world.business.bags[guest.character_id]=FrontierExpeditionBusiness.inventory()
	core.world.business.bags[guest.character_id].ruby=3
	result=request(core,2,"augmentation_upgrade",args_for("combat"))
	check(result.ok and core.world.crew.members[guest.character_id].augmentation.levels.combat==1 and core.world.business.bags[guest.character_id].ruby==0,"guest spends own gems and grows independently")
	check(core.world.crew.members[owner.character_id].augmentation.levels.combat==5 and core.world.crew.cargo.ruby==99,"host and common cargo preserved")
	var local:=core.world.duplicate(true);local.local_shuttle=guest.character_id
	check(not FrontierCrewAugmentation.reason(local,guest.character_id,args_for("combat",1),station).is_empty(),"FINCH context cannot use main ship station")
	var restored:=FrontierCrewAuthority.new()
	check(restored.start(saved,owner,persist),"committed world reloads")
	check(restored.world.crew.members[guest.character_id].augmentation.levels.combat==1 and restored.world.business.bags[guest.character_id].ruby==0,"reload preserves paid guest growth without refund")
	check(not owner.has("augmentation") and not guest.has("augmentation"),"original profiles unchanged")
	print("AUGMENTATION_A02 ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
