class_name FrontierRoverWorkshop
extends VBoxContainer
var app: FrontierCrewExpedition
var factory:=false
var progress: ProgressBar
var state_label: Label
var cost: FrontierResourceReadout
var action: Button
func configure(owner_app: FrontierCrewExpedition,is_factory: bool=false) -> void:
	app=owner_app;factory=is_factory;name="로버 제작" if factory else "운송 장비 개조"
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(row)
	var preview:=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(245,180);preview.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(preview);preview.show_model("vehicles/scout_rover")
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(column)
	FrontierInterfaceStyle.label(column,"SCOUT · 2인승 탐사 로버",22)
	var info:=FrontierInterfaceStyle.label(column,"두 사람이 함께 이동하고, 화물 4칸에 탐험 물자를 싣습니다.\n별도 연구 없이 제작소에서 조립합니다.",15);info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cost=FrontierResourceReadout.new();column.add_child(cost)
	state_label=FrontierInterfaceStyle.label(column,"",14);state_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	progress=ProgressBar.new();progress.custom_minimum_size.y=18;add_child(progress)
	action=Button.new();action.custom_minimum_size.y=44;add_child(action);action.pressed.connect(func():app.session.send_request("rover_craft" if factory else ("rover_research2" if FrontierRovers.research(app.session.latest.crew.members[app.session.latest.self_id])==1 else "rover_research"),{"factory_id":app.business_panel.context_id} if factory else {}))
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or app.session.latest.is_empty():return
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	var level:=FrontierRovers.research(member)
	var ledger: Dictionary=app.session.surface.get("business",{})
	var ownbag: Dictionary=app.session.latest.get("inventory",{})
	var reason:="";progress.hide()
	if factory:
		var site: Dictionary=ledger.get("sites",{}).get(app.session.latest.location,{})
		var building: Dictionary=site.get("buildings",{}).get(app.business_panel.context_id,{})
		if level<1:reason="착륙선 연구실에서 현장 물류 I을 연구하세요"
		elif not building.get("active",false):reason="제작소의 전력·가동 상태를 확인하세요"
		elif not FrontierExpeditionBusiness.affordable(site.get("inventory",{}),FrontierRovers.config().cost):reason="공동 창고의 부품이 부족합니다"
		for job in app.rovers.fleet().jobs.values():
			if job.factory_id==app.business_panel.context_id and job.body_id==app.session.latest.location:
				progress.show();progress.max_value=FrontierRovers.config().craft_seconds;progress.value=job.progress;reason="조립 중 · %.0f / %.0f초"%[job.progress,progress.max_value]
				if progress.value>=progress.max_value:reason="조립 완료 · 제작소 주변 출고 공간을 비워 주세요"
		cost.value="공동 창고 · "+FrontierCatalog.cost_text(FrontierRovers.config().cost)
	else:
		if level>=2:reason="운송 개조 완료 · 적재/하역 8초 → 5초"
		elif FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):reason="착륙선 연구실에 접근하세요"
		elif not FrontierEarlyAccess.available(ledger,"robotics"):reason="기초 로봇공학이 필요합니다"
		elif not FrontierExpeditionBusiness.affordable(ownbag,FrontierRovers.config().transport.research_cost if level==1 else FrontierRovers.config().research_cost):reason="가방의 개조 부품가 부족합니다"
		cost.value="내 가방 · "+FrontierCatalog.cost_text(FrontierRovers.config().transport.research_cost if level==1 else FrontierRovers.config().research_cost)
	action.disabled=not reason.is_empty();action.text="로버 조립 · 45초" if factory else ("운송 개조 · 적재/하역 8초 → 5초" if level==1 else ("운송 개조 완료" if level>=2 else "현장 물류 I 연구"));state_label.text=reason
