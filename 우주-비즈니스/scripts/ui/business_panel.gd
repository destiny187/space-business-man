class_name FrontierBusinessPanel
extends PanelContainer
signal command(kind: String,args: Dictionary)
signal place_building(kind: String)
signal station_action(kind: String)
var context_kind: String="build"
var context_id: String=""
var tabs: TabContainer
var heading: Label
var deposit_button: Button
var robot_factory
var warehouse: VBoxContainer
var supply_controls: VBoxContainer
var robot_controls: VBoxContainer
var recovery_controls: VBoxContainer
var warehouse_stock: OptionButton
var robot_job_status: Label
var warehouse_grid: GridContainer
var warehouse_key: String=""
var facility_picture: FrontierEquipmentPreview
var facility_status: Label
var production_panel: FrontierProductionPanel
var building_cards: Dictionary={}
var summary: FrontierResourceReadout
var stock: FrontierResourceReadout
var environment_bars: Dictionary={}
var environment_label: Label
var guidance: Label
var technology: OptionButton
var building: OptionButton
var building_cost: FrontierResourceReadout
var facility: OptionButton
var factory: OptionButton
var robot: OptionButton
var vein: OptionButton
var hangar: OptionButton
var supply: OptionButton
var ledger: Dictionary={}
var body_id: String=""
var actor_id: String=""
var planet_tier: int=1
var register_button: Button
var engineering: Dictionary={}
var knowledge: Dictionary={}
var research_project: OptionButton
var research_facility: OptionButton
var research_detail: Label
var research_prototype_button: Button
var research_trial_button: Button
var research_install_button: Button
var research_cancel_button: Button
func _ready() -> void:
	theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);offset_left=24;offset_right=minf(900,get_viewport().get_visible_rect().size.x-24);offset_top=26;offset_bottom=-24
	get_viewport().size_changed.connect(func():offset_right=minf(900,get_viewport().get_visible_rect().size.x-24))
	var style:=FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,20);add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",9);scroll.add_child(column)
	heading=label(column,"건설 · B 닫기",24)
	summary=FrontierResourceReadout.new();column.add_child(summary);guidance=label(column,"");stock=FrontierResourceReadout.new();column.add_child(stock)
	register_button=button(column,"무료 개발 등록",func():command.emit("business_register",{}))
	deposit_button=button(column,"현장 창고에 자원 반납",func():station_action.emit("storage"))
	tabs=TabContainer.new();tabs.custom_minimum_size.y=290;column.add_child(tabs)
	robot_factory=load("res://scripts/ui/robot_factory_panel.gd").new();tabs.add_child(robot_factory);robot_factory.configure(self)
	production_panel=FrontierProductionPanel.new();tabs.add_child(production_panel);production_panel.configure(self)
	var build_tab:=VBoxContainer.new();build_tab.name="건설";tabs.add_child(build_tab)
	building=option(build_tab)
	for key in FrontierExpeditionBusiness.config().buildings:
		var def:=FrontierCatalog.entry("buildings",key);building.add_item(def.name);building.set_item_metadata(building.item_count-1,key)
	building.hide()
	var grid:=GridContainer.new();grid.columns=4;build_tab.add_child(grid)
	for index in building.item_count:
		var kind:=str(building.get_item_metadata(index))
		var def:=FrontierCatalog.entry("buildings",kind)
		var card:=Button.new();card.custom_minimum_size=Vector2(145,90);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.toggle_mode=true
		card.tooltip_text=def.name+" · "+FrontierCatalog.cost_text(def.cost)
		var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_top=4;content.offset_bottom=-4
		var preview:=TextureRect.new();preview.texture=load("res://assets/ui/previews/"+def.model+".png");preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.custom_minimum_size.y=62;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(preview)
		var title:=Label.new();title.text=def.name;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",14);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(title)
		card.pressed.connect(func():building.select(index);refresh_building_cost());grid.add_child(card);building_cards[kind]=card
	building_cost=FrontierResourceReadout.new();building_cost.custom_minimum_size.x=0;build_tab.add_child(building_cost)
	building.item_selected.connect(func(_index: int):refresh_building_cost())
	refresh_building_cost()
	button(build_tab,"선택 시설 배치 · 지면 조준 후 클릭",func():place_building.emit(selected(building)))
	var facility_tab:=VBoxContainer.new();facility_tab.name="시설 관리"
	facility_picture=FrontierEquipmentPreview.new();facility_picture.custom_minimum_size=Vector2(150,150);facility_picture.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;facility_tab.add_child(facility_picture)
	facility_status=label(facility_tab,"")
	facility=option(facility_tab)
	button(facility_tab,"선택 시설 가동 / 정지",func():command.emit("business_toggle",{"building_id":selected(facility)}))
	button(facility_tab,"선택 시설 철거 · 건설 재료 반환",func():command.emit("business_demolish",{"building_id":selected(facility)}))
	label(build_tab,"카드 선택 → 배치 → 지면 클릭 · Esc 취소")
	var research_tab:=VBoxContainer.new();research_tab.name="기술";tabs.add_child(research_tab)
	technology=option(research_tab)
	button(research_tab,"선택 기술 구매",func():command.emit("business_technology",{"technology":selected(technology)}))
	warehouse=VBoxContainer.new();warehouse.name="창고";tabs.add_child(warehouse)
	warehouse_stock=option(warehouse)
	warehouse_stock.hide()
	warehouse_grid=GridContainer.new();warehouse_grid.columns=5;warehouse.add_child(warehouse_grid)
	button(warehouse,"선택 자원 1개 인수",func():command.emit("business_withdraw",{"resource":selected(warehouse_stock),"amount":1}))
	button(warehouse,"선택 자원 20개 인수",func():command.emit("business_withdraw",{"resource":selected(warehouse_stock),"amount":20}))
	supply_controls=VBoxContainer.new();warehouse.add_child(supply_controls)
	supply=option(supply_controls)
	for key in FrontierExpeditionBusiness.config().store_unit_price:
		supply.add_icon_item(FrontierResourceIcons.menu_texture(key),"%s 20개 · %d Cr"%[FrontierCatalog.entry("resources",key).name,int(FrontierExpeditionBusiness.config().store_unit_price[key])*20]);supply.set_item_metadata(supply.item_count-1,key)
	button(supply_controls,"보급 20개 인수",func():command.emit("business_supply",{"resource":selected(supply)}))
	label(research_tab,"공동 자금은 호스트가 지출합니다. 기술은 영구 유지하며 실제 장비는 재료로 제작합니다. 생태 배양기는 허가된 표준 균주를 사용하는 지역 복원 설비입니다.")
	var robot_tab:=VBoxContainer.new();robot_tab.name="로봇";tabs.add_child(robot_tab)
	var robot_preview:=FrontierEquipmentPreview.new();robot_preview.custom_minimum_size=Vector2(140,140);robot_preview.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;robot_tab.add_child(robot_preview);robot_preview.show_model("miner")
	factory=option(robot_tab);factory.hide()
	robot=option(robot_tab)
	robot_job_status=label(robot_tab,"")
	robot_controls=VBoxContainer.new();robot_tab.add_child(robot_controls)
	vein=option(robot_controls)
	button(robot_controls,"광맥 배정",func():command.emit("business_assign",{"robot_id":selected(robot),"vein_id":selected(vein)}))
	button(robot_controls,"작업 중지 · 창고로 복귀",func():command.emit("business_robot_return",{"robot_id":selected(robot)}))
	button(robot_controls,"긴급 충전 · 50 Cr",func():command.emit("business_robot_rescue",{"robot_id":selected(robot)}))
	recovery_controls=VBoxContainer.new();robot_tab.add_child(recovery_controls)
	button(recovery_controls,"창고 근처 로봇을 격납고로 회수",func():command.emit("business_robot_recover",{"robot_id":selected(robot)}))
	hangar=option(recovery_controls)
	button(recovery_controls,"운송한 로봇 재파견",func():command.emit("business_robot_deploy",{"robot_id":selected(hangar)}))
	var engineering_tab:=VBoxContainer.new();engineering_tab.name="생물공학";tabs.add_child(engineering_tab)
	research_project=option(engineering_tab)
	for key in FrontierFieldEngineering.config().projects:
		research_project.add_icon_item(FrontierResourceIcons.menu_texture(key),FrontierFieldEngineering.definition(key).name);research_project.set_item_metadata(research_project.item_count-1,key)
	research_project.item_selected.connect(func(_index: int):update_engineering())
	research_detail=label(engineering_tab,"")
	research_facility=option(engineering_tab)
	research_facility.item_selected.connect(func(_index: int):update_engineering())
	research_prototype_button=button(engineering_tab,"시제품 제작 · "+FrontierCatalog.cost_text(FrontierFieldEngineering.config().prototype_cost),func():engineering_command("prototype"))
	research_trial_button=button(engineering_tab,"현장 시험 · "+FrontierCatalog.cost_text(FrontierFieldEngineering.config().trial_cost),func():engineering_command("trial"))
	research_install_button=button(engineering_tab,"설비 개조 · "+FrontierCatalog.cost_text(FrontierFieldEngineering.config().install_cost),func():engineering_command("install"))
	research_cancel_button=button(engineering_tab,"실험 중지 · 투입 재료는 반환되지 않음",func():engineering_command("cancel"))
	label(engineering_tab,"현장에서 생물 스캔 → 기초 분석 → 제작소 시제품 → 대상 설비의 현장 시험 → 개조. 각 작업은 설비 8m 안에서 시작합니다. 전력·가동·소모재·배양 조건이 끊기면 실험도 대기합니다.")
	var contract_tab:=VBoxContainer.new();contract_tab.name="환경·계약";tabs.add_child(contract_tab)
	for category in ["atmosphere","temperature","water","ecology"]:
		var row:=HBoxContainer.new();contract_tab.add_child(row)
		var title:=label(row,{"atmosphere":"대기","temperature":"온도","water":"물","ecology":"생태"}[category]);title.custom_minimum_size.x=50;title.size_flags_horizontal=0
		var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(200,22);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(bar);environment_bars[category]=bar
	environment_label=label(contract_tab,"")
	button(contract_tab,"지역 복원 계약 정산…",confirm_settlement)
	label(contract_tab,"계약은 이 개발 구역의 복원 성과를 평가합니다. 정산하면 남긴 시설·현장 로봇·창고를 인계합니다. 필요한 로봇은 먼저 회수하세요. 행성 전체의 소유권 매각과 구분됩니다.")
	tabs.add_child(facility_tab)
	var ship_tab:=VBoxContainer.new();ship_tab.name="착륙선";tabs.add_child(ship_tab)
	button(ship_tab,"연구실 · 표본 분석과 시험",func():station_action.emit("research"))
	button(ship_tab,"우주선 창고 · 운송할 물건 싣기",func():station_action.emit("cargo"))
	button(ship_tab,"우주선 정비",func():station_action.emit("shipyard"))
	button(ship_tab,"출항 · 승무원 준비",func():station_action.emit("launch"))
	set_context("build")
	hide()
