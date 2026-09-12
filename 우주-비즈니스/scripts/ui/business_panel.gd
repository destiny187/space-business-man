class_name FrontierBusinessPanel
extends PanelContainer
signal command(kind: String,args: Dictionary)
signal prefer_robot(id: String)
var work_cards: GridContainer
var work_signature: String=""
var filter_context: String=""
signal place_building(kind: String)
signal station_action(kind: String)
var context_kind: String="build"
var context_id: String=""
var factory_navigation: HBoxContainer
var factory_section: OptionButton
var factory_category: OptionButton
var outer_scroll: ScrollContainer
var main_column: VBoxContainer
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
var workload_label: Label
var guidance: Label
var technology: OptionButton
var building: OptionButton
var building_message: Label
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
var planet_body: Dictionary={}
var vessel_terminal: FrontierVesselTerminal
var shuttle_panel: FrontierShuttlePanel
var supply_panel: FrontierPlanetSupplyPanel
var register_button: Button
var engineering: Dictionary={}
var knowledge: Dictionary={}
var engineering_cards: HFlowContainer
var engineering_preview: FrontierEquipmentPreview
var engineering_steps: Array[Label]=[]
var engineering_cost: FrontierResourceReadout
var engineering_progress: ProgressBar
var research_project: OptionButton
var research_facility: OptionButton
var research_detail: Label
var research_prototype_button: Button
var research_trial_button: Button
var research_install_button: Button
var research_cancel_button: Button
func _ready() -> void:
	visibility_changed.connect(_flush_paint)
	theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);offset_left=24;offset_right=minf(900,get_viewport().get_visible_rect().size.x-24);offset_top=26;offset_bottom=-24
	get_viewport().size_changed.connect(func():offset_right=minf(900,get_viewport().get_visible_rect().size.x-24))
	var style:=FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,20);add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();outer_scroll=scroll;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column:=VBoxContainer.new();main_column=column;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",9);scroll.add_child(column)
	heading=label(column,"건설  B 닫기",24)
	summary=FrontierResourceReadout.new();column.add_child(summary);guidance=label(column,"");stock=FrontierResourceReadout.new();column.add_child(stock)
	workload_label=label(column,"")
	register_button=button(column,"무료 개발 등록",func():command.emit("business_register",{}))
	deposit_button=button(column,"현장 창고에 자원 반납",func():station_action.emit("storage"))
	factory_navigation=HBoxContainer.new();column.add_child(factory_navigation)
	factory_section=option(factory_navigation)
	for title in ["제작","시설 관리"]:factory_section.add_item(title)
	factory_category=option(factory_navigation)
	for title in ["부품","로봇","로버","시험기","생물공학","소형선"]:factory_category.add_item(title)
	factory_section.item_selected.connect(func(_i):_factory_page())
	factory_category.item_selected.connect(func(_i):_factory_page())
	tabs=TabContainer.new();tabs.use_hidden_tabs_for_min_size=false;tabs.custom_minimum_size.y=290;column.add_child(tabs)
	robot_factory=load("res://scripts/ui/robot_factory_panel.gd").new();tabs.add_child(robot_factory);robot_factory.configure(self)
	production_panel=FrontierProductionPanel.new();tabs.add_child(production_panel);production_panel.configure(self)
	var build_tab:=VBoxContainer.new();build_tab.name="건설";tabs.add_child(build_tab)
	building=option(build_tab)
	for key in FrontierExpeditionBusiness.config().buildings:
		var def:=FrontierCatalog.entry("buildings",key);building.add_item(def.name);building.set_item_metadata(building.item_count-1,key)
	building.hide()
	building_cost=FrontierResourceReadout.new();building_cost.centered_cost=true;building_cost.custom_minimum_size.x=0;build_tab.add_child(building_cost)
	building.item_selected.connect(func(_index: int):refresh_building_cost())
	building_message=label(build_tab,"",14);building_message.add_theme_color_override("font_color",FrontierInterfaceStyle.DANGER)
	button(build_tab,"선택 시설 배치  지면 조준 후 클릭",try_place_building)
	var grid:=GridContainer.new();grid.columns=4;build_tab.add_child(grid)
	for index in building.item_count:
		var kind:=str(building.get_item_metadata(index))
		var def:=FrontierCatalog.entry("buildings",kind)
		var card:=Button.new();card.custom_minimum_size=Vector2(145,168);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.toggle_mode=true
		card.tooltip_text=def.name+"  "+FrontierCatalog.cost_text(def.cost)+"\n"+str(def.get("description",""))
		var content:=VBoxContainer.new();content.add_theme_constant_override("separation",3);content.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_top=4;content.offset_bottom=-4
		var preview:=TextureRect.new();preview.texture=load("res://assets/ui/previews/"+def.model+".png");preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.custom_minimum_size.y=78;preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(preview)
		var title:=Label.new();title.text=def.name;title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",14);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(title)
		var costs:=FrontierResourceReadout.new();costs.centered_cost=true;costs.custom_minimum_size=Vector2(0,32);costs.mouse_filter=Control.MOUSE_FILTER_IGNORE;costs.add_theme_font_size_override("normal_font_size",13);content.add_child(costs);card.set_meta("cost_readout",costs)
		card.pressed.connect(func():building.select(index);building_message.text="";refresh_building_cost());grid.add_child(card);building_cards[kind]=card
	refresh_building_cost()
	var facility_tab:=VBoxContainer.new();facility_tab.name="시설 관리"
	facility_picture=FrontierEquipmentPreview.new();facility_picture.custom_minimum_size=Vector2(150,150);facility_picture.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;facility_tab.add_child(facility_picture)
	facility_status=label(facility_tab,"")
	facility=option(facility_tab)
	button(facility_tab,"가동 / 정지 · 엄폐물 수리",func():command.emit("business_toggle",{"building_id":selected(facility)}))
	button(facility_tab,"시설 철거 · 엄폐물은 남은 내구도만큼 반환",func():command.emit("business_demolish",{"building_id":selected(facility)}))
	label(build_tab,"Esc  배치 취소",12)
	var research_tab:=VBoxContainer.new();research_tab.name="기술";tabs.add_child(research_tab)
	technology=option(research_tab)
	label(research_tab,"기초 설계 사용 가능")
	warehouse=VBoxContainer.new();warehouse.name="창고";tabs.add_child(warehouse)
	warehouse_stock=option(warehouse)
	warehouse_stock.hide()
	warehouse_grid=GridContainer.new();warehouse_grid.columns=5;warehouse.add_child(warehouse_grid)
	button(warehouse,"선택 자원 1개 인수",func():command.emit("business_withdraw",{"resource":selected(warehouse_stock),"amount":1}))
	button(warehouse,"선택 자원 20개 인수",func():command.emit("business_withdraw",{"resource":selected(warehouse_stock),"amount":20}))
	supply_controls=VBoxContainer.new();warehouse.add_child(supply_controls)
	supply=option(supply_controls)
	for key in FrontierExpeditionBusiness.config().store_unit_price:
		supply.add_icon_item(FrontierResourceIcons.menu_texture(key),"%s 20개  %d Cr"%[FrontierCatalog.entry("resources",key).name,int(FrontierExpeditionBusiness.config().store_unit_price[key])*20]);supply.set_item_metadata(supply.item_count-1,key)
	button(supply_controls,"보급 20개 인수",func():command.emit("business_supply",{"resource":selected(supply)}))
	label(research_tab,"공동 자금은 호스트가 지출합니다. 기술은 영구 유지하며 실제 장비는 재료로 제작합니다. 생태 배양기는 허가된 표준 균주를 사용하는 지역 복원 설비입니다.")
	var robot_tab:=VBoxContainer.new();robot_tab.name="로봇";tabs.add_child(robot_tab)
	var robot_preview:=FrontierEquipmentPreview.new();robot_preview.custom_minimum_size=Vector2(140,100);robot_preview.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;robot_tab.add_child(robot_preview);robot_preview.show_model("miner")
	factory=option(robot_tab);factory.hide()
	robot=option(robot_tab)
	robot_job_status=label(robot_tab,"")
	robot_controls=VBoxContainer.new();robot_tab.add_child(robot_controls)
	vein=option(robot_controls);vein.hide()
	work_cards=GridContainer.new();work_cards.columns=5;robot_controls.add_child(work_cards)
	button(robot_controls,"선택 작업 시작",func():command.emit("business_robot_auto",{"robot_id":selected(robot),"resource":selected(vein),"enabled":true}))
	button(robot_controls,"현재 위치를 중심으로 시작",func():command.emit("business_robot_auto",{"robot_id":selected(robot),"resource":selected(vein),"enabled":true,"reset_anchor":true}))
	label(robot_controls,"작업 범위 80m  발견한 광물만 표시  R: 조준한 광맥 지시")
	button(robot_controls,"작업 중지  창고로 복귀",func():command.emit("business_robot_return",{"robot_id":selected(robot)}))
	button(robot_controls,"긴급 충전  50 Cr",func():command.emit("business_robot_rescue",{"robot_id":selected(robot)}))
	button(robot_controls,"R 지시 우선 로봇으로 선택",func():prefer_robot.emit(selected(robot)))
	button(robot_controls,"R 지시 로봇 자동 선정",func():prefer_robot.emit(""))
	recovery_controls=VBoxContainer.new();robot_tab.add_child(recovery_controls)
	button(recovery_controls,"창고 근처 로봇을 격납고로 회수",func():command.emit("business_robot_recover",{"robot_id":selected(robot)}))
	hangar=option(recovery_controls)
	button(recovery_controls,"운송한 로봇 재파견",func():command.emit("business_robot_deploy",{"robot_id":selected(hangar)}))
	var engineering_tab:=VBoxContainer.new();engineering_tab.name="생물공학";tabs.add_child(engineering_tab)
	engineering_cards=HFlowContainer.new();engineering_tab.add_child(engineering_cards)
	research_project=option(engineering_tab);research_project.hide()
	for key in FrontierFieldEngineering.config().projects:
		research_project.add_icon_item(FrontierResourceIcons.menu_texture(key),FrontierFieldEngineering.definition(key).name);research_project.set_item_metadata(research_project.item_count-1,key)
	research_project.item_selected.connect(func(_index: int):update_engineering())
	for key in FrontierFieldEngineering.config().projects:
		var card:=FrontierItemTile.new();card.picture=FrontierResourceIcons.texture(key);card.caption=FrontierFieldEngineering.definition(key).name;card.tooltip_text=card.caption;card.set_meta("project",key);engineering_cards.add_child(card)
		card.pressed.connect(func():
			for i in research_project.item_count:
				if research_project.get_item_metadata(i)==key:research_project.select(i);update_engineering();break)
	var evidence_row:=HBoxContainer.new();engineering_tab.add_child(evidence_row)
	engineering_preview=FrontierEquipmentPreview.new();engineering_preview.custom_minimum_size=Vector2(140,120);evidence_row.add_child(engineering_preview)
	research_detail=label(evidence_row,"")
	var steps:=HBoxContainer.new();engineering_tab.add_child(steps)
	for title in ["분석","시제품","현장 시험","개조"]:
		var step:=label(steps,title,14);engineering_steps.append(step)
	engineering_progress=ProgressBar.new();engineering_progress.custom_minimum_size.y=18;engineering_tab.add_child(engineering_progress)
	engineering_cost=FrontierResourceReadout.new();engineering_tab.add_child(engineering_cost)
	research_facility=option(engineering_tab)
	research_facility.item_selected.connect(func(_index: int):update_engineering())
	research_prototype_button=button(engineering_tab,"시제품 제작",func():engineering_command("prototype"))
	research_trial_button=button(engineering_tab,"현장 시험 시작",func():engineering_command("trial"))
	research_install_button=button(engineering_tab,"설비에 적용",func():engineering_command("install"))
	research_cancel_button=button(engineering_tab,"실험 중지  투입 재료는 반환되지 않음",func():engineering_command("cancel"))

	var contract_tab:=VBoxContainer.new();contract_tab.name="환경 / 계약";tabs.add_child(contract_tab)
	for category in ["atmosphere","temperature","water","ecology"]:
		var row:=HBoxContainer.new();contract_tab.add_child(row)
		var title:=label(row,{"atmosphere":"대기","temperature":"온도","water":"물","ecology":"생태"}[category]);title.custom_minimum_size.x=50;title.size_flags_horizontal=0
		var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(200,22);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(bar);environment_bars[category]=bar
	environment_label=label(contract_tab,"")
	button(contract_tab,"시설 / 재고 인계 후 정산…",confirm_settlement)
	button(contract_tab,"생산 거점 유지하며 정산…",func():confirm_settlement(true))
	label(contract_tab,"전체 인계는 계약 대금 전액, 생산 거점 유지는 60%를 받습니다. 유지하려면 착륙선의 생산 이용권이 필요합니다. 인계한 자산은 되돌릴 수 없습니다.")
	tabs.add_child(facility_tab)
	var ship_tab:=VBoxContainer.new();ship_tab.name="착륙선";tabs.add_child(ship_tab)
	var supply_tab:=VBoxContainer.new();supply_tab.name="생산 거점";tabs.add_child(supply_tab)
	supply_panel=FrontierPlanetSupplyPanel.new();supply_tab.add_child(supply_panel);supply_panel.configure(self)
	vessel_terminal=FrontierVesselTerminal.new();ship_tab.add_child(vessel_terminal);vessel_terminal.configure(self)
	shuttle_panel=FrontierShuttlePanel.new();tabs.add_child(shuttle_panel);shuttle_panel.configure(self)
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
	factory_navigation.visible=kind=="factory"
	var allowed: Array=[]
	match kind:
		"build":allowed=["건설"]
		"ship":allowed=["착륙선","환경 / 계약","생산 거점","소형선"]
		"base","storage":allowed=["창고","로봇"]
		"factory":allowed=["로봇 제작","로버 제작","시험기 조립","생산 / 개조","생물공학","시설 관리","소형선"]
		"robot":allowed=["로봇","생산 / 개조"]
		_:allowed=["시설 관리","생산 / 개조"]
	if kind in ["atmosphere","thermal","water","biolab"]:allowed.append("생물공학")
	if kind=="storage":allowed.append("시설 관리")
	tabs.tabs_visible=allowed.size()>1 and kind!="factory"
	for i in tabs.get_tab_count():tabs.set_tab_hidden(i,str(tabs.get_tab_control(i).name) not in allowed)
	for i in tabs.get_tab_count():
		if str(tabs.get_tab_control(i).name)==allowed[0]:tabs.current_tab=i;break
	if kind=="factory":_factory_page()
	else:_factory_layout(false)
	var title: String={"build":"건설","ship":"착륙선 단말","base":"현장 창고","factory":"현장 제작소","robot":"M-01 작업 관리"}.get(kind,FrontierCatalog.entry("buildings",kind).get("name","시설"))
	heading.text=title+"  Esc 닫기"
	register_button.hide()
	stock.visible=kind not in ["base","storage","ship"]
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
	for card in engineering_cards.get_children():card.visible=available.has(card.get_meta("project"))
