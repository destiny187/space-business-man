class_name FrontierCrewVitals
extends RefCounted
## Host simulation only. Values travel with world members, never client profile claims.
static func config() -> Dictionary:return FrontierCrewSurface.config().vitals
static func create() -> Dictionary:
	return {"health":float(config().maximum_health),"stamina":float(config().maximum_stamina),"rest":0.0,"hurt":0.0,"exhausted":false,"sprinting":false,"damage_serial":0,"rescue_serial":0,"protection":0.0}
static func ensure(member: Dictionary) -> Dictionary:
	if not member.has("vitals"):
		member.vitals=create();member.vitals.health=FrontierCrewAugmentation.maximum_health(member)
	for key in ["shield","shield_wait","shield_serial","shield_break_serial","combat_wait","shield_haste","legendary_serial","stationary_time"]:
		if not member.vitals.has(key):member.vitals[key]=0.0
	if not member.vitals.has("legendary_effect"):member.vitals.legendary_effect=""
	return member.vitals
static func validate(v: Variant,member: Dictionary={}) -> bool:
	if not v is Dictionary:return false
	for key in ["health","stamina","rest","hurt","protection","damage_serial","rescue_serial"]:
		if not FrontierUniverse._finite(v.get(key),0,9007199254740000):return false
	for key in ["shield","shield_wait","shield_serial","shield_break_serial","combat_wait","shield_haste","legendary_serial","stationary_time"]:
		if not FrontierUniverse._finite(v.get(key,0),0,9007199254740000):return false
	if v.get("legendary_effect","")!="" and not FrontierSuitModules.config().legendary.has(v.get("legendary_effect")):return false
	if float(v.get("shield",0))>FrontierSuitModules.shield_max(member)+.001:return false
	return v.health<=FrontierCrewAugmentation.maximum_health(member) and v.stamina<=config().maximum_stamina and v.get("exhausted") is bool and v.get("sprinting") is bool
static func step(member: Dictionary,delta: float,wants_sprint: bool,moving: bool,stationary: bool=false,carrying: bool=false) -> float:
	var v:=ensure(member);var c:=config()
	v.stationary_time=float(v.stationary_time)+delta if stationary else 0.0
	var charge_factor:=float(FrontierSuitModules.config().legendary.stationary_charge.factor) if FrontierSuitModules.has_effect(member,"stationary_charge") and v.stationary_time>=float(FrontierSuitModules.config().legendary.stationary_charge.seconds) else 1.0
	var peaceful_delta:=maxf(0,delta-maxf(float(v.combat_wait),float(v.hurt)))
	v.combat_wait=maxf(0,v.combat_wait-delta);v.shield_haste=maxf(0,v.shield_haste-delta)
	if peaceful_delta>0 and FrontierSuitModules.has_effect(member,"field_regeneration"):
		heal(member,FrontierCrewAugmentation.maximum_health(member)*float(FrontierSuitModules.config().legendary.field_regeneration.rate)*peaceful_delta)
	v.shield_wait=maxf(0,v.shield_wait-delta)
	if v.shield_wait<=0:v.shield=minf(FrontierSuitModules.shield_max(member),v.shield+float(FrontierSuitModules.config().shield.rate)*FrontierSuitModules.factor(member,"shield_rate")*charge_factor*delta)
	v.hurt=maxf(0,v.hurt-delta);v.protection=maxf(0,v.protection-delta)
	if v.exhausted and v.stamina>=c.exhaustion_release:v.exhausted=false
	v.sprinting=member.area=="surface" and wants_sprint and moving and not v.exhausted and v.stamina>0
	if v.sprinting:
		v.stamina=maxf(0,v.stamina-(0.0 if carrying and FrontierSuitModules.has_effect(member,"carrier_engine") else float(c.stamina_drain))*FrontierCrewAugmentation.multiplier(member,"endurance")*(1.0-FrontierSuitModules.bonus(member,"endurance"))*delta*(float(FrontierProductionTier2.config().suit_upgrade.stamina_factor) if int(FrontierEquipment.state(member).get("suit_tier",1))==2 else 1.0));v.rest=c.recovery_delay
		if v.stamina<=0:v.exhausted=true;v.sprinting=false
	else:
		v.rest=maxf(0,v.rest-delta)
		if v.rest<=0:v.stamina=minf(c.maximum_stamina,v.stamina+c.stamina_recovery*FrontierCrewAugmentation.multiplier(member,"stamina_recovery")*delta)
	var near_ship: bool=member.area=="cabin" or FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	if near_ship and v.hurt<=0:heal(member,c.heal_per_second*FrontierCrewAugmentation.multiplier(member,"healing")*FrontierSuitModules.factor(member,"healing")*delta)
	return float(c.sprint_multiplier) if v.sprinting else 1.0
