class_name FrontierEquipmentWorkshop
extends HBoxContainer
var app: FrontierCrewExpedition
var selected:="suit"
var grid: GridContainer
var preview: FrontierEquipmentPreview
var title: Label
var detail: Label
var cost: FrontierResourceReadout
var action: Button
var signature:=""
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;name="장비 개조";add_theme_constant_override("separation",18)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=205;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
	grid=GridContainer.new();grid.columns=2;scroll.add_child(grid)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(right)
	var content_scroll:=ScrollContainer.new();content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.add_child(content_scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content_scroll.add_child(content)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size.y=145;content.add_child(preview)
	title=FrontierInterfaceStyle.label(content,"",22);title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail=FrontierInterfaceStyle.label(content,"",14);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cost=FrontierResourceReadout.new();cost.custom_minimum_size.x=0;content.add_child(cost)
	action=Button.new();action.custom_minimum_size.y=42;right.add_child(action)
	action.pressed.connect(func():app.session.send_request("equipment_suit_upgrade" if selected=="suit" else "equipment_upgrade",{"station_id":"ship:augmentation","item_id":selected}))
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or app.session.latest.is_empty():return
	refresh()
func refresh() -> void:
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	var loadout:=FrontierEquipment.state(member)
	var next:=str(loadout.items)
	if next!=signature:
		signature=next
		for child in grid.get_children():grid.remove_child(child);child.queue_free()
		if selected!="suit" and not loadout.items.has(selected):selected="suit"
		add_item("suit","탐험복","crew/surveyor_suit")
		for id in loadout.items:
			var def: Dictionary=FrontierEquipment.config().items[loadout.items[id]]
			add_item(id,def.name,def.model)
	var materials: Dictionary={}
	var reason: String=app.stations.work_reason("augmentation")
	var target: Dictionary={}
	if selected=="suit":
		title.text="탐험복  Mk.%d"%int(loadout.get("suit_tier",1));preview.show_model("crew/surveyor_suit")
		detail.text="장비 효과  달리기 소모 −20%  낙하 피해 −25%"
		if int(loadout.get("suit_tier",1))<2:materials=FrontierProductionTier2.config().suit_upgrade.cost
	else:
		var definition: String=loadout.items[selected]
		var current: Dictionary=FrontierEquipment.config().items[definition]
		title.text=current.name;preview.show_model(current.model)
		for id in FrontierEquipment.config().items:
			var candidate: Dictionary=FrontierEquipment.config().items[id]
			if candidate.get("upgrade_from","")!=definition:continue
			target=candidate;materials=candidate.cost
			var gate:=FrontierExpeditionResearch.craft_reason(app.session.latest,id)
			if reason.is_empty():reason=gate
			break
		detail.text="소유한 장비의 성능을 높입니다. 장착 위치는 유지됩니다."
		if not target.is_empty():detail.text+="\n"+current.name+" → "+str(target.name)
	if materials.is_empty():reason="최고 개조 단계입니다."

	cost.show_cost(materials,app.session.latest.get("inventory",{}),true)
	action.disabled=not reason.is_empty();action.text="Mk.2로 개조" if reason.is_empty() else reason
	for child in grid.get_children():child.selected=child.get_meta("item")==selected;child.queue_redraw()
func add_item(id: String,caption: String,model: String) -> void:
	var tile:=FrontierItemTile.new();tile.picture=FrontierInterfaceStyle.icon(model);tile.caption=caption;tile.tooltip_text=caption;tile.set_meta("item",id);grid.add_child(tile);tile.pressed.connect(func():selected=id;refresh())
