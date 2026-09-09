class_name FrontierCrewVitals
extends RefCounted
## Host simulation only. Values travel with world members, never client profile claims.
static func config() -> Dictionary:return FrontierCrewSurface.config().vitals
static func create() -> Dictionary:
	return {"health":float(config().maximum_health),"stamina":float(config().maximum_stamina),"rest":0.0,"hurt":0.0,"exhausted":false,"sprinting":false,"damage_serial":0,"rescue_serial":0,"protection":0.0}
static func ensure(member: Dictionary) -> Dictionary:
	if not member.has("vitals"):
		member.vitals=create();member.vitals.health=FrontierCrewAugmentation.maximum_health(member)
	return member.vitals
static func validate(v: Variant,member: Dictionary={}) -> bool:
	if not v is Dictionary:return false
	for key in ["health","stamina","rest","hurt","protection","damage_serial","rescue_serial"]:
		if not FrontierUniverse._finite(v.get(key),0,9007199254740000):return false
	return v.health<=FrontierCrewAugmentation.maximum_health(member) and v.stamina<=config().maximum_stamina and v.get("exhausted") is bool and v.get("sprinting") is bool
static func step(member: Dictionary,delta: float,wants_sprint: bool,moving: bool) -> float:
	var v:=ensure(member);var c:=config()
	v.hurt=maxf(0,v.hurt-delta);v.protection=maxf(0,v.protection-delta)
	if v.exhausted and v.stamina>=c.exhaustion_release:v.exhausted=false
	v.sprinting=member.area=="surface" and wants_sprint and moving and not v.exhausted and v.stamina>0
	if v.sprinting:
		v.stamina=maxf(0,v.stamina-c.stamina_drain*FrontierCrewAugmentation.multiplier(member,"endurance")*delta*(float(FrontierProductionTier2.config().suit_upgrade.stamina_factor) if int(FrontierEquipment.state(member).get("suit_tier",1))==2 else 1.0));v.rest=c.recovery_delay
		if v.stamina<=0:v.exhausted=true;v.sprinting=false
	else:
		v.rest=maxf(0,v.rest-delta)
		if v.rest<=0:v.stamina=minf(c.maximum_stamina,v.stamina+c.stamina_recovery*FrontierCrewAugmentation.multiplier(member,"stamina_recovery")*delta)
	var near_ship: bool=member.area=="cabin" or FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	if near_ship and v.hurt<=0:v.health=minf(FrontierCrewAugmentation.maximum_health(member),v.health+c.heal_per_second*FrontierCrewAugmentation.multiplier(member,"healing")*delta)
	return float(c.sprint_multiplier) if v.sprinting else 1.0
static func land(member: Dictionary,impact_speed: float) -> bool:
	var v:=ensure(member);var c:=config()
	if v.protection>0 or impact_speed<=c.fall_safe_speed:return false
	v.health=maxf(0,v.health-(impact_speed-c.fall_safe_speed)*c.fall_damage_scale*FrontierCrewAugmentation.multiplier(member,"fall_guard")*(float(FrontierProductionTier2.config().suit_upgrade.fall_damage_factor) if int(FrontierEquipment.state(member).get("suit_tier",1))==2 else 1.0))
	v.hurt=c.heal_delay*FrontierCrewAugmentation.multiplier(member,"recovery_delay");v.damage_serial+=1
	if v.health>0:return false
	v.health=c.rescue_health;v.protection=c.rescue_protection;v.rescue_serial+=1
	v.sprinting=false
	return true