static func land(member: Dictionary,impact_speed: float) -> bool:
	var v:=ensure(member);var c:=config()
	if v.protection>0 or impact_speed<=c.fall_safe_speed:return false
	v.health=maxf(0,v.health-(impact_speed-c.fall_safe_speed)*c.fall_damage_scale*FrontierCrewAugmentation.multiplier(member,"fall_guard")*(float(FrontierProductionTier2.config().suit_upgrade.fall_damage_factor) if int(FrontierEquipment.state(member).get("suit_tier",1))==2 else 1.0)*(float(FrontierSuitModules.config().legendary.fall_cushion.factor) if FrontierSuitModules.has_effect(member,"fall_cushion") else 1.0))
	v.hurt=c.heal_delay*FrontierCrewAugmentation.multiplier(member,"recovery_delay");v.damage_serial+=1
	if v.health>0:return false
	v.shield=0.0;v.shield_wait=FrontierSuitModules.shield_delay(member)
	v.health=c.rescue_health;v.protection=c.rescue_protection;v.rescue_serial+=1
	v.sprinting=false
	return true

# All present/future physical combat calls this host-only entry point. Fall remains separate.
static func damage(member: Dictionary,amount: float,kind: String="combat",shield_multiplier: float=1.0) -> bool:
	var v:=ensure(member)
	if amount<=0 or v.protection>0:return false
	FrontierSuitModules.enter_combat(member)
	amount*=1.0-FrontierSuitModules.bonus(member,"guard")
	if kind=="blast":amount*=1.0-FrontierSuitModules.bonus(member,"blast")
	v.shield_wait=FrontierSuitModules.shield_delay(member)
	var split:=split_shield_damage(float(v.shield),amount,shield_multiplier)
	var absorbed: float=split.absorbed
	amount=split.health
	if absorbed>0:
		v.shield-=absorbed;v.shield_serial+=1
		if v.shield<=0:
			v.shield_break_serial+=1
			if FrontierSuitModules.has_effect(member,"break_dash"):
				v.shield_haste=float(FrontierSuitModules.config().legendary.break_dash.seconds);v.legendary_serial+=1;v.legendary_effect="break_dash"
	if amount>0:
		v.health=maxf(0,v.health-amount);v.damage_serial+=1
	v.shield_wait=FrontierSuitModules.shield_delay(member)
	v.hurt=float(config().heal_delay)*FrontierCrewAugmentation.multiplier(member,"recovery_delay")
	if v.health>0:return false
	v.health=config().rescue_health;v.protection=config().rescue_protection;v.rescue_serial+=1;v.sprinting=false
	v.shield=0.0;return true

# Consume ordinary attack energy on the shield, then pass only unused energy to health.
static func split_shield_damage(shield: float,damage_amount: float,multiplier: float=1.0) -> Dictionary:
	multiplier=maxf(1.0,multiplier)
	var absorbed:=minf(maxf(0,shield),maxf(0,damage_amount)*multiplier)
	return {"absorbed":absorbed,"health":maxf(0,damage_amount-absorbed/multiplier)}

static func weather_damage(member: Dictionary,amount: float,acid: bool) -> bool:
	var v:=ensure(member)
	if amount<=0 or v.protection>0:return false
	# Exposure is chemical; electric discharges use shields without combat/weapon procs.
	if not acid:
		var absorbed:=minf(float(v.shield),amount);amount-=absorbed;v.shield-=absorbed
		if absorbed>0:
			v.shield_serial+=1
			if v.shield<=0:v.shield_break_serial+=1
		v.shield_wait=FrontierSuitModules.shield_delay(member)
	if amount>0:v.health=maxf(0,v.health-amount);v.damage_serial+=1
	v.hurt=float(config().heal_delay)
	if v.health>0:return false
	v.health=config().rescue_health;v.protection=config().rescue_protection;v.rescue_serial+=1;v.sprinting=false;v.shield=0.0
	return true

static func heal(member: Dictionary,amount: float) -> void:
	var v:=ensure(member);var maximum:=FrontierCrewAugmentation.maximum_health(member)
	var overflow:=maxf(0,v.health+amount-maximum);v.health=minf(maximum,v.health+maxf(0,amount))
	if overflow>0 and FrontierSuitModules.has_effect(member,"overflow_relay"):
		v.shield=minf(FrontierSuitModules.shield_max(member),v.shield+overflow*float(FrontierSuitModules.config().legendary.overflow_relay.factor))