func refresh_context(current: Dictionary) -> void:
	register_button.hide()
	guidance.visible=current.is_empty()
	if current.is_empty():guidance.text="착륙 지표를 준비 중입니다."
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
	robot_job_status.text="Mk.%d  %s  %s"%[int(target_robot.get("tier",1)),"자동" if target_robot.get("auto_enabled",false) else "지정 광맥" if not target_robot.get("manual_target","").is_empty() else "대기",str(target_robot.get("status",""))]
	if context_kind not in ["build","ship","base"]:
		var row: Dictionary=current.get("robots" if context_kind=="robot" else "buildings",{}).get(context_id,{})
		if context_kind!="robot" and not row.is_empty():
			facility_picture.show_model(FrontierCatalog.entry("buildings",row.type).model)
			facility_status.text=FrontierCatalog.entry("buildings",row.type).description if row.type in FrontierPlanetWeather.config().buildings else "Mk.%d  %s"%[int(row.get("tier",1)),row.get("status","")]
		if FrontierCombatCover.is_cover(row):facility_status.text=FrontierCombatCover.status(row)+"\n수리: "+FrontierCatalog.cost_text(FrontierCombatCover.config().buildings[row.type].repair)
		if row.is_empty() or not FrontierPlanetSupply.operating(current):hide()
