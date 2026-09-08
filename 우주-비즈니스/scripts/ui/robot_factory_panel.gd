extends VBoxContainer
## Manufacturing belongs to the factory the player actually opened.
var owner_panel: FrontierBusinessPanel
var craft: Button
var cost: FrontierResourceReadout
var state_label: Label
var progress: ProgressBar
func configure(panel: FrontierBusinessPanel) -> void:
	owner_panel=panel;name="로봇 제작"
	var row:=HBoxContainer.new();add_child(row)
	var preview:=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(190,190);row.add_child(preview);preview.show_model("miner")
	var detail:=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(detail)
	panel.label(detail,"M-01 채광 로봇",24)
	panel.label(detail,"채광 → 운반 → 하역 → 충전",16)
	cost=FrontierResourceReadout.new();detail.add_child(cost)
	state_label=panel.label(detail,"")
	progress=ProgressBar.new();progress.custom_minimum_size.y=24;add_child(progress)
	craft=panel.button(self,"로봇 제작 시작",func():panel.command.emit("business_craft",{"building_id":panel.context_id}))
	panel.label(self,"완성 후 제작소 옆으로 출고됩니다. 로봇을 보고 F를 눌러 작업을 배정하세요.")
func refresh(site: Dictionary) -> void:
	var b: Dictionary=site.get("buildings",{}).get(owner_panel.context_id,{})
	var def:=FrontierCatalog.entry("robots","miner")
	cost.value="필요 재료 · "+FrontierCatalog.cost_text(def.cost)
	var reason: String=""
	var job: Dictionary={}
	for row in site.get("jobs",{}).values():
		if row.factory_id==owner_panel.context_id:job=row;break
	progress.visible=not job.is_empty()
	if not job.is_empty():progress.value=100*float(job.progress)/float(job.seconds)
	if b.get("type","")!="factory":reason="로봇 제작소가 필요합니다."
	elif not FrontierPlanetSupply.operating(site):reason="인계된 제작소입니다."
	elif not job.is_empty():reason="로봇 조립 중 · "+str(b.get("status",""))
	elif not b.get("production",{}).is_empty():reason="제품 생산 중"
	elif not b.get("active",false):reason="전력·가동 상태를 확인하세요."
	elif "robotics" not in owner_panel.ledger.get("technologies",[]):reason="착륙선 단말에서 로봇공학을 구매하세요."
	elif not FrontierExpeditionBusiness.affordable(site.get("inventory",{}),def.cost):reason="공동 창고에 제작 재료가 부족합니다."
	for project in owner_panel.engineering.get("projects",{}).values():
		if project.get("facility_id","")==owner_panel.context_id and project.get("stage","") in ["prototype","trial"]:reason="공학 작업 진행 중"
	craft.disabled=not reason.is_empty()
	state_label.text=reason if not reason.is_empty() else "제작 준비 · %.0f초"%(float(def.seconds)/FrontierProductionTier2.factor(b))