func label(parent: Node,text: String,size: int=15) -> Label:
	var item:=Label.new();item.text=text;item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;item.add_theme_font_size_override("font_size",size);parent.add_child(item);return item
func button(parent: Node,text: String,callback: Callable) -> Button:
	var item:=Button.new();item.text=text;item.custom_minimum_size.y=36;item.pressed.connect(callback);parent.add_child(item);FrontierResourceIcons.button_caption(item);return item
func option(parent: Node) -> OptionButton:
	var item:=OptionButton.new();item.add_theme_constant_override("icon_max_width",24);item.fit_to_longest_item=false;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(item);return item
func selected(item: OptionButton) -> String:return str(item.get_item_metadata(item.selected)) if item.selected>=0 else ""
func choices(item: OptionButton,values: Dictionary) -> void:
	if item.get_popup().visible:return
	var old:=selected(item);item.clear()
	for key in values:item.add_item(values[key]);item.set_item_metadata(item.item_count-1,key)
	for i in item.item_count:
		if str(item.get_item_metadata(i))==old:item.select(i)
func set_context(kind: String,id: String="") -> void:
	context_kind=kind;context_id=id
	var allowed: Array=[]
	match kind:
		"build":allowed=["건설"]
		"ship":allowed=["착륙선","기술","환경·계약"]
		"base","storage":allowed=["창고","로봇"]
		"factory":allowed=["로봇 제작","생산·개조","생물공학","시설 관리"]
		"robot":allowed=["로봇","생산·개조"]
		_:allowed=["시설 관리","생산·개조"]
	if kind in ["atmosphere","thermal","water","biolab"]:allowed.append("생물공학")
	if kind=="storage":allowed.append("시설 관리")
	for i in tabs.get_tab_count():tabs.set_tab_hidden(i,str(tabs.get_tab_control(i).name) not in allowed)
	for i in tabs.get_tab_count():
		if str(tabs.get_tab_control(i).name)==allowed[0]:tabs.current_tab=i;break
	var title: String={"build":"건설","ship":"착륙선 단말","base":"현장 창고","factory":"로봇 제작소","robot":"M-01 작업 관리"}.get(kind,FrontierCatalog.entry("buildings",kind).get("name","시설"))
	heading.text=title+" · Esc 닫기"
	register_button.visible=kind=="ship"
	deposit_button.visible=kind in ["base","storage"]
	robot_controls.visible=kind=="robot";recovery_controls.visible=kind in ["base","storage"]
	facility.hide();research_facility.hide();robot.visible=kind in ["base","storage"]
	research_prototype_button.visible=kind=="factory"
	research_trial_button.visible=kind!="factory";research_install_button.visible=kind!="factory"
	production_panel.produce.visible=kind=="factory"
	production_panel.targets.hide()
	var available: Dictionary={}
	for key in FrontierFieldEngineering.config().projects:
		var def:=FrontierFieldEngineering.definition(key)
		if kind=="factory" or def.building==kind:available[key]=def.name
	choices(research_project,available)