func context_in_range(position: Vector3) -> bool:
	if context_kind=="build":return true
	if context_kind=="ship":return position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	var site: Dictionary=ledger.get("sites",{}).get(body_id,{})
	if site.is_empty():return false
	if context_kind=="base":return site.get("base_deployed",true) and not site.get("base_submerged",false) and position.distance_to(FrontierCrewWorld.vector(site.center))<=float(FrontierExpeditionBusiness.config().deposit_range)
	var row: Dictionary=site.get("robots" if context_kind=="robot" else "buildings",{}).get(context_id,{})
	return not row.is_empty() and not row.get("submerged",false) and position.distance_to(FrontierCrewWorld.vector(row.position))<=float(FrontierExpeditionBusiness.config().deposit_range if context_kind=="storage" else FrontierExpeditionBusiness.config().interaction_range)
# Keep authoritative data current while expensive card/layout work sleeps.
var pending_paint:=false
var paint_arguments: Array=[]
func update(value: Dictionary,id: String,actor: String,tier: int=1,research: Dictionary={},ecology: Dictionary={},planet: Dictionary={},viewer: Vector3=Vector3.ZERO,participant_count: int=1) -> void:
	ledger=value;body_id=id;actor_id=actor;planet_tier=tier;planet_body=planet;engineering=research;knowledge=ecology
	paint_arguments=[value,id,actor,tier,research,ecology,planet,viewer,participant_count]
	pending_paint=true
	_flush_paint()
