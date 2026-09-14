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
var action_map: Dictionary={}
var last_inventory: String=""
var vessel: Dictionary={}
var world: Dictionary={}
var snapshot: Dictionary={}
var preview: FrontierShipModulePreview
var comparison: GridContainer
var module_grid: GridContainer
var tabs: TabContainer
var choices: VBoxContainer
var empty: Label
var selected_slot:="propulsion"
var ghost: CheckButton
var pending:=false
var pending_sequence:=-1
var shown_draw:=0
func _ready() -> void:
	theme=FrontierInterfaceStyle.theme();set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=24;offset_right=-24;offset_top=24;offset_bottom=-24
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	heading=label(header,"원정선 정비",24);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=Button.new();close.text="닫기  Esc";header.add_child(close);close.pressed.connect(hide)
	summary=resource_label(column)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",18);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	var left:=VBoxContainer.new();left.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(left)
	preview=FrontierShipModulePreview.new();preview.custom_minimum_size=Vector2(300,210);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;left.add_child(preview)
	preview.slot_selected.connect(func(slot):selected_slot=slot;rebuild())
	ghost=CheckButton.new();ghost.text="선택 모듈로 교체 미리보기";left.add_child(ghost);ghost.toggled.connect(func(_v):refresh_details())
	var compare_scroll:=ScrollContainer.new();compare_scroll.custom_minimum_size.y=110;compare_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left.add_child(compare_scroll)
	comparison=GridContainer.new();comparison.columns=2;comparison.add_theme_constant_override("h_separation",18);comparison.size_flags_horizontal=Control.SIZE_EXPAND_FILL;compare_scroll.add_child(comparison)
	var right:=VBoxContainer.new();right.custom_minimum_size.x=370;right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(right)
	tabs=TabContainer.new();tabs.add_theme_stylebox_override("panel",StyleBoxEmpty.new());right.add_child(tabs)
	for title in ["보유 모듈","제작 설계","항해 개장"]:
		var placeholder:=Control.new();placeholder.name=title;tabs.add_child(placeholder)
	tabs.tab_changed.connect(func(_i):rebuild())
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(scroll)
	choices=VBoxContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(choices)
	module_grid=GridContainer.new();module_grid.columns=3;choices.add_child(module_grid)
	empty=label(choices,"이 슬롯에 장착할 모듈이 없습니다. 제작 설계에서 준비하세요.",14)
	kind=OptionButton.new();owned=OptionButton.new();choices.add_child(kind);choices.add_child(owned);kind.hide();owned.hide()
	details=resource_label(choices)
	var actions_grid:=GridContainer.new();actions_grid.columns=2;right.add_child(actions_grid)
	for entry in [["vessel_navigation_refit","항해 개장 적용"],["vessel_build","표준 모듈 제작"],["vessel_draw","모듈 추첨…"],["vessel_equip","이 슬롯에 장착"],["vessel_upgrade","다음 등급 개량"],["vessel_unequip","장착 해제"],["vessel_salvage","모듈 분해…"]]:
		var id: String=entry[0];var button:=Button.new();button.text=entry[1];button.custom_minimum_size.y=40;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions_grid.add_child(button);actions.append(button);action_map[id]=button
		button.pressed.connect(func():send(id))
	outcome=label(column,"호스트 작업  공동 자금과 현장 창고 재료",13)
	hide()
func label(parent: Node,text_value: String,size_value: int=15) -> Label:
	var node:=FrontierInterfaceStyle.label(parent,text_value,size_value);node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return node
func resource_label(parent: Node) -> FrontierResourceReadout:
	var item:=FrontierResourceReadout.new();item.custom_minimum_size.x=0;item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(item);return item
func selected(option: OptionButton) -> String:return str(option.get_item_metadata(option.selected)) if option.selected>=0 else ""
func update_snapshot(value: Dictionary,business: Dictionary) -> void:
	snapshot=value;vessel=value.get("vessel",{})
	business=business.duplicate();business.credits=int(value.get("shared_credits",business.get("credits",0)))
	if vessel.is_empty():vessel=FrontierVesselRefit.create(int(value.get("vessel_seed",0)),str(value.crew.world_id))
	world={"crew":value.crew,"location":value.location,"manifest":{"seed":value.get("vessel_seed",0)},"business":business,"vessel":vessel,"engineering":get_meta("engineering",{})}
	if heading==null or not visible:return
	heading.text=FrontierSpaceStation.hull(vessel).name+"  원정선 정비"
	var key:=str([vessel,business,value.crew.members[value.self_id].position,value.self_id])
	if key==last_inventory:return
	last_inventory=key;rebuild()
	var draw: Dictionary=vessel.get("last_draw",{})
	if int(draw.get("index",0))!=shown_draw:
		shown_draw=int(draw.index);outcome.text="추첨  "+FrontierVesselRefit.definition(draw.type).name+"  "+str({"standard":"표준","improved":"개량","rare":"희귀"}[draw.grade])+("  중복 → 연구 부품" if draw.duplicate else "  획득")
