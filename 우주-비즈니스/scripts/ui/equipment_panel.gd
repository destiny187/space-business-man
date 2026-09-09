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
var storage_owned: GridContainer
var storage_selection: Dictionary={}
var transfer_button: Button
var transfer_count: SpinBox
var storage_label: Label
var storage_headers: Array[Label]=[]
var storage_bars: Array[ProgressBar]=[]
var storage_pending: Dictionary={}
var bulk_transfer: Button
var storage_site: Dictionary={}
var warehouse_choice: OptionButton
var warehouse_management: Button
func using_ship() -> bool:return app.surface_world==null or warehouse_choice.selected==1
var warehouse_supplements: Array[Control]=[]
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
var dye_panel: FrontierSuitDyePanel
var augmentation_readout: FrontierAugmentationReadout
var response_left:=0.0
var browsers: Dictionary={}
var empty_labels: Dictionary={}
var cargo_browser: FrontierItemBrowser
var detail_scroll: ScrollContainer
var cargo_summary: Label
var quantity_buttons: Array[Button]=[]
var usage_dialog: AcceptDialog
var detail_shell: VBoxContainer
func configure(owner_app: FrontierCrewExpedition,parent: Node) -> void:
	app=owner_app;theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);offset_left=24;offset_right=-24;offset_top=24;offset_bottom=-108
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);add_child(column)
	var heading:=HBoxContainer.new();column.add_child(heading)
	var heading_text:=FrontierInterfaceStyle.label(heading,"아이템",12,FrontierInterfaceStyle.MUTED);heading_text.text="L O C U S   /   아이템";heading_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	heading.add_child(FrontierResourceIcons.view("credits",24));credit=FrontierInterfaceStyle.label(heading,"0",18)
	var shared:=FrontierInterfaceStyle.label(heading,"공동 자금",12,FrontierInterfaceStyle.MUTED);shared.tooltip_text="호스트 세계의 공동 사업 자금"
	var close:=Button.new();close.text="돌아가기  I / Esc";close.pressed.connect(hide);heading.add_child(close)
	var line:=HSeparator.new();column.add_child(line)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",24);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	left=VBoxContainer.new()
	category=FrontierInterfaceStyle.label(left,"PERSONAL EQUIPMENT",11,FrontierInterfaceStyle.ACCENT)
	title=FrontierInterfaceStyle.label(left,"자원채집기",20);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size.y=125;left.add_child(preview)
	FrontierInterfaceStyle.label(left,"마우스로 회전",11,FrontierInterfaceStyle.MUTED)
	var middle:=VBoxContainer.new();middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(middle)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;middle.add_child(tabs)
	owned=_grid("아이템");recipes=_grid("제작")
	var warehouse:=VBoxContainer.new();warehouse.name="화물";warehouse.add_theme_constant_override("separation",6);tabs.add_child(warehouse)
	var warehouse_header:=HBoxContainer.new();warehouse.add_child(warehouse_header)
	warehouse_choice=OptionButton.new();warehouse_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;warehouse_choice.add_item("행성 창고  이 행성에 남음");warehouse_choice.add_item("우주선 창고  함께 운송");warehouse_choice.item_selected.connect(func(_index: int):last_key="";storage_selection={};transfer_button.disabled=true);warehouse_header.add_child(warehouse_choice)
	warehouse_management=Button.new();warehouse_management.text="보급  로봇 관리";warehouse_management.icon=FrontierResourceIcons.menu_texture("reinforced_frame");warehouse_management.pressed.connect(app.open_warehouse_management);warehouse_header.add_child(warehouse_management)
	cargo_browser=FrontierItemBrowser.new();warehouse.add_child(cargo_browser);cargo_browser.changed.connect(_filter_items)
	var selection_row:=HBoxContainer.new();warehouse.add_child(selection_row)
	cargo_summary=FrontierInterfaceStyle.label(selection_row,"선택한 물건 없음",14);cargo_summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cargo_summary.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	storage_label=FrontierInterfaceStyle.label(selection_row,"",12);storage_label.custom_minimum_size.x=170;storage_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;storage_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;storage_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);warehouse.add_child(actions)
	transfer_count=SpinBox.new();transfer_count.min_value=1;transfer_count.max_value=FrontierItemInventory.limit();transfer_count.value=1;actions.add_child(transfer_count)
	transfer_count.get_line_edit().add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.PANEL,FrontierInterfaceStyle.LINE,6))
	transfer_button=Button.new();transfer_button.text="선택 아이템 입출고";transfer_button.disabled=true;actions.add_child(transfer_button)
	transfer_button.pressed.connect(func():
		if storage_selection.is_empty():return
		var payload:=storage_selection.duplicate();payload.amount=int(transfer_count.value);payload.quick=true;_transfer_cargo(payload))
	for preset in ["1","중첩","최대"]:
		var quick:=Button.new();quick.text=preset;quick.tooltip_text="옮길 수량 선택";actions.add_child(quick);quantity_buttons.append(quick)
		quick.pressed.connect(func():transfer_count.value=mini(_transfer_limit(),1 if preset=="1" else int(FrontierItemInventory.config().resource_stack) if preset=="중첩" else _transfer_limit()))
	var bulk:=Button.new();bulk_transfer=bulk;bulk.text="모두 싣기 →";bulk.tooltip_text="장비를 제외한 재료와 표본을 창고의 남은 공간만큼 옮깁니다.";actions.add_child(bulk)
	bulk.pressed.connect(func():app.session.send_request("deposit" if using_ship() else "business_deposit",{"all_resources":true}))
	var pair:=HBoxContainer.new();pair.add_theme_constant_override("separation",24);pair.size_flags_vertical=Control.SIZE_EXPAND_FILL;warehouse.add_child(pair)
	for side in ["내 배낭","공동 창고"]:
		var section:=VBoxContainer.new();section.add_theme_constant_override("separation",6);section.size_flags_horizontal=Control.SIZE_EXPAND_FILL;pair.add_child(section)
		storage_headers.append(FrontierInterfaceStyle.label(section,side,16))
		var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size.y=5;section.add_child(bar);storage_bars.append(bar)
		var scroll:=FrontierCargoDropArea.new();scroll.destination="bag" if side=="내 배낭" else "warehouse";scroll.cargo_dropped.connect(_transfer_cargo);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;section.add_child(scroll)
		var empty:=FrontierInterfaceStyle.label(section,"",12,FrontierInterfaceStyle.MUTED);empty_labels[side]=empty
		var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
		if side=="내 배낭":storage_owned=grid
		else:cargo=grid
	augmentation_readout=FrontierAugmentationReadout.new();tabs.add_child(augmentation_readout);augmentation_readout.configure(app)
	dye_panel=FrontierSuitDyePanel.new();tabs.add_child(dye_panel);dye_panel.configure(app)
	tabs.resized.connect(_layout)
	tabs.tab_changed.connect(func(index: int):
		selected_resource="";selected_item=""
		if index==0 and not data.get("items",{}).is_empty():selected_item=data.items.keys()[0];selected_definition=data.items[selected_item]
		if index==1:selected_definition="miner_1"
		storage.select(1 if index==2 else 0);left.visible=index in [0,1];detail_shell.visible=index in [0,1];last_key=""
		for control in warehouse_supplements:control.visible=index in [0,1]
		_layout();_refresh_details();_highlight())
	storage=OptionButton.new();storage.add_item("내 배낭  운반 중");storage.add_item("현장 창고  공동");storage.item_selected.connect(func(_i: int):last_key="");middle.add_child(storage);storage.hide()
	var load_row:=HBoxContainer.new();warehouse_supplements.append(load_row);middle.add_child(load_row);load_row.add_child(FrontierResourceIcons.view("stone",20));capacity_text=FrontierInterfaceStyle.label(load_row,"배낭",12,FrontierInterfaceStyle.MUTED)
	capacity=ProgressBar.new();warehouse_supplements.append(capacity);capacity.custom_minimum_size.y=4;capacity.show_percentage=false;middle.add_child(capacity)
	detail_shell=VBoxContainer.new();body.add_child(detail_shell)
	detail_scroll=ScrollContainer.new();detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_shell.add_child(detail_scroll)
	detail=VBoxContainer.new();detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail.add_theme_constant_override("separation",8);detail_scroll.add_child(detail);detail.add_child(left)
	FrontierInterfaceStyle.label(detail,"선택 정보",12,FrontierInterfaceStyle.MUTED)
	stats=VBoxContainer.new();stats.add_theme_constant_override("separation",8);detail.add_child(stats)
	var spacer:=Control.new();spacer.custom_minimum_size.y=6;detail.add_child(spacer)
	materials=HBoxContainer.new();materials.add_theme_constant_override("separation",8);detail.add_child(materials)
	message=FrontierInterfaceStyle.label(detail,"",12,FrontierInterfaceStyle.MUTED);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=28
	action=Button.new();action.custom_minimum_size.y=44;action.pressed.connect(_action);detail_shell.add_child(action)
	upgrade_action=Button.new();upgrade_action.text="선택 장비 Mk.2 개조";upgrade_action.pressed.connect(func():app.stations.navigate("augmentation",1));detail_shell.add_child(upgrade_action)
	suit_action=Button.new();suit_action.text="탐험복 Mk.2 개조";suit_action.tooltip_text="보강 프레임 1 + 열전달 유닛 1  달리기 소모 −20%, 낙하 피해 −25%";suit_action.icon=FrontierResourceIcons.menu_texture("reinforced_frame");suit_action.pressed.connect(func():app.stations.navigate("augmentation",1));detail_shell.add_child(suit_action)
	withdraw_count=SpinBox.new();withdraw_count.min_value=1;withdraw_count.max_value=FrontierItemInventory.limit();withdraw_count.value=1;withdraw_count.prefix="인수";detail.add_child(withdraw_count)
	var footer:=HBoxContainer.new();warehouse_supplements.append(footer);column.add_child(footer)
	FrontierInterfaceStyle.label(footer,"장비 선택 → 아래 번호 슬롯 클릭    끌어놓기 가능",12,FrontierInterfaceStyle.MUTED)
	var info:=FrontierInterfaceStyle.label(footer,"E  내장 스캐너",12,FrontierInterfaceStyle.ACCENT);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hotbar=HBoxContainer.new();hotbar.theme=theme;hotbar.add_theme_constant_override("separation",6);parent.add_child(hotbar)
	for i in int(FrontierEquipment.config().slots):
		var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(80,80);tile.compact_slot=true;tile.slot=i;tile.pressed.connect(func():_slot(i));tile.item_dropped.connect(func(id: String):_equip(id,i));hotbar.add_child(tile);hotbuttons.append(tile)
	get_viewport().size_changed.connect(_layout);visibility_changed.connect(_visibility);app.session.response_received.connect(_response);app.session.request_started.connect(_storage_requested);_layout();hide()
