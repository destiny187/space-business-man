extends PanelContainer
## Field findings and optional equipment enhancements; basic recipes need no purchase.
var app: FrontierCrewExpedition
var tabs: TabContainer
var ecology: HBoxContainer
var access: Label
var expedition: FrontierExpeditionResearchPanel
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);offset_left=24;offset_right=-24;offset_top=24;offset_bottom=-80
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	var heading:=FrontierInterfaceStyle.label(header,"탐사 기록",25);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=Button.new();close.text="닫기 · J / Esc";header.add_child(close);close.pressed.connect(hide)
	access=FrontierInterfaceStyle.label(column,"",13,FrontierInterfaceStyle.MUTED)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	expedition=FrontierExpeditionResearchPanel.new();tabs.add_child(expedition);expedition.configure(app,"journal")
	ecology=HBoxContainer.new();ecology.name="생태 조사 · 분석";tabs.add_child(ecology)
	var efficiency:=FrontierProgressionResearchPanel.new();tabs.add_child(efficiency);efficiency.configure(app)
	var logistics:=FrontierRoverWorkshop.new();tabs.add_child(logistics);logistics.configure(app)
	hide()
func _process(_delta: float) -> void:
	if visible:refresh()
func refresh() -> void:
	if app.session.latest.is_empty():return
	var landed: bool=not app.session.latest.crew.get("landing",{}).is_empty()
	for i in range(1,tabs.get_tab_count()):tabs.set_tab_hidden(i,not landed)
	if not landed:
		tabs.current_tab=0;access.text="원정대 공동 기록 · 열람";return
	if app.session.surface.is_empty():return
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	var near:=FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	access.text="착륙선 연구실 연결됨" if near else "현장 기록 열람 · 분석은 착륙선에서"
	for control in app.research_actions:
		if control is Button:
			var options: OptionButton=app.sample_options if control==app.research_actions[2] else app.form_options
			control.disabled=not near or (control!=app.research_actions[3] and (options.selected<0 or str(options.get_item_metadata(options.selected)).is_empty()))
