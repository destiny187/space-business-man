class_name FrontierOnboarding
extends RefCounted

const STEPS := ["contract","move","mine","deposit","robotics","solar","charger","factory","robot","delivery","atmosphere","climate","ecology","discovery","sale"]
const TITLES := ["당신의 첫 번째 행성","원격 장비에 익숙해지기","광물을 끌어당기세요","자원을 기지로 운반하세요","첫 자동화를 위한 설계도","전력부터 준비하세요","로봇이 돌아올 자리","당신의 첫 번째 공장","첫 동료를 제작하세요","이제 로봇에게 맡기세요","숨 쉴 수 있는 대기로","물과 온도를 맞추세요","황무지에 생명을","지도 밖의 이야기를 찾으세요","첫 번째 사업을 완성하세요"]
const DESCRIPTIONS := ["입문용 모래빛 위성으로 시작합니다.","WASD로 5m 이동하고 마우스로 둘러보세요.","가까운 광맥에 조준하고 좌클릭을 유지하세요.","기지의 화물 단말기 근처에서 E를 누르세요.","T · 기술 상점에서 입문 로봇공학을 구매하세요.","B · 건설에서 태양광 발전기를 배치하세요.","B · 건설에서 로봇 충전 패드를 배치하세요.","B · 건설에서 자율장비 제작기를 배치하세요.","R · 자율장비에서 M-01 채광로봇을 주문하세요.","현장으로 돌아와 첫 자동 운반을 지켜보세요.","대기 공학을 연구하고 대기 처리기를 가동하세요.","열 제어·수자원을 연구해 온도와 물을 개선하세요.","생태 정착을 연구하고 생태 배양기를 가동하세요.","보라색 이상 신호로 이동해 E로 조사하세요.","P · 평가에서 회수 편성과 행성 판매를 검토하세요."]

static func fresh() -> Dictionary:
	return {"enabled":true,"completed":[],"travel":0.0,"mined":0,"deposited":0,"delivered":0}

static func record(state: Dictionary,key: String,amount: float) -> void:
	if not state.profile.has("onboarding"): return
	var guide: Dictionary = state.profile.onboarding
	if key == "travel": guide.travel = minf(100,float(guide.travel)+maxf(0,amount))
	elif key in ["mined","deposited","delivered"]: guide[key] = mini(100000,int(guide[key])+maxi(0,int(amount)))

static func sync(state: Dictionary) -> void:
	if not state.profile.has("onboarding"): return
	var g: Dictionary = state.profile.onboarding
	var p: Dictionary = state.planet
	var built: Dictionary = {}
	for b in p.get("buildings",[]): built[b.type] = true
	var e: Dictionary = p.get("environment",{})
	var discovered: bool = not state.profile.codex.is_empty()
	for event in p.get("events",[]): discovered = discovered or event.discovered
	var conditions: Array = [not p.is_empty(),g.travel >= 5,g.mined >= 32,g.deposited >= 32,"robotics" in state.profile.technologies,built.has("solar"),built.has("charger"),built.has("factory"),not p.get("robots",[]).is_empty(),g.delivered > 0,built.has("atmosphere") and float(e.get("oxygen",0)) >= 0.06,built.has("thermal") and built.has("water") and float(e.get("water",0)) >= 20,built.has("biolab") and float(e.get("ecology",0)) >= 10,discovered,int(state.profile.round) > 0]
	for i in range(STEPS.size()):
		if conditions[i] and STEPS[i] not in g.completed: g.completed.append(STEPS[i])
	if state.profile.round > 0:
		for id in STEPS:
			if id not in g.completed: g.completed.append(id)