func refresh_context(current: Dictionary) -> void:
	register_button.visible=context_kind=="ship" and current.is_empty()
	guidance.visible=current.is_empty()
	if current.is_empty():guidance.text="착륙선에 접근해 F로 무료 개발 등록을 진행하세요."
	robot_factory.refresh(current)
	var cargo: Dictionary={}
	for key in current.get("inventory",{}):
		if int(current.inventory[key])>0:cargo[key]=FrontierCatalog.entry("resources",key).name+" ×"+str(int(current.inventory[key]))
	choices(warehouse_stock,cargo)
	var next_key:=str(cargo)
	if warehouse_key!=next_key:
		warehouse_key=next_key
		for child in warehouse_grid.get_children():warehouse_grid.remove_child(child);child.queue_free()
		for key in cargo:
			var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(key);tile.caption=FrontierCatalog.entry("resources",key).name;tile.amount=str(int(current.inventory[key]));tile.tooltip_text=cargo[key]
			tile.selected=key==selected(warehouse_stock)
			tile.pressed.connect(func():
				for i in warehouse_stock.item_count:
					if str(warehouse_stock.get_item_metadata(i))==key:warehouse_stock.select(i)
				for other in warehouse_grid.get_children():other.selected=other==tile;other.queue_redraw())
			warehouse_grid.add_child(tile)
	var target_robot: Dictionary=current.get("robots",{}).get(context_id,{})
	robot_job_status.text=str(target_robot.get("status",""))
	if context_kind not in ["build","ship","base"]:
		var row: Dictionary=current.get("robots" if context_kind=="robot" else "buildings",{}).get(context_id,{})
		if context_kind!="robot" and not row.is_empty():
			facility_picture.show_model(FrontierCatalog.entry("buildings",row.type).model)
			facility_status.text="Mk.%d · %s"%[int(row.get("tier",1)),row.get("status","")]
		if row.is_empty() or current.get("state","")!="active":hide()
