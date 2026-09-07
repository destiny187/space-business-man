class_name FrontierEquipmentPanel
extends PanelContainer
var app: FrontierCrewExpedition
var tabs: TabContainer
var hotbar: HBoxContainer
var hotbuttons: Array[FrontierItemTile]=[]
var owned: GridContainer
var upgrade_action: Button
var suit_action: Button
var withdraw_count: SpinBox
var recipes: GridContainer
var cargo: GridContainer
var preview: FrontierEquipmentPreview
var left: VBoxContainer
var detail: VBoxContainer
var title: Label
var category: Label
var message: Label
var stats: VBoxContainer
var materials: HBoxContainer
var action: Button
var credit: Label
var capacity: ProgressBar
var capacity_text: Label
var storage: OptionButton
var selected_item: String=""
var selected_definition: String="miner_1"
var selected_resource: String=""
var last_key: String=""
var data: Dictionary={}
var bag: Dictionary={}
var depot: Dictionary={}
var tiles: Array[FrontierItemTile]=[]
var response_left:=0.0
func configure(owner_app: FrontierCrewExpedition,parent: Node) -> void:
	app=owner_app;theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);offset_left=24;offset_right=-24;offset_top=24;offset_bottom=-108
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var heading:=HBoxContainer.new();column.add_child(heading)
	var heading_text:=FrontierInterfaceStyle.label(heading,"현장 장비",12,FrontierInterfaceStyle.MUTED);heading_text.text="L O C U S   /   현장 장비";heading_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(FrontierResourceIcons.view("credits",24));credit=FrontierInterfaceStyle.label(heading,"0",18)
	var shared:=FrontierInterfaceStyle.label(heading,"공동 자금",12,FrontierInterfaceStyle.MUTED);shared.tooltip_text="호스트 세계의 공동 사업 자금"
	var close:=Button.new();close.text="돌아가기  I / Esc";close.pressed.connect(hide);heading.add_child(close)
	var line:=HSeparator.new();column.add_child(line)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",24);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	left=VBoxContainer.new();body.add_child(left)
	category=FrontierInterfaceStyle.label(left,"PERSONAL EQUIPMENT",11,FrontierInterfaceStyle.ACCENT)
	title=FrontierInterfaceStyle.label(left,"자원채집기",25);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview=FrontierEquipmentPreview.new();preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;preview.custom_minimum_size.y=150;left.add_child(preview)
	FrontierInterfaceStyle.label(left,"마우스로 회전",11,FrontierInterfaceStyle.MUTED)
	var middle:=VBoxContainer.new();middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(middle)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(tabs)
	owned=_grid("장비");recipes=_grid("제작");cargo=_grid("화물")
	tabs.tab_changed.connect(func(index: int):
		selected_resource="";selected_item=""
		if index==0 and not data.get("items",{}).is_empty():selected_item=data.items.keys()[0];selected_definition=data.items[selected_item]
		if index==1:selected_definition="miner_1"
		storage.visible=index==2;_refresh_details();_highlight())
	storage=OptionButton.new();storage.add_item("내 배낭 · 운반 중");storage.add_item("현장 창고 · 공동");storage.item_selected.connect(func(_i: int):last_key="");middle.add_child(storage);storage.hide()
	var load_row:=HBoxContainer.new();middle.add_child(load_row);load_row.add_child(FrontierResourceIcons.view("stone",20));capacity_text=FrontierInterfaceStyle.label(load_row,"배낭",12,FrontierInterfaceStyle.MUTED)
	capacity=ProgressBar.new();capacity.custom_minimum_size.y=4;capacity.show_percentage=false;middle.add_child(capacity)
	detail=VBoxContainer.new();detail.add_theme_constant_override("separation",8);body.add_child(detail)
	FrontierInterfaceStyle.label(detail,"장비 정보",12,FrontierInterfaceStyle.MUTED)
	stats=VBoxContainer.new();stats.add_theme_constant_override("separation",8);detail.add_child(stats)
	var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail.add_child(spacer)
	materials=HBoxContainer.new();materials.add_theme_constant_override("separation",8);detail.add_child(materials)
	message=FrontierInterfaceStyle.label(detail,"",12,FrontierInterfaceStyle.MUTED);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=28
	action=Button.new();action.custom_minimum_size.y=44;action.pressed.connect(_action);detail.add_child(action)
	upgrade_action=Button.new();upgrade_action.text="선택 장비 Mk.2 개조";upgrade_action.pressed.connect(func():app.session.send_request("equipment_upgrade",{"item_id":selected_item}));detail.add_child(upgrade_action)
	suit_action=Button.new();suit_action.text="탐험복 Mk.2 개조";suit_action.tooltip_text="보강 프레임 1 + 열전달 유닛 1 · 달리기 소모 −20%, 낙하 피해 −25%";suit_action.icon=FrontierResourceIcons.menu_texture("reinforced_frame");suit_action.pressed.connect(func():app.session.send_request("equipment_suit_upgrade",{}));detail.add_child(suit_action)
	withdraw_count=SpinBox.new();withdraw_count.min_value=1;withdraw_count.max_value=96;withdraw_count.value=1;withdraw_count.prefix="인수";detail.add_child(withdraw_count)
	var footer:=HBoxContainer.new();column.add_child(footer)
	FrontierInterfaceStyle.label(footer,"장비 선택 → 아래 번호 슬롯 클릭  ·  끌어놓기 가능",12,FrontierInterfaceStyle.MUTED)
	var info:=FrontierInterfaceStyle.label(footer,"E  내장 스캐너",12,FrontierInterfaceStyle.ACCENT);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hotbar=HBoxContainer.new();hotbar.theme=theme;hotbar.add_theme_constant_override("separation",6);parent.add_child(hotbar)
	for i in int(FrontierEquipment.config().slots):
		var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(72,72);tile.slot=i;tile.pressed.connect(func():_slot(i));tile.item_dropped.connect(func(id: String):_equip(id,i));hotbar.add_child(tile);hotbuttons.append(tile)
	get_viewport().size_changed.connect(_layout);visibility_changed.connect(_visibility);app.session.response_received.connect(_response);_layout();hide()
