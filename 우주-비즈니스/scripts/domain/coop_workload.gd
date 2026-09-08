class_name FrontierCoopWorkload
extends RefCounted
## A larger treated volume, fixed at successful activation. No personal speed penalty.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/coop_workload.json"))
	return _config
static func coefficient(tier: int,count: int) -> float:
	return 1.0+float(config().intro_increment if tier<=1 else config().advanced_increment)*(clampi(count,1,int(config().maximum_participants))-1)
static func base_reward(tier: int) -> int:
	var cfg:=FrontierExpeditionBusiness.config()
	return int(cfg.contract_base_reward)+tier*int(cfg.contract_tier_reward)
static func reward(site: Dictionary,tier: int) -> int:
	return int(site.get("coop_workload",{}).get("reward",base_reward(tier)))
static func description(site: Dictionary,tier: int,count: int) -> String:
	if site.has("coop_workload"):
		var row: Dictionary=site.coop_workload
		return "참여 %d명 확정 · 처리 대상 ×%.2f · 계약 %d Cr"%[int(row.participant_count),float(row.coefficient),int(row.reward)]
	if site.get("workload_eligible",false) or (site.is_empty() and tier in [1,2]):
		var factor:=coefficient(tier,count)
		return "시작 예상 %d명 · 처리 대상 ×%.2f · 계약 %d Cr\n첫 시설 운영·등록 성공 시 확정"%[count,factor,roundi(base_reward(tier)*factor)]
	return "기존 계약 규모 유지 · 계약 %d Cr"%base_reward(tier)
static func activate(site: Dictionary,body: Dictionary,count: int) -> void:
	if not site.get("workload_eligible",false) or site.has("coop_workload"):return
	var e: Dictionary=site.environment
	var cfg:=FrontierExpeditionBusiness.config();var margin:=100.0-float(cfg.contract_environment_minimum)
	var targets: Dictionary={"oxygen":clampf(float(e.oxygen),.21-margin/500.0,.21+margin/500.0),"pressure":clampf(float(e.pressure),1-margin/110.0,1+margin/110.0),"toxicity":minf(float(e.toxicity),margin),"temperature":clampf(float(e.temperature),18-margin/1.7,18+margin/1.7),"water":maxf(float(e.water),float(cfg.contract_environment_minimum)/1.5),"ecology":maxf(float(e.ecology),float(cfg.contract_ecology_minimum))}
	var initial: Dictionary={}
	for key in targets:initial[key]=float(e[key])
	if site.has("restoration2"):
		var r: Dictionary=site.restoration2;var rc: Dictionary=FrontierProductionTier2.config().restoration
		initial.salinity=float(r.salinity);initial.soil=float(r.soil)
		targets.salinity=minf(float(r.salinity),float(rc.salinity_target));targets.soil=maxf(float(r.soil),float(rc.soil_target))
	var factor:=coefficient(int(body.planet_tier),count)
	var base: Dictionary={};var target: Dictionary={};var processed: Dictionary={}
	for key in initial:base[key]=absf(float(targets[key])-float(initial[key]));target[key]=float(base[key])*factor;processed[key]=0.0
	site.coop_workload={"version":1,"participant_count":clampi(count,1,6),"coefficient":factor,"base_workload":base,"target_workload":target,"processed":processed,"initial":initial,"thresholds":targets,"reward":roundi(base_reward(int(body.planet_tier))*factor)}
	site.erase("workload_eligible")
static func distribute(site: Dictionary,before: Dictionary,restoration_before: Dictionary) -> void:
	if not site.has("coop_workload"):return
	var record: Dictionary=site.coop_workload;var factor:=float(record.coefficient)
	for key in before:
		if key=="stable_seconds":continue
		# An unchanged machine treats its normal quantity; the region contains factor volumes.
		site.environment[key]=float(before[key])+(float(site.environment[key])-float(before[key]))/factor
	for key in ["salinity","soil"]:
		if restoration_before.has(key):site.restoration2[key]=float(restoration_before[key])+(float(site.restoration2[key])-float(restoration_before[key]))/factor
	for key in record.initial:
		var value: float=site.restoration2[key] if key in ["salinity","soil"] else site.environment[key]
		record.processed[key]=minf(float(record.target_workload[key]),absf(value-float(record.initial[key]))*factor)
static func valid(site: Dictionary,tier: int) -> bool:
	if site.has("workload_eligible") and not site.workload_eligible is bool:return false
	if not site.has("coop_workload"):return true
	if tier not in [1,2] or site.has("workload_eligible") or site.get("state")=="exploration":return false
	var value: Variant=site.coop_workload
	if not value is Dictionary or value.get("version")!=1 or not FrontierExpeditionBusiness.integer(value.get("participant_count"),1,6):return false
	if not FrontierUniverse._finite(value.get("coefficient"),1,2.5) or not is_equal_approx(float(value.coefficient),coefficient(tier,int(value.participant_count))):return false
	if not FrontierExpeditionBusiness.integer(value.get("reward"),0,100000000) or int(value.reward)!=roundi(base_reward(tier)*float(value.coefficient)):return false
	if site.get("state")=="settled" and site.get("settlement",{}).get("payment")!=FrontierPlanetSupply.settlement_payment(site,tier,site.get("settlement",{}).get("retained",false)):return false
	for key in ["base_workload","target_workload","processed","initial","thresholds"]:
		if not value.get(key) is Dictionary:return false
	var keys: Array=["oxygen","pressure","toxicity","temperature","water","ecology"]
	if site.has("restoration2"):keys.append_array(["salinity","soil"])
	for table in ["base_workload","target_workload","processed","initial","thresholds"]:
		if value[table].size()!=keys.size():return false
	for key in keys:
		if not FrontierUniverse._finite(value.initial.get(key),-273,1000) or not FrontierUniverse._finite(value.thresholds.get(key),-273,1000):return false
		var base:=absf(float(value.initial[key])-float(value.thresholds[key]))
		if not FrontierUniverse._finite(value.base_workload.get(key),0,2000) or not is_equal_approx(value.base_workload[key],base):return false
		if not FrontierUniverse._finite(value.target_workload.get(key),0,5000) or not is_equal_approx(value.target_workload[key],base*float(value.coefficient)):return false
		if not FrontierUniverse._finite(value.processed.get(key),0,float(value.target_workload[key])+.00001):return false
	return true