func _grid(caption: String) -> GridContainer:
	var page:=VBoxContainer.new();page.name=caption;tabs.add_child(page)
	var browser:=FrontierItemBrowser.new();page.add_child(browser);browsers[caption]=browser;browser.changed.connect(_filter_items)
	if caption=="제작":browser.category.hide();browser.order.hide()
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;page.add_child(scroll)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);scroll.add_child(grid)
	var empty:=FrontierInterfaceStyle.label(page,"",13,FrontierInterfaceStyle.MUTED);empty_labels[caption]=empty
	return grid
func _layout() -> void:
	if detail_scroll==null:return
	var viewport_size:=get_viewport().get_visible_rect().size
	preview.custom_minimum_size.y=72 if viewport_size.y<720 else 125
	for bar in storage_bars:bar.visible=viewport_size.y>=720
	offset_bottom=-108 if tabs.current_tab in [0,1] else -24
	detail_shell.custom_minimum_size.x=250 if viewport_size.x<1100 else 290
	left.custom_minimum_size.x=0;detail.custom_minimum_size.x=0
	var tile_width:=104
	for grid in [owned,recipes,cargo,storage_owned]:
		# Use the intended viewport allocation, not a grid's previous minimum width.
		# Otherwise a wide grid prevents its ScrollContainer from shrinking on resize.
		var width: float=(viewport_size.x-48-36-24-24)/2.0-12 if grid in [cargo,storage_owned] else viewport_size.x-48-36-24-detail_shell.custom_minimum_size.x-24-12
		grid.columns=maxi(1,int(width/float(tile_width+6)))
		for tile in grid.get_children():tile.custom_minimum_size=Vector2(tile_width,100)
	var bar_width:=hotbuttons.size()*80+maxi(0,hotbuttons.size()-1)*6
	hotbar.size=Vector2(bar_width,80)
	hotbar.position=Vector2((viewport_size.x-bar_width)/2,viewport_size.y-92)
	_filter_items()
