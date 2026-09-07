class_name FrontierShipyardPanel
extends PanelContainer
signal command(kind: String,args: Dictionary)
var heading: Label
var summary: FrontierResourceReadout
var details: FrontierResourceReadout
var outcome: Label
var kind: OptionButton
var owned: OptionButton
var actions: Array[Button]=[]
var last_inventory: String=""
var vessel: Dictionary={}
func _ready() -> void:
	theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE);offset_left=24;offset_right=578;offset_top=140;offset_bottom=-24
	var style:=FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,20);add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",9);scroll.add_child(column)
	heading=label(column,"KESTREL · 원정선 정비",24)
	summary=resource_label(column)
	kind=OptionButton.new();kind.fit_to_longest_item=false;column.add_child(kind)
	for key in FrontierVesselRefit.config().modules:
		kind.add_icon_item(FrontierResourceIcons.menu_texture("ship_module"),FrontierVesselRefit.definition(key).name);kind.set_item_metadata(kind.item_count-1,key)
	kind.item_selected.connect(func(_index: int):refresh_details())
	details=resource_label(column);refresh_details()
	var cfg:=FrontierVesselRefit.config()
	button(column,"표준 모듈 제작 · %d Cr · %s"%[cfg.build_credits,FrontierCatalog.cost_text(cfg.build_materials)],func():send("vessel_build"))
	button(column,"모듈 추첨 · %d Cr · %s"%[cfg.draw_credits,FrontierCatalog.cost_text(cfg.draw_materials)],func():send("vessel_draw"))
	label(column,"게임 내 공동 자금으로 추첨합니다. 표준 %d%% · 개량 %d%% · 희귀 %d%%. 매 %d번째는 선택 종류의 개량 등급 확정, 이미 가진 종류·등급은 부품 %d개로 전환됩니다."%[cfg.weights[0],cfg.weights[1],cfg.weights[2],cfg.pity_interval,cfg.duplicate_parts],13)
	outcome=label(column,"")
	owned=OptionButton.new();owned.fit_to_longest_item=false;column.add_child(owned)
	owned.item_selected.connect(func(_index: int):refresh_details())
	button(column,"선택 모듈 장착 · 같은 슬롯 교체",func():send("vessel_equip"))
	button(column,"선택 모듈 개량",func():send("vessel_upgrade"))
	button(column,"선택 모듈 해제",func():
		var id:=selected(owned)
		if vessel.get("modules",{}).has(id):command.emit("vessel_unequip",{"slot":FrontierVesselRefit.definition(vessel.modules[id].type).slot}))
	button(column,"해제한 모듈 분해 · 부품 회수",func():send("vessel_salvage"))
	label(column,"추진 슬롯 1개 · 공용 슬롯 1개 (실험실 / 수송 포드).\n호스트가 착륙선 주변에서 정비합니다. 제작·추첨·개량은 진행 중인 사업 현장 창고를 사용합니다. 정비 후 승무원은 출항 준비를 다시 확인합니다.",13)
	var close:=Button.new();close.text="닫기";close.pressed.connect(hide);column.add_child(close);hide()
func label(parent: Node,text_value: String,size_value: int=15) -> Label:
	var node:=Label.new();node.text=text_value;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.add_theme_font_size_override("font_size",size_value);parent.add_child(node);return node
func button(parent: Node,text_value: String,callback: Callable) -> void:
	var node:=Button.new();node.text=text_value;node.custom_minimum_size.y=36;node.pressed.connect(callback);parent.add_child(node);FrontierResourceIcons.button_caption(node);actions.append(node)
func selected(option: OptionButton) -> String:return str(option.get_item_metadata(option.selected)) if option.selected>=0 else ""
func send(action: String) -> void:command.emit(action,{"module_type":selected(kind),"module_id":selected(owned)})
func refresh_details() -> void:
	if details==null:return
	var def:=FrontierVesselRefit.definition(selected(kind));var cfg:=FrontierVesselRefit.config()
	details.value=def.description+"\n등급 순서: 표준 → 개량 → 희귀\n질량 %s t · 소비 전력 %s MW"%[str(def.mass),str(def.power)]
	if owned!=null and vessel.get("modules",{}).has(selected(owned)):
		var module: Dictionary=vessel.modules[selected(owned)];var grade:=FrontierVesselRefit.grade_index(module.grade)
		if grade<2:details.value+="\n개량 비용 %d Cr · 부품 %d · %s%s"%[cfg.upgrade_credits[grade],(0 if grade==0 else cfg.upgrade_parts[grade]),FrontierCatalog.cost_text(FrontierProductionTier2.config().vessel_upgrade_cost if grade==0 else cfg.upgrade_materials)," · 관련 생물공학 인증 필요" if grade==1 else ""]
		else:details.value+="\n최고 등급입니다."
func update_snapshot(snapshot: Dictionary,business: Dictionary) -> void:
	vessel=snapshot.get("vessel",{})
	heading.text=FrontierSpaceStation.hull(vessel).name+" · 원정선 정비"
	var stats: Dictionary=snapshot.get("vessel_stats",{});var cfg:=FrontierVesselRefit.config()
	if stats.is_empty():return
	summary.value="항속거리 %.1f 항로 단위\n질량 %.1f / %.1f t · 전력 %.1f / %.1f MW\n접근 성능 ×%.2f · 현장 연구 ×%.2f · 로봇 격납고 %d칸\n공동 자금 %s · 부품 %d · 확정 추첨까지 %d회"%[stats.get("stellar_range",8.0),stats.mass,stats.get("maximum_mass",cfg.maximum_mass),stats.power,stats.get("reactor_power",cfg.reactor_power),stats.speed,stats.research_speed,stats.hangar,str(int(business.credits))+" Cr" if business.has("credits") else "착륙 후 장부 확인",vessel.get("parts",0),int(cfg.pity_interval)-int(vessel.get("draws",0))%int(cfg.pity_interval)]
	var fingerprint:=FrontierUniverse.fingerprint(vessel)
	if fingerprint!=last_inventory:
		last_inventory=fingerprint;var old:=selected(owned);owned.clear()
		for id in vessel.get("modules",{}):
			var module: Dictionary=vessel.modules[id]
			owned.add_icon_item(FrontierResourceIcons.menu_texture("ship_module"),FrontierVesselRefit.definition(module.type).name+" · "+{"standard":"표준","improved":"개량","rare":"희귀"}[module.grade]+(" · 장착" if id in vessel.loadout.values() else ""));owned.set_item_metadata(owned.item_count-1,id)
			if id==old:owned.select(owned.item_count-1)
		var draw: Dictionary=vessel.get("last_draw",{})
		outcome.text=""
		if not draw.is_empty():outcome.text="최근 %d회: %s · %s%s%s"%[draw.index,FrontierVesselRefit.definition(draw.type).name,{"standard":"표준","improved":"개량","rare":"희귀"}[draw.grade]," · 확정 획득" if draw.guaranteed else ""," · 중복 → 부품" if draw.duplicate else ""]
		refresh_details()
	var allowed: bool=snapshot.self_id==snapshot.crew.owner_id and snapshot.crew.members[snapshot.self_id].area=="surface"
	for node in actions:node.disabled=not allowed

func resource_label(parent: Node) -> FrontierResourceReadout:
	var item:=FrontierResourceReadout.new();item.custom_minimum_size.x=0;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(item);return item