func _grid(caption: String) -> GridContainer:
	var scroll:=ScrollContainer.new();scroll.name=caption;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid);return grid
func _layout() -> void:
	var size:=get_viewport().get_visible_rect().size
	left.custom_minimum_size.x=clampf(size.x*.24,190,320);detail.custom_minimum_size.x=clampf(size.x*.21,205,280)
	var width: float=size.x-48-48-left.custom_minimum_size.x-detail.custom_minimum_size.x-48-24
	for grid in [owned,recipes,cargo]:grid.columns=maxi(2,int(width/94))
	hotbar.position=Vector2((size.x-384)/2,size.y-88)
func _visibility() -> void:
	if visible:
		last_key="";modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,.14)
		if selected_item.is_empty() and data.get("items",{}).is_empty():tabs.current_tab=1
		get_viewport().gui_release_focus()
func _response(_sequence: int,value: Dictionary) -> void:
	if not visible:return
	message.text="완료" if value.get("ok",false) else str(value.get("error","실행할 수 없습니다."))
	if value.get("ok",false):message.text="완료";message.modulate=FrontierInterfaceStyle.ACCENT
	else:message.modulate=FrontierInterfaceStyle.WARNING
	response_left=2;last_key=""
func _process(delta: float) -> void:
	response_left=maxf(0,response_left-delta)
	var active: bool=app.session.active and app.surface_world!=null and app.session.latest.get("phase","playing")=="playing"
	hotbar.visible=active and (visible or not app.feedback.blocked())
	if not active:hide();return
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	data=FrontierEquipment.state(member)
	var ledger: Dictionary=app.session.surface.get("business",{})
	bag=ledger.get("bags",{}).get(app.session.latest.self_id,FrontierExpeditionBusiness.inventory())
	depot=ledger.get("sites",{}).get(app.surface_world.body.id,{}).get("inventory",FrontierExpeditionBusiness.inventory())
	var key:=JSON.stringify([data,bag,depot,ledger.get("credits",0),member.carried,storage.selected])
	if key==last_key:return
	last_key=key
	credit.text="%s"%int(ledger.get("credits",FrontierExpeditionBusiness.config().starting_credits))
	capacity.max_value=int(FrontierExpeditionBusiness.config().bag_capacity);capacity.value=FrontierExpeditionBusiness.total(bag);capacity_text.text="내 배낭   %d / %d   ·   굴착 암석 %d"%[int(capacity.value),int(capacity.max_value),int(member.carried)]
	for i in data.slots.size():
		var def: Dictionary=FrontierEquipment.config().items.get(data.items.get(data.slots[i],""),{})
		var tile:=hotbuttons[i];tile.picture=null if def.is_empty() else FrontierInterfaceStyle.icon(def.model);tile.grade=int(def.get("tier",0));tile.selected=i==int(data.selected);tile.caption="";tile.tooltip_text=str(i+1)+" · "+str(def.get("name","빈 슬롯"));tile.queue_redraw()
	for grid in [owned,recipes,cargo]:
		for child in grid.get_children():grid.remove_child(child);child.queue_free()
	tiles.clear()
	for id in data.items:_tile(owned,id,data.items[id])
	for id in FrontierEquipment.config().items:
		if FrontierEquipment.config().items[id].get("craftable",true):_tile(recipes,"",id)
	for i in maxi(0,12-data.items.size()):
		var empty:=FrontierItemTile.new();empty.disabled=true;empty.tooltip_text="빈 보관 공간";owned.add_child(empty)
	var source: Dictionary=bag if storage.selected==0 else depot
	for id in source:
		var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(id);tile.amount=str(int(source[id]));tile.tooltip_text=FrontierCatalog.entry("resources",id).name;tile.pressed.connect(func():selected_resource=id;selected_item="";_refresh_details());cargo.add_child(tile)
	if selected_item!="" and not data.items.has(selected_item):selected_item=""
	if tabs.current_tab==0 and not data.items.is_empty():
		if selected_item.is_empty():selected_item=data.slots[int(data.selected)] if data.slots[int(data.selected)]!="" else data.items.keys()[0]
		selected_definition=data.items[selected_item]
	_refresh_details();_highlight()