func _filter_items() -> void:
	for pair in [[owned,"아이템"],[recipes,"제작"],[storage_owned,"내 배낭"],[cargo,"공동 창고"]]:
		var browser: FrontierItemBrowser=browsers.get(pair[1],cargo_browser)
		var count:=browser.apply(pair[0])
		empty_labels[pair[1]].visible=count==0
		empty_labels[pair[1]].text="검색 결과 없음" if browser.filtered() else ("보관한 물건 없음  이 영역에 끌어놓기" if pair[1] in ["내 배낭","공동 창고"] else "보유한 아이템 없음")
func _visibility() -> void:
	if visible:
		last_key="";modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,.14)
		tabs.current_tab=0
		get_viewport().gui_release_focus()
func _response(_sequence: int,value: Dictionary) -> void:
	var cargo_response:=storage_pending.has(_sequence)
	storage_pending.erase(_sequence)
	if not visible or (tabs.current_tab==2 and not cargo_response):return
	message.text="완료" if value.get("ok",false) else str(value.get("error","실행할 수 없습니다."))
	if value.get("ok",false):
		message.text="완료";message.modulate=FrontierInterfaceStyle.ACCENT
	else:message.modulate=FrontierInterfaceStyle.WARNING
	response_left=2;last_key=""
	if tabs.current_tab==2:storage_label.text=message.text;storage_label.modulate=message.modulate