func rebuild() -> void:
	if module_grid==null or world.is_empty():return
	var old_kind:=selected(kind);var old_owned:=selected(owned)
	kind.clear();owned.clear()
	for id in FrontierVesselRefit.config().modules:
		var def:=FrontierVesselRefit.definition(id)
		if def.slot!=selected_slot:continue
		kind.add_item(def.name);kind.set_item_metadata(kind.item_count-1,id)
		if id==old_kind:kind.select(kind.item_count-1)
	for id in vessel.get("modules",{}):
		var module: Dictionary=vessel.modules[id]
		if FrontierVesselRefit.definition(module.type).slot!=selected_slot:continue
		owned.add_item(id);owned.set_item_metadata(owned.item_count-1,id)
		if id==old_owned:owned.select(owned.item_count-1)
	for child in module_grid.get_children():module_grid.remove_child(child);child.queue_free()
	var selector:=owned if tabs.current_tab==0 else kind
	for i in selector.item_count:
		var id: String=selector.get_item_metadata(i)
		var module: Dictionary=vessel.modules[id] if tabs.current_tab==0 else {"type":id,"grade":"standard"}
		var def:=FrontierVesselRefit.definition(module.type)
		var card:=FrontierItemTile.new();card.picture=load("res://assets/ui/previews/vessel_"+str(def.model).get_file()+".png");card.caption=def.name;card.grade=FrontierVesselRefit.grade_index(module.grade)+1;card.amount="장착" if id in vessel.get("loadout",{}).values() else "";card.tooltip_text=def.name;card.set_meta("index",i);module_grid.add_child(card)
		card.pressed.connect(func():selector.select(i);refresh_details())
	empty.visible=selector.item_count==0
	refresh_details()
func candidate() -> Dictionary:
	if tabs.current_tab==2:return {}
	if tabs.current_tab==0:return vessel.get("modules",{}).get(selected(owned),{})
	return {"id":"preview","type":selected(kind),"grade":"standard"} if not selected(kind).is_empty() else {}
func refresh_details() -> void:
	if world.is_empty():return
	var module:=candidate();var cfg:=FrontierVesselRefit.config()
	module_grid.visible=tabs.current_tab!=2;empty.visible=tabs.current_tab!=2 and (owned.item_count==0 if tabs.current_tab==0 else kind.item_count==0)
	var draft:=world.duplicate(true)
	if not module.is_empty():draft.vessel.modules["preview"]=module;draft.vessel.loadout[selected_slot]="preview"
	preview.selected_slot=selected_slot;preview.show_vessel(draft.vessel if ghost.button_pressed and not module.is_empty() else vessel)
	for card in module_grid.get_children():card.selected=int(card.get_meta("index"))==(owned.selected if tabs.current_tab==0 else kind.selected);card.disabled=pending;card.queue_redraw()
	var stats:=FrontierVesselRefit.stats(world);var after:=FrontierVesselRefit.stats(draft)
	summary.value="항해 내성  "+"공동 자금 %d Cr  질량 %.1f/%.1f t  전력 %.1f/%.1f MW"%[int(world.business.get("credits",0)),stats.mass,stats.maximum_mass,stats.power,stats.reactor_power]
	if int(vessel.get("parts",0))>0:summary.value+="  연구 부품 %d"%int(vessel.parts)
	for child in comparison.get_children():comparison.remove_child(child);child.queue_free()
	for row in [["질량","mass","t"],["전력","power","MW"],["항속","stellar_range",""],["접근","speed","배"],["연구","research_speed","배"],["격납고","hangar","칸"]]:
		var text: String="%s  %.2f → %.2f %s"%[row[0],stats[row[1]],after[row[1]],row[2]]
		var line:=label(comparison,text,13);line.custom_minimum_size.x=185;line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.autowrap_mode=TextServer.AUTOWRAP_OFF;line.modulate=FrontierInterfaceStyle.ACCENT if stats[row[1]]!=after[row[1]] else FrontierInterfaceStyle.MUTED
	details.value=""
	if tabs.current_tab==2:
		for child in comparison.get_children():comparison.remove_child(child);child.queue_free()
		var readout:=VBoxContainer.new();comparison.add_child(readout)
		var next:=FrontierVesselAccess.next_refit(vessel)
		FrontierVesselCapabilityReadout.populate(readout,stats.navigation_capabilities,next)
		if next<=5:
			var refit: Dictionary=FrontierVesselAccess.config().refits[str(next)]
			details.value="%s\n%d Cr  %s\n현재 선체에 영구 적용 · 임무 모듈 슬롯 유지\n정거장 부품 포함 개장: %d Cr"%[refit.name,refit.field_credits,FrontierCatalog.cost_text(refit.materials),refit.station_credits]
		else:details.value="최고 항해 내성을 갖추었습니다. 선체 역할과 임무 모듈을 자유롭게 선택하세요."
	if not module.is_empty():
		var def:=FrontierVesselRefit.definition(module.type)
		details.value=def.name+"  "+["표준","개량","희귀"][FrontierVesselRefit.grade_index(module.grade)]+"\n"+def.description
		if tabs.current_tab==1:details.value+="\n제작 %d Cr  %s\n추첨 %d Cr  %s"%[cfg.build_credits,FrontierCatalog.cost_text(cfg.build_materials),cfg.draw_credits,FrontierCatalog.cost_text(cfg.draw_materials)]
		else:
			var grade:=FrontierVesselRefit.grade_index(module.grade)
			if grade<2:details.value+="\n개량 %d Cr  %s"%[cfg.upgrade_credits[grade],FrontierCatalog.cost_text(FrontierProductionTier2.config().vessel_upgrade_cost if grade==0 else cfg.upgrade_materials)]
			if grade==1:details.value+="  연구 부품 %d  생물공학 인증"%int(cfg.upgrade_parts[grade])
		var constraint:=FrontierVesselRefit.constraints(draft)
		if not constraint.is_empty():details.value+="\n"+constraint
	for action in action_map:
		var button: Button=action_map[action]
		button.visible=(tabs.current_tab==2) if action=="vessel_navigation_refit" else (tabs.current_tab!=2 and (action in ["vessel_build","vessel_draw"])==(tabs.current_tab==1))
		var reason: String="현장 장부를 확인하세요." if not world.business.has("credits") else "모듈을 선택하세요." if module.is_empty() and action!="vessel_navigation_refit" else FrontierVesselRefit.apply(world.duplicate(true),str(snapshot.self_id),action,arguments())
		button.disabled=pending or not reason.is_empty();button.tooltip_text=reason
	ghost.disabled=module.is_empty()