func _tile(parent: Node,id: String,definition: String) -> void:
	var def: Dictionary=FrontierEquipment.config().items[definition]
	var tile:=FrontierItemTile.new();tile.item_id=id;tile.set_meta("definition",definition);tile.picture=FrontierInterfaceStyle.icon(def.model);tile.grade=int(def.tier);tile.caption="Mk. %d"%int(def.tier);tile.tooltip_text=def.name
	if parent==recipes:
		tile.unavailable=int(data.kit)<=0 if definition=="miner_1" else not FrontierExpeditionBusiness.affordable(bag,def.cost)
		if tile.unavailable:tile.tooltip_text+=" · 재료 부족"
	tile.pressed.connect(func():selected_item=id;selected_definition=definition;selected_resource="";_refresh_details();_highlight())
	parent.add_child(tile);tiles.append(tile)
func _highlight() -> void:
	for tile in tiles:tile.selected=(tile.item_id==selected_item if tabs.current_tab==0 and selected_item!="" else tile.get_meta("definition")==selected_definition and tabs.current_tab==1);tile.queue_redraw()
func _clear(parent: Node) -> void:
	for child in parent.get_children():parent.remove_child(child);child.queue_free()
func _metric(label: String,value: String,ratio: float,color: Color=FrontierInterfaceStyle.ACCENT) -> void:
	var row:=HBoxContainer.new();stats.add_child(row)
	var name_label:=FrontierInterfaceStyle.label(row,label,12,FrontierInterfaceStyle.MUTED);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	FrontierInterfaceStyle.label(row,value,18,color)
	var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size.y=4;bar.value=clampf(ratio,0,1)*100;stats.add_child(bar)
