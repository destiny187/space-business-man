class_name FrontierEcologyJournal
extends PanelContainer
var app: FrontierPlanetExploration
var summary: Label
var discoveries: OptionButton
var detail: RichTextLabel
var cargo: OptionButton
var lab: FrontierResourceReadout
var form_ids: Array[String]=[]
var sample_ids: Array[String]=[]
var refresh_timer:=0.0

func configure(owner_app: FrontierPlanetExploration) -> void:
	app=owner_app
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left=-506;offset_right=-24;offset_top=24;offset_bottom=-24
	custom_minimum_size=Vector2(482,570)
	var panel_style:=StyleBoxFlat.new();panel_style.bg_color=Color("13232bf5");panel_style.border_color=Color("8cb8a6");panel_style.set_border_width_all(2);panel_style.set_content_margin_all(20)
	add_theme_stylebox_override("panel",panel_style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",10);scroll.add_child(column)
	var title:=Label.new();title.text="생태 탐사 기록";title.add_theme_font_size_override("font_size",24);column.add_child(title)
	summary=Label.new();summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(summary)
	discoveries=OptionButton.new();discoveries.add_theme_constant_override("icon_max_width",24);discoveries.custom_minimum_size.y=38;discoveries.fit_to_longest_item=false;column.add_child(discoveries)
	discoveries.item_selected.connect(func(_index: int):update_detail())
	detail=RichTextLabel.new();detail.bbcode_enabled=false;detail.custom_minimum_size=Vector2(420,125);detail.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(detail)
	var analyze_button:=Button.new();analyze_button.text="우주선에서 기초 분석  창고 광물 3";analyze_button.pressed.connect(func():app.ecology_action("analyze",selected_form());refresh());column.add_child(analyze_button);FrontierResourceIcons.button_caption(analyze_button)
	var plot_button:=Button.new();plot_button.text="현재 위치에 시험 구획 설치  창고 광물 6";plot_button.pressed.connect(func():
		var form:=FrontierEcologyCatalog.form(selected_form())
		if not form.is_empty():app.ecology_action("restore",form.environment);refresh())
	column.add_child(plot_button);FrontierResourceIcons.button_caption(plot_button)
	var cargo_title:=Label.new();cargo_title.text="보관한 생체 표본";column.add_child(cargo_title)
	cargo=OptionButton.new();cargo.add_theme_constant_override("icon_max_width",24);cargo.fit_to_longest_item=false;cargo.custom_minimum_size.y=38;column.add_child(cargo)
	var transplant:=Button.new();transplant.text="선택한 표본을 현재 시험 구획에 이식";transplant.pressed.connect(func():
		if cargo.selected>=0 and cargo.selected<sample_ids.size():app.ecology_action("introduce",sample_ids[cargo.selected]);refresh())
	column.add_child(transplant)
	var refill:=Button.new();refill.text="지원 팩 보충  창고 광물 3";refill.pressed.connect(func():app.ecology_action("resupply");refresh());column.add_child(refill);FrontierResourceIcons.button_caption(refill)
	lab=FrontierResourceReadout.new();lab.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lab.add_theme_color_override("default_color",Color("a6c4be"));column.add_child(lab)
	var close:=Button.new();close.text="현장으로  J";close.pressed.connect(func():app.toggle_journal());column.add_child(close)
	hide()

func selected_form() -> String:
	return form_ids[discoveries.selected] if discoveries.selected>=0 and discoveries.selected<form_ids.size() else ""

func refresh() -> void:
	var selected:=selected_form()
	var selected_sample: String=sample_ids[cargo.selected] if cargo.selected>=0 and cargo.selected<sample_ids.size() else ""
	var ecology: Dictionary=app.state.ecology
	var record: Dictionary=ecology.planets[app.body_id]
	var p: Dictionary=record.profile
	summary.text="%s  %s\n기준 온도 %.1f°C  압력 %.0f kPa  기질 수분 %.0f%%"%[app.body.name,{"sterile":"고유 생명 신호 없음","dormant":"휴면 생명 계통","established":"고유 생태계"}[p.origin],p.temperature,p.pressure,p.moisture*100]
	form_ids.clear();discoveries.clear()
	for row in ecology.observations.values():
		if row.form_id not in form_ids:form_ids.append(row.form_id)
	form_ids.sort()
	for id in form_ids:
		var form:=FrontierEcologyCatalog.form(id)
		discoveries.add_icon_item(FrontierResourceIcons.menu_texture(FrontierResourceIcons.specimen_id(form)),form.name)
	if form_ids.is_empty():discoveries.add_item("생명체를 조준하고 E를 길게 눌러 스캔하세요.")
	elif selected in form_ids:discoveries.select(form_ids.find(selected))
	update_detail()
	sample_ids.clear();cargo.clear()
	for id in ecology.specimens:
		if ecology.specimens[id].state=="cargo":sample_ids.append(id)
	sample_ids.sort()
	for id in sample_ids:
		var row: Dictionary=ecology.specimens[id]
		cargo.add_icon_item(FrontierResourceIcons.menu_texture(FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(row.form_id))),"%s  %s"%[FrontierEcologyCatalog.form(row.form_id).name,FrontierUniverse.body_from_id(app.state.manifest,row.source_body).name])
	if sample_ids.is_empty():cargo.add_item("표본 없음  스캔 후 4m 이내에서 Q")
	elif selected_sample in sample_ids:cargo.select(sample_ids.find(selected_sample))
	lab.value="화물 %d / %d  창고 광물 %d\n기초 분석과 시험 구획은 우주선 24m 이내에서 이용합니다."%[sample_ids.size(),int(FrontierEcologyCatalog.config().cargo_capacity),int(app.logistics.depot_rock)]
	if not record.plot.is_empty():lab.value+="\n시험 구획 생물량 %.1f / 100  지원 잔여 %.0f분"%[record.plot.biomass,record.plot.support_remaining/60]

func update_detail() -> void:
	var form:=FrontierEcologyCatalog.form(selected_form())
	if form.is_empty():detail.text="육안 관측 → 스캔 → 기초 분석 → 생체 표본 운송 → 관리 구획 이식\n\n스캔 기록에는 실물 표본이 포함되지 않습니다.";return
	var habitat: Dictionary=FrontierEcologyCatalog.config().habitats[form.environment]
	detail.text="%s  %s\n온도 %.0f–%.0f°C / 압력 %.0f–%.0f kPa\n%s\n연구: %s%s\n외계 생리와 범위는 게임 설정입니다."%[form.family_name,form.environment_label,habitat.temperature[0],habitat.temperature[1],habitat.pressure[0],habitat.pressure[1],form.habitat_note,habitat.principle,"  분석 완료" if app.state.ecology.research.has(form.environment) else "  미분석"]

func _process(delta: float) -> void:
	if not visible:return
	refresh_timer-=delta
	if refresh_timer<=0 and not discoveries.get_popup().visible and not cargo.get_popup().visible:refresh_timer=1.0;refresh()
