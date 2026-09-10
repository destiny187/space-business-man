class_name FrontierMineMaintenance
extends RefCounted
const PREFIX := "service-v1:"
const STATES := ["작업장 고장 신호","교체 부품 수령 대기","교체 부품 운반 중","부품 설치 · 정비 대기","작업 재개"]
static func address(system: int) -> String:return PREFIX+str(system)
static func rules(m: Dictionary) -> Dictionary:return m.settings.get("corporate_space",{}).get("maintenance",{})
static func valid_rules(v: Variant) -> bool:
	if not v is Dictionary or v.get("version")!=1:return false
	for e in [["diagnose_distance",350,900],["diagnose_seconds",2,8],["repair_distance",200,450],["repair_seconds",4,15],["payment",1,10000]]:
		if not FrontierUniverse._finite(v.get(e[0]),e[1],e[2]):return false
	return FrontierExpeditionBusiness.integer(v.payment,1,10000)
static func definition(m: Dictionary,system: int,t: float=0) -> Dictionary:
	if rules(m).is_empty() or system<=0:return {}
	var profile:=FrontierCorporateSites.profile(m,system)
	if profile.theme!="industry" or profile.sites.size()!=2:return {}
	var site:=FrontierCorporateSites.definition(m,FrontierCorporateSites.address(system,0),t)
	var supplier:=FrontierCorporateSites.definition(m,FrontierCorporateSites.address(system,1),t)
	var receiver:=FrontierCrewWorld.vector(site.position)+Vector3(1500,500,1050)
	var supply:=FrontierCrewWorld.vector(supplier.position)+Vector3(-1000,450,1050)
	return {"id":address(system),"type":"maintenance","system":system,"body":int(site.body),"body_id":FrontierUniverse.body_id(m,int(site.body)),"source_body":int(supplier.body),"company":"mine","name":"mine 작업장 정비","model":"ships/mine_service_pack","receiver_model":"mine_repair_worksite","cargo":"드릴 구동 카트리지","destination":site.id,"port_name":"mine 외부 정비대","source_name":supplier.name+" · 부품 거치대","call_sign":"MINE SERVICE-%d"%system,"receiver":FrontierExpeditionBusiness.array(receiver),"position":FrontierExpeditionBusiness.array(supply),"payment":int(rules(m).payment),"seed":FrontierUniverse.derive(int(m.seed),address(system))}