func _refresh_details() -> void:
	if data.is_empty():return
	_clear(stats);_clear(materials)
	upgrade_action.hide();withdraw_count.visible=tabs.current_tab==2 and storage.selected==1
	suit_action.visible=tabs.current_tab==0
	suit_action.disabled=int(data.get("suit_tier",1))>=2 or not FrontierExpeditionBusiness.affordable(bag,FrontierProductionTier2.config().suit_upgrade.cost)
	suit_action.text="탐험복 Mk.2 완료" if int(data.get("suit_tier",1))>=2 else "탐험복 Mk.2 개조"
	if tabs.current_tab==2:
		if selected_resource.is_empty():selected_resource="iron"
		var resource:=FrontierCatalog.entry("resources",selected_resource)
		title.text=resource.name;category.text="CARGO / "+("내 배낭" if storage.selected==0 else "공동 창고")
		var product:=FrontierProductionTier2.product(selected_resource)
		preview.show_model(product.model if not product.is_empty() else "ore_"+selected_resource)
		_metric("보유 수량",str(int((bag if storage.selected==0 else depot).get(selected_resource,0))),float((bag if storage.selected==0 else depot).get(selected_resource,0))/96)
		if not product.is_empty():FrontierInterfaceStyle.label(stats,product.use,12)
		else:_metric("채집기 요구 등급",str(int(FrontierMineralWorld.tier(selected_resource))),float(FrontierMineralWorld.tier(selected_resource))/3)
		action.text="공동 창고에서 인수" if storage.selected==1 else "현장 창고에 반납";action.disabled=int(depot.get(selected_resource,0))<=0 if storage.selected==1 else FrontierExpeditionBusiness.total(bag)==0
		if response_left<=0:message.text="현장 창고 근처에서 선택 수량을 인수합니다." if storage.selected==1 else "현장 창고 근처에서 반납할 수 있습니다.";message.modulate=Color.WHITE
		return
	var def: Dictionary=FrontierEquipment.config().items[selected_definition]
	title.text=def.name;category.text={"miner":"EXTRACTION / 자원 채집","pulse":"DEFENCE / 공격 장비","terrain":"TERRAIN / 지형 변환"}[def.kind]
	preview.show_model(def.model)
	_metric("장비 등급","%s"%["I","II","III"][int(def.tier)-1],float(def.tier)/3,FrontierInterfaceStyle.WARNING)
	if def.kind=="miner":_metric("채집량","%d개"%int(def.amount),float(def.amount)/5);_metric("작업 간격","%.2f초"%float(def.interval),.3/float(def.interval))
	elif def.kind=="pulse":_metric("타격 피해",str(int(def.damage)),float(def.damage)/40)
	else:_metric("굴착 반경","%.1fm"%float(def.radius),float(def.radius)/1.7)
	var current:=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
	if not current.is_empty() and current.kind==def.kind and current.tier!=def.tier:
		FrontierInterfaceStyle.label(stats,"장착 장비 대비 등급 %+d"%(int(def.tier)-int(current.tier)),12,FrontierInterfaceStyle.ACCENT)
	if tabs.current_tab==1:
		for id in def.cost:
			var cost:=VBoxContainer.new();materials.add_child(cost);cost.add_child(FrontierResourceIcons.view(id,30));var have:=int(bag.get(id,0));FrontierInterfaceStyle.label(cost,"%d/%d"%[have,int(def.cost[id])],12,FrontierInterfaceStyle.ACCENT if have>=int(def.cost[id]) else FrontierInterfaceStyle.WARNING)
		if def.cost.is_empty():materials.add_child(FrontierResourceIcons.view("research_parts",30));FrontierInterfaceStyle.label(materials,"키트 %d / 1"%int(data.kit),13)
		action.text="제작";action.disabled=int(data.kit)<=0 if selected_definition=="miner_1" else not FrontierExpeditionBusiness.affordable(bag,def.cost)
		if response_left<=0:message.text="재료를 모으면 제작할 수 있습니다." if action.disabled else "내 배낭의 재료를 사용합니다.";message.modulate=Color.WHITE
	else:
		upgrade_action.visible=int(def.tier)==1 and selected_item!=""
		var next: Dictionary=FrontierEquipment.config().items.get(str(def.kind)+"_2",{})
		upgrade_action.disabled=not FrontierExpeditionBusiness.affordable(bag,next.get("cost",{}))
		upgrade_action.tooltip_text=FrontierCatalog.cost_text(next.get("cost",{}))+" · 장비 ID와 슬롯 유지"
		if upgrade_action.visible:
			for resource in next.get("cost",{}):
				var column:=VBoxContainer.new();materials.add_child(column);column.add_child(FrontierResourceIcons.view(resource,28));FrontierInterfaceStyle.label(column,"%d/%d"%[int(bag.get(resource,0)),int(next.cost[resource])],12)
		action.text="현재 슬롯 비우기";action.disabled=data.slots[int(data.selected)]==""
		if response_left<=0:message.text="장비를 선택하고 아래 슬롯에 놓으세요.";message.modulate=Color.WHITE
func _slot(slot: int) -> void:
	if visible and tabs.current_tab==0 and not selected_item.is_empty():_equip(selected_item,slot)
	else:app.session.send_request("equipment_select",{"slot":slot})
func _equip(id: String,slot: int) -> void:
	if visible and data.items.has(id):app.session.send_request("equipment_equip",{"item_id":id,"slot":slot})
func _action() -> void:
	if tabs.current_tab==1:app.session.send_request("equipment_craft",{"definition":selected_definition})
	elif tabs.current_tab==2:
		if storage.selected==1:app.session.send_request("business_withdraw",{"resource":selected_resource,"amount":int(withdraw_count.value)})
		else:app.session.send_request("business_deposit",{})
	else:app.session.send_request("equipment_equip",{"item_id":"","slot":int(data.selected)})
