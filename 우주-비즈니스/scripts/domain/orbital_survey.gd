class_name FrontierOrbitalSurvey
extends RefCounted
## Initial remote measurements, not a promise of yield or a current site appraisal.
static func report(body: Dictionary) -> Dictionary:
	var result: Dictionary={"available":false,"resources":[],"water":0.0,"air":0.0,"risk":"미확인","difficulty":"미확인","detail":""}
	if not FrontierUniverse.landable(body):
		result.detail=FrontierUniverse.landing_restriction(body);result.risk="착륙 불가";result.difficulty="개발 불가";return result
	var t: Dictionary=body.get("traits",{})
	if t.is_empty():result.detail="현장 조사가 필요합니다.";return result
	result.available=true;result.water=float(t.water)
	var env:=t.duplicate();env.ecology=0;env.stable_seconds=0
	var scores:=FrontierEvaluator.scores(env);result.air=scores.atmosphere
	var hazards: PackedStringArray=[]
	if float(t.temperature)>80:hazards.append("고열")
	elif float(t.temperature)<-40:hazards.append("극저온")
	if float(t.toxicity)>25:hazards.append("독성")
	if float(t.pressure)<.4:hazards.append("희박 대기")
	elif float(t.pressure)>2:hazards.append("고압")
	result.risk="주의" if hazards.is_empty() else " · ".join(hazards)
	var burden: float=100.0-(float(scores.atmosphere)+float(scores.temperature)+float(scores.water))/3.0
	result.difficulty="낮음" if burden<35 else ("보통" if burden<65 else "높음")
	if t.id=="volcanic":result.difficulty="극한 · 냉각 선행"
	var p: Dictionary=body.get("mineral_profile",{})
	for id in p.get("primary",[]):
		if id not in result.resources:result.resources.append(id)
	for id in p.get("secondary",[]):
		if id not in result.resources:result.resources.append(id)
	var materials: PackedStringArray=[]
	for id in result.resources:materials.append(FrontierMinerals.entry(id).get("name",id))
	var gems: PackedStringArray=[]
	for id in p.get("gems",[]):gems.append(FrontierMinerals.entry(id).get("name",id))
	result.detail="초기 원격 관측 · 현장 개발 변화 별도\n%s\n수자원 %.0f%% · 대기 적합도 %.0f/100\n기온 %.0f°C · 기압 %.2f atm · 산소 %.1f%%\n위험: %s\n환경 개선 부담: %s\n주요/부수 광물: %s\n지하 보석 후보: %s"%[t.name,result.water,result.air,t.temperature,t.pressure,float(t.oxygen)*100,result.risk,result.difficulty," / ".join(materials)," / ".join(gems)]
	if not str(p.get("exotic","")).is_empty():result.detail+="\n특이 반응: "+FrontierMinerals.entry(p.exotic).name
	result.detail+="\n매장량·채굴 위치는 현장 탐사로 확인"
	return result