func _flush_paint() -> void:
	if not is_visible_in_tree() or not pending_paint:return
	pending_paint=false
	_paint_update.callv(paint_arguments)
func _paint_update(value: Dictionary,id: String,actor: String,tier: int=1,research: Dictionary={},ecology: Dictionary={},planet: Dictionary={},viewer: Vector3=Vector3.ZERO,participant_count: int=1) -> void:
	workload_label.text=FrontierCoopWorkload.description(value.get("sites",{}).get(id,{}),tier,participant_count)
	workload_label.visible=context_kind=="ship" and planet.get("origin","")!="solar_reference" and tabs.get_current_tab_control().name=="환경 / 계약"
	register_button.hide();guidance.show()
	ledger=value;body_id=id;actor_id=actor;planet_tier=tier;planet_body=planet;engineering=research;knowledge=ecology
	supply_panel.update(value,planet,actor,actor==value.get("owner_id",""))
	refresh_context(value.get("sites",{}).get(id,{}))
	refresh_building_cost()
	update_engineering()
	production_panel.update_site(value.get("sites",{}).get(id,{}))
	for bar in environment_bars.values():bar.value=0
	register_button.disabled=not value.is_empty() and (value.sites.has(id) or not value.get("active_elsewhere","").is_empty())
	stock.value="등록된 현장 창고가 없습니다.";environment_label.text="착륙 지표의 환경을 조사합니다."
	for item in [facility,factory,robot,vein,technology,hangar]:
		if value.is_empty() or not value.sites.has(id):choices(item,{})
	if value.is_empty():summary.value="첫 원정  채광 가능";register_button.hide();stock.value="광맥 조준  클릭 유지로 채광";return
	summary.value="공동 자금 %s Cr  격납고 %d/%d"%[str(int(value.credits)),value.hangar.size(),int(value.get("hangar_capacity",FrontierExpeditionBusiness.config().hangar_slots))]
	if not value.get("active_elsewhere","").is_empty():guidance.text="다른 행성에서 사업 진행 중  등록한 사업으로 돌아가 정산하세요."
	elif not value.sites.has(id):guidance.text="광맥을 바로 채집할 수 있습니다."
	var current: Dictionary=value.sites.get(id,{})
	register_button.hide();guidance.visible=current.is_empty()
	production_panel.update_site(current)
	if current.is_empty():return
	stock.value="건설 재료  내 배낭" if context_kind=="build" else "생산 재료  현장 창고    장비/시험기  내 배낭"
	var factories: Dictionary={};var buildings: Dictionary={};var robots: Dictionary={};var veins: Dictionary={};var technologies: Dictionary={};var transported: Dictionary={}
	for key in current.buildings:
		if key!=context_id:continue
		var b: Dictionary=current.buildings[key];buildings[key]=FrontierCatalog.entry("buildings",b.type).name+"  "+str(b.status)
		if b.type=="factory":factories[key]=buildings[key]
	for key in current.robots:
		if context_kind=="robot" and key!=context_id:continue
		var r: Dictionary=current.robots[key];robots[key]=key+"  "+FrontierCatalog.entry("grades",r.grade).name+"  "+str(r.status)
	for key in value.hangar:transported[key]=key+"  "+FrontierCatalog.entry("grades",value.hangar[key].grade).name
	veins[""]="전체 자원  자동"
	for key in value.get("discovered_resources",[]):
		veins[key]=FrontierCatalog.entry("resources",key).name
	for key in FrontierExpeditionBusiness.config().technologies:
		var def:=FrontierCatalog.entry("technologies",key);technologies[key]=def.name+("  보유" if FrontierEarlyAccess.available(value,key) else "  %d Cr"%int(def.price))
	choices(facility,buildings);choices(factory,factories);choices(robot,robots);choices(vein,veins);choices(technology,technologies);choices(hangar,transported)
	var selected_robot: Dictionary=current.robots.get(selected(robot),{})
	var next_filter:=selected(robot)+":"+str(selected_robot.get("resource_filter",""))
	if filter_context!=next_filter:
		filter_context=next_filter
		for i in vein.item_count:
			if str(vein.get_item_metadata(i))==str(selected_robot.get("resource_filter","")):vein.select(i);break
	refresh_work_cards(veins)
	var e: Dictionary=current.environment;var report:=FrontierEvaluator.environment_report(current,body_id)
	for category in environment_bars:
		environment_bars[category].visible=report.observed
		if report.observed:environment_bars[category].value=float(report.scores[category])
	environment_label.text="지역 환경  평가 중"
	if report.observed:
		environment_label.text="환경 적합도 %.0f%%  지역 환경\n지역 전력 %.0f / %.0f kW\n온도 %.1f°C  기압 %.2f bar  산소 %.1f%%\n%s  안정화 %.0f / %.0f초"%[report.overall,float(current.power_demand),float(current.power_supply),float(e.temperature),float(e.pressure),float(e.oxygen)*100,"✓ 안정" if report.stable else "◷ 관찰 중",report.stable_seconds,report.stable_required]
		if not report.limiting_factors.is_empty():environment_label.text+="\n! "+str(report.limiting_factors[0].label)
		if current.has("restoration2"):
			var restore_cfg: Dictionary=FrontierProductionTier2.config().restoration
			environment_label.text+="\n염류 %.0f / 목표 ≤%.0f  토양 %.0f / 목표 ≥%.0f"%[float(current.restoration2.salinity),float(restore_cfg.salinity_target),float(current.restoration2.soil),float(restore_cfg.soil_target)]
	if FrontierRegionalTerraform.enabled(current):
		var completed:=0
		for region in current.regions.values():
			if FrontierRegionalTerraform.ready(region):completed+=1
		environment_label.text+="\n지역 복원 %d / %d  ·  중간 지급 %d Cr\nTab 지도에서 남은 현장을 확인하세요."%[completed,current.regions.size(),FrontierRegionalTerraform.paid(current)]
	guidance.text="계약 인계 완료  다음 목적지에서 재투자하세요." if current.state=="settled" else "F 상호작용  B 건설  I 아이템"
	if not current.jobs.is_empty():guidance.text+="\n제작 진행  %.0f / %.0f초"%[float(current.jobs.values()[0].progress),float(current.jobs.values()[0].seconds)]