func context_in_range(position: Vector3) -> bool:
	if context_kind=="build":return true
	if context_kind=="ship":return position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	var site: Dictionary=ledger.get("sites",{}).get(body_id,{})
	if site.is_empty():return false
	if context_kind=="base":return position.distance_to(FrontierCrewWorld.vector(site.center))<=float(FrontierExpeditionBusiness.config().deposit_range)
	var row: Dictionary=site.get("robots" if context_kind=="robot" else "buildings",{}).get(context_id,{})
	return not row.is_empty() and position.distance_to(FrontierCrewWorld.vector(row.position))<=float(FrontierExpeditionBusiness.config().interaction_range)
func update(value: Dictionary,id: String,actor: String,tier: int=1,research: Dictionary={},ecology: Dictionary={},planet: Dictionary={},viewer: Vector3=Vector3.ZERO) -> void:
	register_button.show();guidance.show()
	ledger=value;body_id=id;actor_id=actor;planet_tier=tier;engineering=research;knowledge=ecology
	refresh_context(value.get("sites",{}).get(id,{}))
	update_engineering()
	production_panel.update_site(value.get("sites",{}).get(id,{}))
	for bar in environment_bars.values():bar.value=0
	register_button.disabled=not value.is_empty() and (value.sites.has(id) or not value.get("active_elsewhere","").is_empty())
	stock.value="등록된 현장 창고가 없습니다.";environment_label.text="무료 개발 등록 후 환경을 조사합니다."
	for item in [facility,factory,robot,vein,technology,hangar]:
		if value.is_empty() or not value.sites.has(id):choices(item,{})
	if value.is_empty():summary.value="첫 원정 · 무료 개발 등록";register_button.visible=context_kind=="ship";stock.value="착륙선에서 F · 개발 등록";return
	summary.value="공동 자금 %s Cr · 격납고 %d/%d"%[str(int(value.credits)),value.hangar.size(),int(value.get("hangar_capacity",FrontierExpeditionBusiness.config().hangar_slots))]
	if not value.get("active_elsewhere","").is_empty():guidance.text="다른 행성에서 사업 진행 중 · 등록한 사업으로 돌아가 정산하세요."
	elif not value.sites.has(id):guidance.text="새 목적지입니다. 무료 개발 등록으로 사업을 시작하세요."
	var current: Dictionary=value.sites.get(id,{})
	register_button.visible=current.is_empty() and context_kind=="ship";guidance.visible=current.is_empty()
	production_panel.update_site(current)
	if current.is_empty():return
	stock.value="창고 · "+FrontierCatalog.cost_text(current.inventory)+"\n배낭 · "+FrontierCatalog.cost_text(value.bags.get(actor,FrontierExpeditionBusiness.inventory()))
	var factories: Dictionary={};var buildings: Dictionary={};var robots: Dictionary={};var veins: Dictionary={};var technologies: Dictionary={};var transported: Dictionary={}
	for key in current.buildings:
		if key!=context_id:continue
		var b: Dictionary=current.buildings[key];buildings[key]=FrontierCatalog.entry("buildings",b.type).name+" · "+str(b.status)
		if b.type=="factory":factories[key]=buildings[key]
	for key in current.robots:
		if context_kind=="robot" and key!=context_id:continue
		var r: Dictionary=current.robots[key];robots[key]=key+" · "+FrontierCatalog.entry("grades",r.grade).name+" · "+str(r.status)
	for key in value.hangar:transported[key]=key+" · "+FrontierCatalog.entry("grades",value.hangar[key].grade).name
	if not planet.is_empty():
		for row in FrontierExpeditionBusiness.veins(planet,viewer):
			if row.get("underground",false):continue
			veins[row.id]=FrontierCatalog.entry("resources",row.resource).name+" · "+row.id+" · "+str(int(current.remaining.get(row.id,row.capacity)))
	else:
		for i in FrontierExpeditionBusiness.config().veins.size():
			var key: String="vein:"+str(i);veins[key]=FrontierCatalog.entry("resources",FrontierExpeditionBusiness.config().veins[i]).name+" · "+key+" · "+str(int(current.remaining.get(key,0)))
	for key in FrontierExpeditionBusiness.config().technologies:
		var def:=FrontierCatalog.entry("technologies",key);technologies[key]=def.name+(" · 보유" if key in value.technologies else " · %d Cr"%int(def.price))
	choices(facility,buildings);choices(factory,factories);choices(robot,robots);choices(vein,veins);choices(technology,technologies);choices(hangar,transported)
	var e: Dictionary=current.environment;var scores:=FrontierEvaluator.scores(e)
	for category in environment_bars:environment_bars[category].value=float(e.ecology) if category=="ecology" else float(scores[category])
	environment_label.text="지역 전력 %.0f / %.0f kW\n온도 %.1f°C · 기압 %.2f bar · 산소 %.1f%%\n대기 %.0f · 온도 %.0f · 물 %.0f · 생태 %.0f\n안정화 %.0f / 30초"%[float(current.power_demand),float(current.power_supply),float(e.temperature),float(e.pressure),float(e.oxygen)*100,scores.atmosphere,scores.temperature,scores.water,float(e.ecology),float(e.stable_seconds)]
	if current.has("restoration2"):
		environment_label.text+="\n염류 %.0f / 목표 ≤20 · 토양 %.0f / 목표 ≥60 · Mk.2 필터·기반재 필요"%[float(current.restoration2.salinity),float(current.restoration2.soil)]
	guidance.text="계약 인계 완료 · 다음 목적지에서 재투자하세요." if current.state=="settled" else ("광맥 채집 → 창고 반납 → 태양광·충전기·제작소 → 로봇 제작" if current.robots.is_empty() else "로봇에 광맥을 배정하고 대기·온도·물·생태 시설을 가동하세요.")
	if not current.jobs.is_empty():guidance.text+="\n제작 진행 · %.0f / %.0f초"%[float(current.jobs.values()[0].progress),float(current.jobs.values()[0].seconds)]
