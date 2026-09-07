extends PanelContainer
## Separate research desk; the host remains authoritative for every purchase/analysis.
var app: FrontierCrewExpedition
var tabs: TabContainer
var ecology: HBoxContainer
var catalog: GridContainer
var preview: FrontierEquipmentPreview
var title: Label
var description: Label
var prerequisite: Label
var action: Button
var funds: Label
var access: Label
var selected: String="robotics"
var cards: Dictionary={}
var signature: String=""
const MODELS={"robotics":"miner","atmosphere":"atmosphere","thermal":"thermal","water":"water","biotech":"biolab","recovery":"storage","analysis":"reactor","combat":"guardian","advanced":"surveyor","ancient":"reactor"}
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);offset_left=24;offset_right=-24;offset_top=24;offset_bottom=-80
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	var heading:=FrontierInterfaceStyle.label(header,"연구",25);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	funds=FrontierInterfaceStyle.label(header,"",14)
	var close:=Button.new();close.text="닫기 · J / Esc";header.add_child(close);close.pressed.connect(hide)
	access=FrontierInterfaceStyle.label(column,"",13,FrontierInterfaceStyle.MUTED)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	var technology:=HBoxContainer.new();technology.name="기술 설계도";tabs.add_child(technology)
	var scroll:=ScrollContainer.new();scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;technology.add_child(scroll)
	catalog=GridContainer.new();catalog.columns=2;catalog.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(catalog)
	for key in FrontierExpeditionBusiness.config().technologies:
		var def:=FrontierCatalog.entry("technologies",key)
		var card:=Button.new();card.custom_minimum_size=Vector2(150,162);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.toggle_mode=true
		var content:=VBoxContainer.new();content.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_top=8
		var picture:=TextureRect.new();picture.texture=load("res://assets/ui/research/"+key+".png");picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size.y=78;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(picture)
		var caption:=FrontierInterfaceStyle.label(content,def.name,14);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var state:=FrontierInterfaceStyle.label(content,"",12);state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		card.pressed.connect(func():selected=key;signature="";refresh());catalog.add_child(card);cards[key]={"button":card,"state":state}
	var detail_column:=VBoxContainer.new();detail_column.custom_minimum_size.x=310;detail_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;technology.add_child(detail_column)
	var detail_scroll:=ScrollContainer.new();detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_column.add_child(detail_scroll)
	var detail:=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(detail)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(280,150);detail.add_child(preview)
	title=FrontierInterfaceStyle.label(detail,"",22)
	prerequisite=FrontierInterfaceStyle.label(detail,"",14,FrontierInterfaceStyle.ACCENT);prerequisite.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description=FrontierInterfaceStyle.label(detail,"",14);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	action=Button.new();action.custom_minimum_size.y=44;detail_column.add_child(action);action.pressed.connect(func():app.session.send_request("business_technology",{"technology":selected}))
	var note:=FrontierInterfaceStyle.label(detail,"설계도는 공동 연구로 영구 유지됩니다.\n장비·시설은 해금 후 재료로 제작하세요.",13,FrontierInterfaceStyle.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	ecology=HBoxContainer.new();ecology.name="생태 조사 · 분석";tabs.add_child(ecology)
	hide()
func _process(_delta: float) -> void:
	if visible:refresh()
func refresh() -> void:
	if app.session.surface.is_empty():return
	var ledger: Dictionary=app.session.surface.get("business",{})
	var owned: Array=ledger.get("technologies",[])
	var actor: String=app.session.latest.self_id
	var member: Dictionary=app.session.latest.crew.members[actor]
	var near: bool=FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	var host: bool=actor==app.session.latest.crew.owner_id
	var key:=str([selected,owned,ledger.get("credits",0),near,host])
	for control in app.research_actions:
		if control is Button:
			var options: OptionButton=app.sample_options if control==app.research_actions[2] else app.form_options
			control.disabled=not near or (control!=app.research_actions[3] and (options.selected<0 or str(options.get_item_metadata(options.selected)).is_empty()))
	if key==signature:return
	signature=key
	access.text="착륙선 연구실 연결됨 · 분석 및 기술 구매 가능" if near else "현장 열람 중 · 분석과 기술 구매는 착륙선 연구실에서"
	funds.text="공동 자금  %d Cr"%int(ledger.get("credits",0))
	for id in cards:
		var row:=FrontierCatalog.entry("technologies",id)
		cards[id].button.set_pressed_no_signal(id==selected)
		cards[id].state.text="✓ 연구 완료" if id in owned else ("선행 연구 필요" if not row.requires.is_empty() and row.requires not in owned else "%d Cr"%int(row.price))
	var def:=FrontierCatalog.entry("technologies",selected)
	preview.show_model(MODELS.get(selected,"miner"));title.text=def.name;description.text=def.description
	prerequisite.text=(FrontierCatalog.entry("technologies",def.requires).name+"  →  ") if not def.requires.is_empty() else "기초 연구  →  "
	prerequisite.text+=def.name
	var reason: String=""
	if selected in owned:reason="연구 완료"
	elif not def.requires.is_empty() and def.requires not in owned:reason="선행 기술을 먼저 연구하세요"
	elif not near:reason="착륙선 연구실에 접근하세요"
	elif not host:reason="공동 기술 구매는 호스트가 진행합니다"
	elif int(ledger.get("credits",0))<int(def.price):reason="공동 크레딧 부족"
	action.disabled=not reason.is_empty();action.text=reason if action.disabled else "설계도 연구 · %d Cr"%int(def.price)