func confirm_settlement(retain: bool=false) -> void:
	if ledger.is_empty() or not ledger.sites.has(body_id):return
	var payment:=FrontierPlanetSupply.settlement_payment(ledger.get("sites",{}).get(body_id,{}),planet_tier,retain)
	var dialog:=ConfirmationDialog.new();dialog.title="지역 복원 계약 인계";dialog.dialog_text="복원 계약 대금 %d Cr\n현장 시설 / 로봇 / 재고를 인계하고 복원 대금을 한 번 받습니다.\n격납고로 회수한 로봇과 영구 기술은 유지됩니다.\n조건 미충족 시 자산을 변경하지 않습니다."%payment;dialog.dialog_text=("남은 복원 대금 %d Cr\n총대금의 60%%에서 중간 지급액을 제외합니다.\n인계 대금 40%%를 포기하고 시설 / 로봇 / 재고와 생산 이용권을 유지합니다.\n호스트 세션 중에는 다른 행성에서도 생산합니다. 원료 / 전력 / 창고 조건에 따라 대기합니다."%payment) if retain else dialog.dialog_text;dialog.confirmed.connect(func():command.emit("business_settle",{"retain":retain});dialog.queue_free());dialog.canceled.connect(dialog.queue_free);add_child(dialog);dialog.popup_centered(Vector2i(510,190))

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
		if b.type in ["factory",def.building]:facilities[id]=FrontierCatalog.entry("buildings",b.type).name+"  "+str(b.status)+("  개조 완료" if not b.get("engineering","").is_empty() else "")
	choices(research_facility,facilities)
	var row: Dictionary=engineering.get("projects",{}).get(key,{})
	var analyzed:=false
	var form_id: String=str(row.get("form_id",""))
	for environment in def.environments:
		if knowledge.get("research",{}).has(environment):analyzed=true;form_id=knowledge.research[environment].form_id;break
	for card in engineering_cards.get_children():card.selected=card.get_meta("project")==key;card.queue_redraw()
	engineering_preview.show_model(FrontierCatalog.entry("buildings",def.building).model if form_id.is_empty() else FrontierEcologyCatalog.model_key(FrontierEcologyCatalog.form(form_id)))
	var stage: String=str(row.get("stage",""))
	var installed: bool=not current.get("buildings",{}).get(context_id,{}).get("engineering","").is_empty()
	var done: Array=[analyzed,stage in ["prototype_ready","trial","certified"],stage=="certified",installed]
	for i in engineering_steps.size():
		engineering_steps[i].text=("✓ " if done[i] else "%d "%(i+1))+["분석","시제품","현장 시험","개조"][i]
		engineering_steps[i].modulate=FrontierInterfaceStyle.ACCENT if done[i] else FrontierInterfaceStyle.MUTED
	research_detail.text=def.description
	if not analyzed:research_detail.text+="\n관련 생물을 E로 조사한 뒤 착륙선에서 분석하세요."
	elif not form_id.is_empty():research_detail.text+="\n연구 표본  "+FrontierEcologyCatalog.form(form_id).name
	var cfg:=FrontierFieldEngineering.config()
	engineering_progress.visible=stage in ["prototype","trial"]
	if engineering_progress.visible:
		var elapsed:=float(row.progress)
		engineering_progress.value=clampf(elapsed/float(cfg.trial_seconds if stage=="trial" else cfg.prototype_seconds)*100,0,100)
		if row.body_id!=body_id or row.facility_id!=context_id:research_detail.text+="\n진행 중인 실험 시설로 돌아가세요."
	var action: Button
	var cost: Dictionary={}
	for control in [research_prototype_button,research_trial_button,research_install_button,research_cancel_button]:control.hide()
	if stage.is_empty() and analyzed and context_kind=="factory":action=research_prototype_button;cost=cfg.prototype_cost
	elif stage=="prototype_ready":
		if context_kind==def.building:action=research_trial_button;cost=cfg.trial_cost
		else:research_detail.text+="\n"+FrontierCatalog.entry("buildings",def.building).name+"에서 현장 시험을 시작하세요."
	elif stage=="certified" and not installed:
		if context_kind==def.building:action=research_install_button;cost=cfg.install_cost
		else:research_detail.text+="\n"+FrontierCatalog.entry("buildings",def.building).name+"에 적용할 수 있습니다."
	elif stage in ["prototype","trial"] and row.body_id==body_id and row.facility_id==context_id:research_cancel_button.show();research_cancel_button.disabled=false
	engineering_cost.visible=not cost.is_empty();engineering_cost.value="현장 창고  "+FrontierCatalog.cost_text(cost)
	if action!=null:
		action.show()
		var facility_row: Dictionary=current.get("buildings",{}).get(context_id,{})
		action.disabled=not facility_row.get("active",false) or not FrontierExpeditionBusiness.affordable(current.get("inventory",{}),cost)
		if action.disabled:research_detail.text+="\n전력 / 가동 상태와 현장 창고 재료를 확인하세요."