static func current(state: Dictionary) -> Dictionary:
	var g: Dictionary = state.profile.get("onboarding",{})
	if g.is_empty() or not g.get("enabled",false): return {}
	var index: int = 0
	while index < STEPS.size() and STEPS[index] in g.completed: index += 1
	if index == STEPS.size(): return {}
	var id: String = STEPS[index]
	var info: Dictionary = {"id":id,"index":index,"total":STEPS.size(),"title":TITLES[index],"detail":DESCRIPTIONS[index],"progress":0.0,"counter":"","position":Vector2.INF,"target_label":"","menu":"help"}
	var p: Dictionary = state.planet
	if p.is_empty(): info.menu = "earth"; return info
	var want: Dictionary = {}
	match id:
		"move": info.progress = minf(1,g.travel/5.0); info.counter = "%.0f / 5 m" % minf(5,g.travel)
		"mine": info.progress = minf(1,g.mined/32.0); info.counter = "%d / 32 채집" % mini(32,g.mined); want = {"iron":32}
		"deposit": info.progress = minf(1,g.deposited/32.0); info.counter = "%d / 32 반납" % mini(32,g.deposited); info.position = Vector2.ZERO; info.target_label = "착륙 기지"
		"robotics": info.menu = "technology"; info.counter = "연구비 %d Cr" % FrontierCatalog.entry("technologies","robotics").price
		"solar","charger","factory":
			info.menu = "build"
			want = FrontierCatalog.entry("buildings",id).cost
		"robot":
			info.menu = "robots"
			want = FrontierCatalog.entry("robots","miner").cost
			if not p.jobs.is_empty():
				info.progress = float(p.jobs[0].progress)/float(p.jobs[0].seconds)
				info.counter = "제작 중 · %.0f초 남음" % (float(p.jobs[0].seconds)-float(p.jobs[0].progress))
				info.detail = "메뉴를 닫으면 제작이 진행됩니다."
				want = {}
		"delivery": info.menu = "robots"; info.counter = "자동 채광 → 운반 → 하역"
		"atmosphere": info.menu = "technology"; info.counter = "산소 %.1f / 6.0%%" % (float(p.environment.oxygen)*100); info.progress = minf(1,float(p.environment.oxygen)/0.06)
		"climate": info.menu = "technology"; info.counter = "수자원 %.0f / 20%%" % float(p.environment.water); info.progress = minf(1,float(p.environment.water)/20)
		"ecology": info.menu = "technology"; info.counter = "생태 %.0f / 10%%" % float(p.environment.ecology); info.progress = minf(1,float(p.environment.ecology)/10)
		"discovery":
			info.menu = "journal"
			var closest: float = INF
			for event in p.events:
				var distance: float = FrontierCampaign.point(event.position).distance_to(FrontierCampaign.point(p.player.position))
				if not event.discovered and distance < closest: closest = distance; info.position = FrontierCampaign.point(event.position); info.target_label = "미확인 이상 신호"
		"sale": info.menu = "planet"; info.counter = "회수 기술과 우주선으로 로봇 계승 가능"
	if not want.is_empty():
		var needed: PackedStringArray = []
		var missing: String = ""
		var total: int = 0
		var ready: int = 0
		for key in want:
			var count: int = int(p.inventory.get(key,0))
			needed.append("%s %d/%d" % [FrontierCatalog.entry("resources",key).name,mini(count,want[key]),want[key]])
			total += int(want[key]); ready += mini(count,want[key])
			if missing.is_empty() and count < int(want[key]): missing = key
		if id != "mine": info.counter = " · ".join(needed); info.progress = float(ready)/maxi(1,total)
		if not missing.is_empty():
			if (id != "mine" and int(p.player.cargo.get(missing,0))+int(p.inventory.get(missing,0)) >= int(want[missing])) or FrontierCatalog.total(p.player.cargo) >= 140:
				info.position = Vector2.ZERO; info.target_label = "착륙 기지 · 화물 반납"
			else:
				var distance: float = INF
				for ore in p.nodes:
					var d: float = FrontierCampaign.point(ore.position).distance_to(FrontierCampaign.point(p.player.position))
					if ore.resource == missing and ore.amount > 0 and d < distance: distance = d; info.position = FrontierCampaign.point(ore.position); info.target_label = FrontierCatalog.entry("resources",missing).name+" 광맥"
	return info