func _process(delta: float) -> void:
	if response_left>0 and response_left<=delta:last_key=""
	response_left=maxf(0,response_left-delta)
	var active: bool=app.session.active and app.session.latest.get("phase","playing")=="playing"
	hotbar.visible=active and (app.rovers==null or app.rovers.seat().is_empty()) and ((visible and tabs.current_tab in [0,1]) or (not visible and app.surface_world!=null and not app.feedback.blocked()))
	if not active:hide();return
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	data=FrontierEquipment.state(member)
	var ledger: Dictionary=app.session.surface.get("business",{})
	bag=app.session.latest.get("inventory",ledger.get("bags",{}).get(app.session.latest.self_id,FrontierExpeditionBusiness.inventory())).duplicate()
	bag.stone=int(bag.get("stone",0))+int(member.carried)
	storage_site=ledger.get("sites",{}).get(app.surface_world.body.id if app.surface_world!=null else "",{})
	depot=storage_site.get("inventory",FrontierExpeditionBusiness.inventory())

	storage.set_item_text(1,"현장 창고  공동" if app.surface_world!=null else "우주선 화물  공동")
	warehouse_choice.disabled=app.surface_world==null
	if app.surface_world==null:warehouse_choice.select(1)
	if using_ship():
		storage_site=FrontierItemInventory.ship_site(app.session.latest.crew);depot=storage_site.inventory
		if not app.session.latest.get("local_shuttle","").is_empty():storage_site["slot_capacity"]=int(FrontierShuttles.config().cargo_slots)
	var personal: bool=not app.session.latest.get("local_shuttle","").is_empty()
	warehouse_choice.set_item_text(1,"FINCH  내 화물" if personal else "원정선  공동 화물")
	if tabs.current_tab==2:
		left.hide();detail_shell.hide()
	bulk_transfer.text="모두 싣기 →" if using_ship() else "모두 보관 →"
	warehouse_management.visible=not using_ship()
	warehouse_management.disabled=using_ship() or storage_site.is_empty() or storage_site.get("state")=="settled" or not FrontierExpeditionBusiness.near_warehouse(storage_site,FrontierCrewWorld.vector(member.position))
	warehouse_management.tooltip_text="현장 창고 9m 이내에서 보급 / 로봇 / 시설을 관리합니다."
	var key:=JSON.stringify([data,bag,depot,storage_site.get("stored_equipment",{}),storage_site.get("buildings",{}).size(),ledger.get("credits",0),member.carried,storage.selected,using_ship(),app.surface_world!=null,personal,storage_pending.size()])
	if key==last_key:return
	last_key=key
	credit.text="%s"%int(ledger.get("credits",FrontierExpeditionBusiness.config().starting_credits))
	var available:=FrontierItemInventory.capacity(member)
	var occupied:=FrontierItemInventory.used(bag,data.items.size())
	capacity.max_value=available;capacity.value=occupied
	capacity_text.text="수납  %d / %d칸%s"%[occupied,available,"  초과 보관" if occupied>available else ""]
	capacity_text.modulate=FrontierInterfaceStyle.WARNING if occupied>available else Color.WHITE
	capacity_text.tooltip_text="자원은 한 칸에 %d개, 장비와 생체 표본은 한 칸에 1개입니다. 번호 슬롯에 장착해도 수납 공간을 사용합니다."%int(FrontierItemInventory.config().resource_stack)
	if occupied>available:capacity_text.tooltip_text+="\n기존 아이템은 보존됩니다. 창고에 반납하여 공간을 확보하세요."
	else:capacity_text.tooltip_text+="\n기본 수납은 %d칸입니다. 성능 개조의 현장 물류로 수납 칸을 늘릴 수 있습니다."%int(FrontierItemInventory.config().slots)
	for i in data.slots.size():
		var def: Dictionary=FrontierEquipment.config().items.get(data.items.get(data.slots[i],""),{})
		var tile:=hotbuttons[i];tile.picture=null if def.is_empty() else FrontierInterfaceStyle.icon(def.model);tile.grade=int(def.get("tier",0));tile.selected=i==int(data.selected);tile.caption="";tile.tooltip_text=str(i+1)+"  "+str(def.get("name","빈 슬롯"));tile.queue_redraw()
	for grid in [owned,recipes,cargo,storage_owned]:
		for child in grid.get_children():grid.remove_child(child);child.queue_free()
	tiles.clear()
	for id in data.items:_tile(owned,id,data.items[id])
	for id in FrontierEquipment.config().items:
		if FrontierEquipment.config().items[id].get("craftable",true):_tile(recipes,"",id)
	for storage_index in 2:
		var source: Dictionary=bag if storage_index==0 else depot
		var grid: GridContainer=owned if storage_index==0 else cargo
		var displayed: Array=[]
		displayed=FrontierItemInventory.stacks(source) if storage_index==0 else []
		for stack in displayed:
			var id: String=stack.resource
			var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(id);tile.amount=str(int(stack.amount));tile.caption=FrontierCatalog.entry("resources",id).name;FrontierItemBrowser.tag(tile,tile.caption,FrontierItemBrowser.kind(id),int(source[id]));tile.tooltip_text=FrontierCatalog.entry("resources",id).name+("  최대 %d개"%FrontierItemInventory.stack_size(id) if storage_index==0 else "  공동 재고 합계")
			if storage_index==0:tile.custom_minimum_size=Vector2(84,96)
			tile.set_meta("resource",id);tile.pressed.connect(func():selected_resource=id;selected_item="";_refresh_details();_highlight());grid.add_child(tile)
	_refresh_storage(available)
	if selected_item!="" and not data.items.has(selected_item):selected_item=""
	if tabs.current_tab==0 and selected_resource.is_empty() and not data.items.is_empty():
		if selected_item.is_empty():selected_item=data.slots[int(data.selected)] if data.slots[int(data.selected)]!="" else data.items.keys()[0]
		selected_definition=data.items[selected_item]
	_layout();_refresh_details();_highlight()
