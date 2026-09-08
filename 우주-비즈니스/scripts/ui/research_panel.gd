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
	ecology=HBoxContainer.new();ecology.name="발견 도감";tabs.add_child(ecology)
	hide()
func _process(_delta: float) -> void:
	if visible:refresh()
func refresh() -> void:
	if app.session.latest.is_empty():return
	if app.session.surface.is_empty() or app.session.latest.crew.get("landing",{}).is_empty():app.surface_panel.hide()
	else:app.surface_panel.refresh(false)
	access.text="원정대 공동 기록 · 분석과 개조는 실제 장치에서"
	if app.session.surface.has("business"):access.text+=" · 공동 생산 +%d%%"%(int(app.session.surface.business.get("efficiency",0))*10)