func confirm_settlement() -> void:
	if ledger.is_empty() or not ledger.sites.has(body_id):return
	var payment: int=int(FrontierExpeditionBusiness.config().contract_base_reward)+planet_tier*int(FrontierExpeditionBusiness.config().contract_tier_reward)
	var dialog:=ConfirmationDialog.new();dialog.title="지역 복원 계약 인계";dialog.dialog_text="복원 계약 대금 %d Cr\n현장 시설·로봇·재고를 인계하고 복원 대금을 한 번 받습니다.\n격납고로 회수한 로봇과 영구 기술은 유지됩니다.\n조건 미충족 시 자산을 변경하지 않습니다."%payment;dialog.confirmed.connect(func():command.emit("business_settle",{});dialog.queue_free());dialog.canceled.connect(dialog.queue_free);add_child(dialog);dialog.popup_centered(Vector2i(510,190))

func engineering_command(stage: String) -> void:
	command.emit("business_research_"+stage,{"project":selected(research_project),"building_id":selected(research_facility)})
func update_engineering() -> void:
	var key:=selected(research_project);var def:=FrontierFieldEngineering.definition(key)
	if def.is_empty():return
	var current: Dictionary=ledger.get("sites",{}).get(body_id,{})
	var facilities: Dictionary={}
	for id in current.get("buildings",{}):
		if id!=context_id:continue
		var b: Dictionary=current.buildings[id]
		if b.type in ["factory",def.building]:facilities[id]=FrontierCatalog.entry("buildings",b.type).name+" · "+str(b.status)+(" · 개조 완료" if not b.get("engineering","").is_empty() else "")
	choices(research_facility,facilities)
	var row: Dictionary=engineering.get("projects",{}).get(key,{})
	var stages: Dictionary={"prototype":"시제품 제작","prototype_ready":"현장 시험 준비","trial":"현장 시험","certified":"설계도 확정"}
	research_detail.text=def.description+"\n"+str(stages.get(row.get("stage",""),"관련 생물의 기초 분석 필요"))
	if row.is_empty():
		for environment in def.environments:
			if knowledge.get("research",{}).has(environment):research_detail.text=def.description+"\n기초 분석 완료 · 제작소에서 시제품을 제작하세요.";break
	else:
		research_detail.text+=" · %.0f초\n원본 관측: %s"%[float(row.progress),FrontierEcologyCatalog.form(row.form_id).name]
		if row.stage in ["prototype","trial"] and row.body_id!=body_id:research_detail.text+="\n다른 행성의 실험 시설로 돌아가세요."
	research_prototype_button.disabled=not row.is_empty()
	research_trial_button.disabled=row.get("stage")!="prototype_ready"
	research_install_button.disabled=row.get("stage")!="certified" or not current.get("buildings",{}).get(selected(research_facility),{}).get("engineering","").is_empty()
	research_cancel_button.disabled=row.get("stage") not in ["prototype","trial"]

func refresh_building_cost() -> void:
	for kind in building_cards:building_cards[kind].set_pressed_no_signal(kind==selected(building))
	building_cost.value="건설 재료 · "+FrontierCatalog.cost_text(FrontierCatalog.entry("buildings",selected(building)).cost)
