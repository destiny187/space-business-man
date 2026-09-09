class_name FrontierRoverPanel
extends PanelContainer
var app: FrontierCrewExpedition
var controller: FrontierRoverController
var vehicle_id:=""
var title: Label
var battery: ProgressBar
var health: ProgressBar
var cargo: GridContainer
var bag: GridContainer
var repair: Button
var rescue: Button
var note: Label
var actions: HBoxContainer
var signature:=""
var upgrade: Button
var loading: Button
var cancel: Button
var work_progress: ProgressBar
func configure(owner_app: FrontierCrewExpedition,owner_controller: FrontierRoverController) -> void:
	app=owner_app;controller=owner_controller;theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);offset_left=32;offset_right=-32;offset_top=35;offset_bottom=-80
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();add_child(column)
	var header:=HBoxContainer.new();column.add_child(header);title=FrontierInterfaceStyle.label(header,"SCOUT  화물",24);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=Button.new();close.text="닫기  Esc";header.add_child(close);close.pressed.connect(hide)
	var row:=HBoxContainer.new();row.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(row)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=245;row.add_child(left)
	var preview:=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(240,160);left.add_child(preview);preview.show_model("vehicles/scout_rover")
	FrontierInterfaceStyle.label(left,"배터리",14);battery=ProgressBar.new();left.add_child(battery)
	FrontierInterfaceStyle.label(left,"내구도",14);health=ProgressBar.new();left.add_child(health)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(right)
	FrontierInterfaceStyle.label(right,"차량 화물  4칸",17);cargo=GridContainer.new();cargo.columns=4;right.add_child(cargo)
	FrontierInterfaceStyle.label(right,"내 가방  클릭하여 한 묶음 이동",17)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.add_child(scroll);bag=GridContainer.new();bag.columns=4;scroll.add_child(bag)
	work_progress=ProgressBar.new();work_progress.custom_minimum_size.y=20;column.add_child(work_progress)
	note=FrontierInterfaceStyle.label(column,"",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	actions=HBoxContainer.new();column.add_child(actions)
	repair=button("수리  철 5 / 구리 2", "rover_repair");rescue=button("구조 충전  50 Cr", "rover_rescue")
	var secondary:=HBoxContainer.new();column.add_child(secondary);actions=secondary
	upgrade=button("Mk.2 개조  20초","rover_upgrade");loading=button("우주선 적재","rover_load");cancel=button("작업 취소","rover_cancel")
	hide()
func button(caption: String,kind: String) -> Button:
	var control:=Button.new();control.text=caption;control.custom_minimum_size.y=40;control.size_flags_horizontal=Control.SIZE_EXPAND_FILL;actions.add_child(control);control.pressed.connect(func():app.session.send_request(kind,{"id":vehicle_id}));return control
func move_item(args: Dictionary) -> void:
	args=args.duplicate();args.id=vehicle_id;app.session.send_request("rover_transfer",args)
func tile(parent: GridContainer,resource: String,amount: int,withdraw: bool,item: Dictionary={}) -> void:
	var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(86,83);parent.add_child(tile)
	var args: Dictionary={"withdraw":withdraw}
	if item.is_empty():
		tile.picture=FrontierResourceIcons.texture(resource);tile.amount=str(amount);tile.tooltip_text=FrontierCatalog.entry("resources",resource).get("name",resource);args.resource=resource
	else:
		var def: Dictionary=FrontierEquipment.config().items[item.definition];tile.picture=load("res://assets/ui/equipment/"+str(def.model).get_file()+".png") if ResourceLoader.exists("res://assets/ui/equipment/"+str(def.model).get_file()+".png") else null;tile.caption=def.get("name",item.definition);tile.tooltip_text=tile.caption;args.item_id=item.item_id;tile.disabled=item.get("owner",app.session.latest.self_id)!=app.session.latest.self_id;tile.unavailable=tile.disabled
	tile.cargo_payload={"source":"rover" if withdraw else "bag","args":args};tile.cargo_destination="rover" if withdraw else "bag"
	tile.pressed.connect(func():move_item(args));tile.cargo_dropped.connect(func(payload: Dictionary):move_item(payload.args))
func refresh() -> void:
	var r: Dictionary=controller.local().get(vehicle_id,{})
	if r.is_empty():hide();return
	var actor: String=app.session.latest.self_id;var member: Dictionary=app.session.latest.crew.members[actor]
	if FrontierRovers.point(r,FrontierRovers.config().cargo_point).distance_to(FrontierCrewWorld.vector(member.position))>3.5 or not FrontierRovers.stopped(r):hide();return
	title.text="SCOUT %s  %s"%["Mk.2" if int(r.upgrade_level)>0 else "Mk.1",vehicle_id]
	battery.max_value=FrontierRovers.stats(r).battery;battery.value=r.battery;health.max_value=FrontierRovers.stats(r).health;health.value=r.health
	upgrade.visible=int(r.upgrade_level)<1;upgrade.tooltip_text="내 가방  "+FrontierCatalog.cost_text(FrontierRovers.config().upgrade.cost)
	loading.visible=true
	var busy:=FrontierRovers.busy(controller.runtime(),vehicle_id)
	upgrade.disabled=busy;loading.disabled=busy;cancel.visible=busy;cancel.disabled=controller.runtime().get("tasks",{}).get(vehicle_id,{}).get("actor")!=actor
	loading.text="우주선 적재  %.0f초"%FrontierRoverTransport.duration(member)
	repair.disabled=busy or float(r.health)>=float(health.max_value);rescue.disabled=busy or float(r.battery)>=20
	note.text="자원은 공유, 장비는 넣은 본인만 회수합니다. 충전소 4m 이내 정차 시 자동 충전됩니다." if not busy else "차량 작업 중  완료 전 화물을 옮길 수 없습니다"
	work_progress.visible=busy
	if busy:
		var task: Dictionary=controller.runtime().tasks[vehicle_id];work_progress.max_value=task.seconds;work_progress.value=task.progress;note.text="차량 작업 중  %.1f / %.0f초  완료 전 화물 이동 불가"%[task.progress,task.seconds]
	var stock: Dictionary=app.session.latest.get("inventory",{});var loadout:=FrontierEquipment.state(member)
	var key:=str([r.cargo,r.equipment,stock,loadout.items,busy])
	if signature==key:return
	signature=key
	for parent in [cargo,bag]:
		for child in parent.get_children():parent.remove_child(child);child.queue_free()
	for resource in r.cargo:
		var remaining:=int(r.cargo[resource])
		while remaining>0:tile(cargo,resource,mini(100,remaining),true);remaining-=100
	for item in r.equipment.values():tile(cargo,"",1,true,item)
	while cargo.get_child_count()<4:
		var empty:=FrontierItemTile.new();empty.custom_minimum_size=Vector2(86,83);empty.cargo_destination="rover";cargo.add_child(empty);empty.cargo_dropped.connect(func(payload: Dictionary):move_item(payload.args))
	for resource in stock:
		if int(stock[resource])>0:tile(bag,resource,int(stock[resource]),false)
	for id in loadout.items:tile(bag,"",1,false,{"item_id":id,"definition":loadout.items[id]})