func _tile(parent: Node,id: String,definition: String) -> void:
	var def: Dictionary=FrontierEquipment.config().items[definition]
	var tile:=FrontierItemTile.new();tile.item_id=id;tile.set_meta("definition",definition);tile.picture=FrontierInterfaceStyle.icon(def.model);tile.grade=int(def.tier);tile.caption=def.name;tile.tooltip_text=def.name;FrontierItemBrowser.tag(tile,def.name,"equipment")
	if parent==owned:tile.custom_minimum_size=Vector2(84,96)
	if parent==recipes:
		tile.unavailable=int(data.kit)<=0 if definition=="miner_1" else not FrontierExpeditionBusiness.affordable(bag,def.cost)
		if tile.unavailable:tile.tooltip_text+="  재료 부족"
	tile.pressed.connect(func():selected_item=id;selected_definition=definition;selected_resource="";_refresh_details();_highlight())
	parent.add_child(tile);tiles.append(tile)
func _highlight() -> void:
	for grid in [owned,cargo]:
		for tile in grid.get_children():
			if tile.has_meta("resource"):tile.selected=tile.get_meta("resource")==selected_resource;tile.queue_redraw()
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
	left.visible=tabs.current_tab in [0,1];detail_shell.visible=tabs.current_tab in [0,1]
	upgrade_action.hide();withdraw_count.visible=tabs.current_tab==2 and storage.selected==1
	suit_action.hide()
	if tabs.current_tab==2:
		_refresh_transfer()
		return

	if tabs.current_tab==0 and not selected_resource.is_empty():
		var source: Dictionary=depot if tabs.current_tab==2 and storage.selected==1 else bag
		if int(source.get(selected_resource,0))<=0:
			selected_resource=""
			for id in source:
				if int(source[id])>0:selected_resource=id;break
		if selected_resource.is_empty():
			title.text="빈 보관함";category.text="공동 창고";preview.show_model("");action.text="선택한 아이템 없음";action.disabled=true;return
		action.show()
		var resource:=FrontierCatalog.entry("resources",selected_resource)
		title.text=resource.name;category.text="CARGO / "+("내 배낭" if storage.selected==0 else "공동 창고")
		if FrontierSpecimenItems.is_item(selected_resource):
			var sample: Dictionary=resource.sample
			category.text="생체 표본 / 내 아이템"
			preview.show_specimen(sample)
			var source_body:=FrontierUniverse.body_from_id(app.session.manifest,sample.source_body)
			var source_label:=FrontierInterfaceStyle.label(stats,"채집 행성  "+str(source_body.get("name","")),13);source_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			FrontierInterfaceStyle.label(stats,"수납 1칸 / 표본 1개",13)
			var use_label:=FrontierInterfaceStyle.label(stats,"생태 연구와 다른 행성의 이식에 사용합니다.
이식할 때 내 배낭에 있어야 합니다.",13);use_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var research_button:=Button.new();research_button.text="표본 연구대 위치";stats.add_child(research_button);research_button.pressed.connect(func():app.stations.navigate("research",2))
			action.text="창고로 옮기기…";action.disabled=false
			if response_left<=0:message.text="화물에서 일반 아이템과 함께 옮길 수 있습니다."
			return
		var product:=FrontierProductionTier2.product(selected_resource)
		preview.show_model(product.model if not product.is_empty() else "ore_"+selected_resource)
		_metric("보유 수량",str(int((bag if storage.selected==0 else depot).get(selected_resource,0))),float((bag if storage.selected==0 else depot).get(selected_resource,0))/float(FrontierItemInventory.config().resource_stack))
		if not product.is_empty():FrontierInterfaceStyle.label(stats,product.use,12)
		else:_metric("채집기 요구 등급",str(int(FrontierMineralWorld.tier(selected_resource))),float(FrontierMineralWorld.tier(selected_resource))/3)
		_show_uses(selected_resource)
		action.text="창고로 옮기기…";action.disabled=false
		message.text="화물에서 목적지와 수량을 선택합니다."
		return
	if tabs.current_tab==0 and selected_item.is_empty():
		title.text="아이템 선택";category.text="내 아이템";preview.show_model("");action.hide();message.text="";return
	action.show()
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
			var cost:=VBoxContainer.new();materials.add_child(cost);cost.add_child(FrontierResourceIcons.view(id,30));var have:=int(bag.get(id,0));FrontierInterfaceStyle.label(cost,"%d/%d"%[have,int(def.cost[id])],12,FrontierInterfaceStyle.ACCENT if have>=int(def.cost[id]) else FrontierInterfaceStyle.DANGER)
		if def.cost.is_empty():materials.add_child(FrontierResourceIcons.view("research_parts",30));FrontierInterfaceStyle.label(materials,"키트 %d / 1"%int(data.kit),13)
		var research_reason:=FrontierExpeditionResearch.craft_reason(app.session.latest,selected_definition)
		action.text="제작";action.disabled=not research_reason.is_empty() or app.surface_world==null or (selected_definition=="miner_1" and int(data.kit)<=0)
		if response_left<=0:message.text="착륙 후 휴대 제작기를 사용할 수 있습니다." if app.surface_world==null else ("재료를 모으면 제작할 수 있습니다." if action.disabled else "내 배낭의 재료를 사용합니다.");message.modulate=Color.WHITE
		if not research_reason.is_empty():message.text=research_reason
	else:
		upgrade_action.hide()
		action.text="현재 슬롯 비우기";action.disabled=data.slots[int(data.selected)]==""
		if response_left<=0:message.text="장비를 선택하고 아래 슬롯에 놓으세요.";message.modulate=Color.WHITE
func _slot(slot: int) -> void:
	if visible and tabs.current_tab==0 and not selected_item.is_empty():_equip(selected_item,slot)
	else:app.session.send_request("equipment_select",{"slot":slot})
func _equip(id: String,slot: int) -> void:
	if visible and data.items.has(id):app.session.send_request("equipment_equip",{"item_id":id,"slot":slot})
func _action() -> void:
	if tabs.current_tab==1:app.session.send_request("equipment_craft",{"definition":selected_definition})
	elif not selected_resource.is_empty():
		var resource:=selected_resource;tabs.current_tab=2
		storage_selection={"resource":resource,"source":"bag"};last_key=""
	else:app.session.send_request("equipment_equip",{"item_id":"","slot":int(data.selected)})

func _refresh_storage(available: int) -> void:
	var limit:=FrontierItemInventory.warehouse_capacity(storage_site)
	var occupied:=FrontierItemInventory.warehouse_used(storage_site)
	storage_headers[0].text="내 배낭  %d / %d"%[FrontierItemInventory.used(bag,data.items.size()),available]
	storage_headers[1].text=("내 FINCH" if not app.session.latest.get("local_shuttle","").is_empty() else "공동 원정선") if using_ship() else "행성 창고"
	storage_headers[1].text+="  %d / %d"%[occupied,limit]
	for i in 2:
		storage_bars[i].max_value=available if i==0 else limit
		storage_bars[i].value=FrontierItemInventory.used(bag,data.items.size()) if i==0 else occupied
	if response_left<=0:storage_label.text="옮기는 중…" if not storage_pending.is_empty() else "아이템을 선택하거나 반대편 슬롯으로 끌어놓으세요."
	if response_left<=0:storage_label.modulate=FrontierInterfaceStyle.WARNING if occupied>limit else FrontierInterfaceStyle.ACCENT
	for id in data.items:
		_storage_tile(storage_owned,{"equipment_item":id,"source":"bag"},FrontierInterfaceStyle.icon(FrontierEquipment.config().items[data.items[id]].model),"",FrontierEquipment.config().items[data.items[id]].name)
	for side in ["bag","warehouse"]:
		var grid: GridContainer=storage_owned if side=="bag" else cargo
		var source: Dictionary=bag if side=="bag" else depot
		for stack in FrontierItemInventory.stacks(source):
			_storage_tile(grid,{"resource":stack.resource,"amount":stack.amount,"source":side},FrontierResourceIcons.texture(stack.resource),str(stack.amount),FrontierCatalog.entry("resources",stack.resource).name)
	for stored in storage_site.get("stored_equipment",{}).values():
		var mine: bool=stored.owner==app.session.latest.self_id
		var def: Dictionary=FrontierEquipment.config().items[stored.definition]
		var payload: Dictionary={"equipment_item":stored.item_id,"source":"warehouse"} if mine else {}
		_storage_tile(cargo,payload,FrontierInterfaceStyle.icon(def.model),"",def.name+("" if mine else "  다른 승무원 소유"))

func _storage_tile(grid: GridContainer,payload: Dictionary,picture: Texture2D,amount: String,caption: String) -> void:
	var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(72,80) if get_viewport().get_visible_rect().size.x<1100 else Vector2(84,96);tile.picture=picture;tile.amount=amount;tile.caption=caption;tile.tooltip_text=caption
	FrontierItemBrowser.tag(tile,caption,FrontierItemBrowser.kind(str(payload.resource)) if payload.has("resource") else "equipment",int((bag if payload.get("source")=="bag" else depot).get(payload.get("resource",""),1)))
	tile.selected=not payload.is_empty() and payload.get("source")==storage_selection.get("source") and (payload.get("resource",payload.get("equipment_item",""))==storage_selection.get("resource",storage_selection.get("equipment_item","!")))
	tile.pressed.connect(func():
		if payload.is_empty():return
		storage_selection=payload.duplicate();last_key="";_refresh_transfer()
		if Input.is_physical_key_pressed(KEY_SHIFT):
			var quick:=payload.duplicate();quick.quick=true;_transfer_cargo(quick))
	tile.cargo_payload=payload;tile.cargo_destination="bag" if grid==storage_owned else "warehouse";tile.cargo_dropped.connect(_transfer_cargo);grid.add_child(tile)
func _transfer_cargo(payload: Dictionary) -> void:
	if not storage_pending.is_empty():return
	var withdraw: bool=payload.get("source")=="warehouse"
	if payload.has("equipment_item"):
		if using_ship():app.session.send_request("withdraw" if withdraw else "deposit",{"item_id":payload.equipment_item})
		else:app.session.send_request("business_store_equipment",{"item_id":payload.equipment_item,"withdraw":withdraw})
	elif payload.has("resource"):
		var args: Dictionary={"resource":payload.resource,"amount":payload.get("amount",int(transfer_count.value)),"quick":payload.get("quick",false)}
		app.session.send_request(("withdraw" if withdraw else "deposit") if using_ship() else ("business_withdraw" if withdraw else "business_deposit"),args)

func _storage_requested(_sequence: int,kind: String,_args: Dictionary) -> void:
	if visible and tabs.current_tab==2 and kind in ["deposit","withdraw","business_deposit","business_withdraw","business_store_equipment"]:
		storage_pending[_sequence]=true;last_key=""
		transfer_button.disabled=true;bulk_transfer.disabled=true
		storage_label.text="옮기는 중…";storage_label.modulate=FrontierInterfaceStyle.MUTED

func _transfer_limit() -> int:
	if storage_selection.is_empty() or data.is_empty():return 0
	var incoming: bool=storage_selection.get("source")=="warehouse"
	if storage_selection.has("equipment_item"):
		return 1 if (FrontierItemInventory.used(bag,data.items.size())<FrontierItemInventory.capacity(app.session.latest.crew.members[app.session.latest.self_id]) if incoming else FrontierItemInventory.warehouse_used(storage_site)<FrontierItemInventory.warehouse_capacity(storage_site)) else 0
	var resource: String=storage_selection.get("resource","")
	var source: Dictionary=depot if incoming else bag
	var room:=FrontierItemInventory.warehouse_room(storage_site,resource)
	if incoming:
		var world: Dictionary={"crew":app.session.latest.crew,"business":{"bags":{app.session.latest.self_id:app.session.latest.get("inventory",{})}}}
		room=FrontierItemInventory.room(world,app.session.latest.self_id,resource)
	return mini(int(source.get(resource,0)),room)

func _refresh_transfer() -> void:
	var incoming: bool=storage_selection.get("source")=="warehouse"
	var destination: String="선박 화물" if using_ship() else "행성 창고"
	var label: String=""
	if storage_selection.has("resource"):
		var resource: String=storage_selection.resource
		if int((depot if incoming else bag).get(resource,0))>0:label=FrontierCatalog.entry("resources",resource).name
	elif storage_selection.has("equipment_item"):
		var item: String=storage_selection.equipment_item
		if not incoming and data.items.has(item):label=FrontierEquipment.config().items[data.items[item]].name
		if incoming:
			for stored in storage_site.get("stored_equipment",{}).values():
				if stored.item_id==item and stored.owner==app.session.latest.self_id:label=FrontierEquipment.config().items[stored.definition].name
	if label.is_empty():storage_selection={}
	var maximum:=_transfer_limit()
	transfer_count.max_value=maxi(1,maximum);transfer_count.value=mini(transfer_count.value,maxi(1,maximum))
	transfer_count.editable=storage_selection.has("resource") and maximum>0 and storage_pending.is_empty()
	for button in quantity_buttons:button.disabled=not transfer_count.editable
	transfer_button.disabled=maximum<=0 or not storage_pending.is_empty()
	transfer_button.text="← 배낭으로" if incoming else "창고로 →"
	cargo_summary.text="물건을 선택하세요" if storage_selection.is_empty() else label+"  "+(destination+" → 내 배낭" if incoming else "내 배낭 → "+destination)+("  공간 부족" if maximum==0 else "  최대 %d개"%maximum)
	bulk_transfer.disabled=not storage_pending.is_empty() or FrontierExpeditionBusiness.total(bag)<=0
	if response_left<=0:storage_label.text="결과 확인 중…" if not storage_pending.is_empty() else "Shift+클릭  중첩 이동"

func _show_uses(resource: String) -> void:
	var uses: Array[Dictionary]=[]
	for field in FrontierCrewAugmentation.config().fields:
		var definition: Dictionary=FrontierCrewAugmentation.config().fields[field]
		if definition.gem==resource:uses.append({"name":definition.name,"model":"crew/surveyor_suit","cost":FrontierCrewAugmentation.cost(field,FrontierCrewAugmentation.level(app.session.latest.crew.members[app.session.latest.self_id],field)),"where":"우주선 증강 장치  F","target":"body","id":field})
	for id in FrontierEquipment.config().items:
		var definition: Dictionary=FrontierEquipment.config().items[id]
		if definition.cost.has(resource) and definition.get("craftable",true) and FrontierExpeditionResearch.craft_reason(app.session.latest,id).is_empty():uses.append({"name":definition.name,"model":definition.model,"cost":definition.cost,"where":"내 배낭  휴대 제작","target":"recipe","id":id})
	for id in FrontierProductionTier2.config().products:
		var definition: Dictionary=FrontierProductionTier2.product(id)
		if definition.cost.has(resource) and int(definition.tier)<=2:uses.append({"name":definition.name,"model":definition.model,"cost":definition.cost,"where":"현장 제작소  F  공동 창고 재료","target":"product","id":id})
	for id in FrontierExpeditionBusiness.config().buildings:
		var definition: Dictionary=FrontierCatalog.entry("buildings",id)
		if definition.cost.has(resource):uses.append({"name":definition.name,"model":definition.model,"cost":definition.cost,"where":"건설  B  내 배낭 재료","target":"building","id":id})
	var research: Dictionary=app.session.latest.get("expedition_research",{}).get("projects",{}).get("deep_mining",{})
	if research.get("evidence",{}).has(resource):uses.push_front({"name":"심부 정밀 채집 연구","model":"ore_"+resource,"cost":{resource:int(FrontierExpeditionResearch.config().projects.deep_mining.analysis_samples)},"where":"우주선 표본 연구대  F","target":"research","id":"deep_mining"})
	FrontierInterfaceStyle.label(stats,"알려진 사용처",13,FrontierInterfaceStyle.ACCENT)
	if uses.is_empty():FrontierInterfaceStyle.label(stats,"확인된 제작 / 연구 사용처 없음",12,FrontierInterfaceStyle.MUTED)
	for use in uses.slice(0,3):
		var button:=Button.new();button.text=use.name;button.icon=FrontierResourceIcons.texture(resource);button.add_theme_constant_override("icon_max_width",24);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.clip_text=true;button.tooltip_text=use.name+"  "+use.where;stats.add_child(button);button.pressed.connect(func():_open_use(use))
	if uses.size()>3:
		var more:=MenuButton.new();more.text="사용처 %d개 더 보기"%(uses.size()-3);stats.add_child(more)
		for i in range(3,uses.size()):more.get_popup().add_item(uses[i].name,i)
		more.get_popup().id_pressed.connect(func(index: int):_open_use(uses[index]))

func _open_use(use: Dictionary) -> void:
	if is_instance_valid(usage_dialog):usage_dialog.queue_free()
	usage_dialog=AcceptDialog.new();usage_dialog.title=use.name;usage_dialog.exclusive=true;usage_dialog.ok_button_text="닫기";add_child(usage_dialog)
	usage_dialog.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,12))
	usage_dialog.add_theme_stylebox_override("embedded_border",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,12))
	var background:=ColorRect.new();background.color=FrontierInterfaceStyle.INK;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;usage_dialog.add_child(background);usage_dialog.move_child(background,0);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content:=VBoxContainer.new();content.position=Vector2(18,18);content.size=Vector2(484,290);usage_dialog.add_child(content)
	var model:=FrontierEquipmentPreview.new();model.custom_minimum_size=Vector2(484,145);content.add_child(model);model.show_model(use.model)
	FrontierInterfaceStyle.label(content,use.where,14,FrontierInterfaceStyle.ACCENT)
	var cost:=FrontierResourceReadout.new();cost.custom_minimum_size.x=0;cost.value="현재 최고 단계" if use.cost.is_empty() else "필요 재료  "+FrontierCatalog.cost_text(use.cost);content.add_child(cost)
	if use.target!="product":
		var link:=Button.new();link.text={"recipe":"제작 설계 보기","building":"건설 설계 보기","body":"내 신체 능력 보기","research":"공동 연구 기록 보기"}[use.target];content.add_child(link)
		link.pressed.connect(_navigate_use.bind(use))
	usage_dialog.popup_centered(Vector2i(520,360))

func _navigate_use(use: Dictionary) -> void:
	usage_dialog.hide()
	match use.target:
		"recipe":tabs.current_tab=1;browsers["제작"].search.clear();selected_definition=use.id;last_key="";_filter_items();_refresh_details();_highlight()
		"body":tabs.current_tab=3
		"research":app.close_menus();app.toggle_research();app.research_frame.tabs.current_tab=0
		"building":
			if app.surface_world!=null:
				app.close_menus();app.toggle_business()
				for i in app.business_panel.building.item_count:
					if app.business_panel.building.get_item_metadata(i)==use.id:
						app.business_panel.building.select(i);app.business_panel.refresh_building_cost();break