func arguments() -> Dictionary:return {"tier":FrontierVesselAccess.next_refit(vessel),"module_type":selected(kind),"module_id":selected(owned),"slot":selected_slot}
func send(action: String) -> void:
	if pending:return
	var args:=arguments()
	if action in ["vessel_draw","vessel_salvage"]:
		var dialog:=FrontierGameModal.new();add_child(dialog)
		var drawing:=action=="vessel_draw"
		dialog.configure("모듈 추첨" if drawing else "모듈 분해","비용 지불하고 추첨" if drawing else "분해하고 부품 받기","원정선  /  모듈 정비","ship",true)
		var cfg:=FrontierVesselRefit.config()
		if drawing:
			var costs:=dialog.section("지불할 비용")
			dialog.metric(costs,FrontierVesselRefit.definition(args.module_type).name,FrontierGameModal.number(int(cfg.draw_credits))+" Cr","ship",true)
			dialog.resources(costs,cfg.draw_materials)
			var chances:=dialog.section("등급별 추첨 확률")
			var odds:=HBoxContainer.new();chances.add_child(odds)
			for i in 3:
				var grade:=VBoxContainer.new();grade.size_flags_horizontal=Control.SIZE_EXPAND_FILL;odds.add_child(grade)
				dialog.paragraph(["표준","개량","희귀"][i],FrontierInterfaceStyle.MUTED,grade)
				FrontierInterfaceStyle.label(grade,str(cfg.weights[i])+"%",24)
				var bar:=ProgressBar.new();bar.value=cfg.weights[i];bar.show_percentage=false;bar.custom_minimum_size.y=4;grade.add_child(bar)
			dialog.paragraph("%d회 뒤 선택 종류의 개량 등급 확정"%(int(cfg.pity_interval)-int(vessel.get("draws",0))%int(cfg.pity_interval)),FrontierInterfaceStyle.ACCENT)
			dialog.paragraph("중복 모듈은 연구 부품 %d개로 전환됩니다."%int(cfg.duplicate_parts))
		else:
			var source:=dialog.section("분해할 모듈")
			var definition:=FrontierVesselRefit.definition(vessel.modules[args.module_id].type)
			dialog.item_card(source,load("res://assets/ui/previews/vessel_"+str(definition.model).get_file()+".png"),definition.name,{"standard":"표준","improved":"개량","rare":"희귀"}[vessel.modules[args.module_id].grade])
			dialog.paragraph("분해하면 이 모듈이 사라집니다.",FrontierInterfaceStyle.WARNING,source)
			var output:=dialog.section("돌려받는 재료")
			dialog.metric(output,"연구 부품",str(int(cfg.salvage_parts[FrontierVesselRefit.grade_index(vessel.modules[args.module_id].grade)]))+"개","build",true)
		dialog.confirmed.connect(func():submit(action,args);dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.present(Vector2i(720,620));return
	submit(action,args)
func submit(action: String,args: Dictionary) -> void:
	if pending:return
	pending=true;pending_sequence=-1;outcome.text="정비 승인 중…";refresh_details();command.emit(action,args)
func response(sequence: int,result: Dictionary) -> void:
	if not pending or sequence!=pending_sequence:return
	pending=false;outcome.text="정비 완료" if result.get("ok",false) else str(result.get("error","정비 실패"));last_inventory=""
	refresh_details()
