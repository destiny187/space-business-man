class_name FrontierEquipmentPanel
extends PanelContainer
var app: FrontierCrewExpedition
var tabs: TabContainer
var stock: FrontierResourceReadout
var owned: VBoxContainer
var recipes: VBoxContainer
var slot_choice: OptionButton
var hotbar: HBoxContainer
var hotbuttons: Array[Button]=[]
var hotlabels: Array[Label]=[]
var hoticons: Array[TextureRect]=[]
var last_key: String=""
func configure(owner_app: FrontierCrewExpedition,parent: Node) -> void:
	app=owner_app;theme=app.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=24;offset_right=-24;offset_top=112;offset_bottom=-170
	var style:=StyleBoxFlat.new();style.bg_color=Color("12252cf5");style.border_color=Color("68c6bb");style.set_border_width_all(2);style.set_content_margin_all(14);add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();add_child(column)
	var heading:=HBoxContainer.new();column.add_child(heading)
	var title:=Label.new();title.text="아이템 · 제작 · 장착";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
	var close:=Button.new();close.text="닫기 [I / Esc]";close.pressed.connect(hide);heading.add_child(close)
	stock=FrontierResourceReadout.new();stock.custom_minimum_size.y=64;column.add_child(stock)
	slot_choice=OptionButton.new();column.add_child(slot_choice)
	for i in int(FrontierEquipment.config().slots):slot_choice.add_item("%d번 슬롯에 장착"%(i+1))
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(tabs)
	owned=_page("소유 장비");recipes=_page("제작 설계도")
	hotbar=HBoxContainer.new();parent.add_child(hotbar);hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);hotbar.add_theme_constant_override("separation",6)
	for i in int(FrontierEquipment.config().slots):
		var button:=Button.new();button.custom_minimum_size=Vector2(134,68);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",44);button.pressed.connect(func():app.session.send_request("equipment_select",{"slot":i}));hotbar.add_child(button);hotbuttons.append(button)
		button.focus_mode=Control.FOCUS_NONE
		var face:=HBoxContainer.new();face.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(face);face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);face.offset_left=6;face.offset_right=-6
		var picture:=TextureRect.new();picture.custom_minimum_size=Vector2(40,48);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;face.add_child(picture);hoticons.append(picture)
		var label:=Label.new();label.add_theme_font_size_override("font_size",12);label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;face.add_child(label);hotlabels.append(label)
	get_viewport().size_changed.connect(_layout);_layout();hide()
func _layout() -> void:
	var size:=get_viewport().get_visible_rect().size
	hotbar.position=Vector2((size.x-694)/2,size.y-142)
func _page(label: String) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=label;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column);return column
func _process(_delta: float) -> void:
	hotbar.visible=app.session.active and app.surface_world!=null and app.session.latest.get("phase")=="playing"
	if not hotbar.visible:hide();return
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	var data:=FrontierEquipment.state(member)
	var ledger: Dictionary=app.session.surface.get("business",{})
	var key:=JSON.stringify([data,ledger.get("bags",{}),ledger.get("credits",0),ledger.get("sites",{}).get(app.surface_world.body.id,{}).get("inventory",{}),member.carried])
	if key==last_key:return
	last_key=key
	var bag: Dictionary=ledger.get("bags",{}).get(app.session.latest.self_id,FrontierExpeditionBusiness.inventory())
	stock.value="공동 크레딧 %d  ·  배낭 %d/%d  ·  굴착 암석 %d  ·  조립 키트 %d\n철 %d   구리 %d   암석 %d   얼음 %d   결정 %d"%[int(ledger.get("credits",FrontierExpeditionBusiness.config().starting_credits)),FrontierExpeditionBusiness.total(bag),int(FrontierExpeditionBusiness.config().bag_capacity),int(member.carried),int(data.kit),int(bag.iron),int(bag.copper),int(bag.stone),int(bag.ice),int(bag.crystal)]
	var depot: Dictionary=ledger.get("sites",{}).get(app.surface_world.body.id,{}).get("inventory",FrontierExpeditionBusiness.inventory())
	stock.value+="\n현장 공동 창고: 철 %d · 구리 %d · 암석 %d · 얼음 %d · 결정 %d"%[int(depot.iron),int(depot.copper),int(depot.stone),int(depot.ice),int(depot.crystal)]
	for i in data.slots.size():
		var def: Dictionary=FrontierEquipment.config().items.get(data.items.get(data.slots[i],""),{})
		hotlabels[i].text="%d  %s\n%s"%[i+1,"●" if i==int(data.selected) else "",def.get("name","빈 슬롯")]
		hoticons[i].texture=load("res://assets/ui/previews/"+def.preview+".png") if not def.is_empty() else null
		hotbuttons[i].modulate=Color("8cf0d2") if i==int(data.selected) else Color.WHITE
	for page in [owned,recipes]:
		for child in page.get_children():page.remove_child(child);child.queue_free()
	for id in data.items:
		var def: Dictionary=FrontierEquipment.config().items[data.items[id]]
		_card(owned,def,"장착",func():app.session.send_request("equipment_equip",{"item_id":id,"slot":slot_choice.selected}),false)
	var remove:=Button.new();remove.text="선택한 슬롯 비우기";remove.pressed.connect(func():app.session.send_request("equipment_equip",{"item_id":"","slot":slot_choice.selected}));owned.add_child(remove)
	var note:=Label.new();note.text="E 유지: 탐험복 내장 스캐너 · Q: 표본 채집\n제작 장비는 내 소유로 이 호스트 세계에 보관됩니다.\n채집물은 세계 화물입니다. F로 현장 창고에 반납합니다.";owned.add_child(note)
	for id in FrontierEquipment.config().items:
		var def: Dictionary=FrontierEquipment.config().items[id]
		var missing: bool=int(data.kit)<=0 if id=="miner_1" else not FrontierExpeditionBusiness.affordable(bag,def.cost)
		_card(recipes,def,"제작",func():app.session.send_request("equipment_craft",{"definition":id}),missing)
func _card(parent: Node,def: Dictionary,caption: String,action: Callable,disabled: bool) -> void:
	var row:=HBoxContainer.new();row.custom_minimum_size.y=94;parent.add_child(row)
	var preview:=TextureRect.new();preview.custom_minimum_size=Vector2(110,90);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;preview.texture=load("res://assets/ui/previews/"+def.preview+".png");row.add_child(preview)
	var description:=Label.new();description.size_flags_horizontal=Control.SIZE_EXPAND_FILL;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.text=def.name+"  ·  %d등급"%int(def.tier)
	description.text+="\n"+({"miner":"채광 %.2f초 / %d개 · 광물 요구 등급 확인"%[float(def.interval),int(def.amount)],"pulse":"동물 타격 피해 %d · 아군 피해 없음"%int(def.damage),"terrain":"굴착 반경 %.1fm · 광맥 채광 별도"%float(def.radius)}[def.kind])
	var costs: PackedStringArray=[]
	for resource in def.cost:costs.append(FrontierCatalog.entry("resources",resource).name+" "+str(int(def.cost[resource])))
	description.text+="\n재료: "+("기초 조립 키트 1" if def.cost.is_empty() else " · ".join(costs));row.add_child(description)
	var button:=Button.new();button.text=caption if not disabled else "재료 부족";button.disabled=disabled;button.pressed.connect(action);row.add_child(button)