func try_place_building() -> void:
	var cost: Dictionary=FrontierCatalog.entry("buildings",selected(building)).cost
	if not FrontierExpeditionBusiness.affordable(ledger.get("bags",{}).get(actor_id,{}),cost):
		building_message.text="재료가 부족합니다."
		return
	building_message.text=""
	place_building.emit(selected(building))

func refresh_building_cost() -> void:
	var bag: Dictionary=ledger.get("bags",{}).get(actor_id,{})
	for kind in building_cards:
		var card: Button=building_cards[kind]
		card.set_pressed_no_signal(kind==selected(building))
		var tier: int=FrontierCatalog.entry("buildings",kind).get("tier",1)
		if tier>=3:
			var blueprint:=FrontierFacilityBlueprints.required({"type":kind},tier)
			card.tooltip_text="공동 원정 설계도 필요" if blueprint not in ledger.get("facility_blueprints",[]) else FrontierCatalog.entry("buildings",kind).get("description","")
		card.get_meta("cost_readout").show_cost(FrontierCatalog.entry("buildings",kind).cost,bag,false,22)
	var cost: Dictionary=FrontierCatalog.entry("buildings",selected(building)).cost
	building_cost.show_cost(cost,bag,true)

func refresh_work_cards(values: Dictionary) -> void:
	var signature:=str(values.keys())
	if work_signature!=signature:
		work_signature=signature
		for child in work_cards.get_children():work_cards.remove_child(child);child.queue_free()
		for key in values:
			var card:=FrontierItemTile.new();card.set_meta("resource",key)
			card.caption="자동  전체" if key=="" else str(values[key]);card.tooltip_text=card.caption
			card.picture=load("res://assets/ui/previews/miner.png") if key=="" else FrontierResourceIcons.texture(key)
			card.pressed.connect(func():
				for i in vein.item_count:
					if str(vein.get_item_metadata(i))==key:vein.select(i);break
				refresh_work_cards(values))
			work_cards.add_child(card)
	for card in work_cards.get_children():card.selected=card.get_meta("resource")==selected(vein);card.queue_redraw()

func _factory_page() -> void:
	factory_category.visible=factory_section.selected==0
	var target: String="시설 관리" if factory_section.selected==1 else ["생산 / 개조","로봇 제작","로버 제작","시험기 조립","생물공학","소형선"][factory_category.selected]
	for i in tabs.get_tab_count():
		if str(tabs.get_tab_control(i).name)==target:tabs.current_tab=i;break
	_factory_layout(target=="생산 / 개조")
func _factory_layout(fixed: bool) -> void:
	outer_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED if fixed else ScrollContainer.SCROLL_MODE_AUTO
	main_column.size_flags_vertical=Control.SIZE_EXPAND_FILL if fixed else Control.SIZE_FILL
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL if fixed else Control.SIZE_FILL
