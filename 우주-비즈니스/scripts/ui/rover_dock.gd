class_name FrontierRoverDock
extends PanelContainer
var app: FrontierCrewExpedition
var controller: FrontierRoverController
var heading: Label
var status: Label
var cost: FrontierResourceReadout
var preview: FrontierEquipmentPreview
var upgrade: Button
var unload: Button
var cancel: Button
var progress: ProgressBar
var summary: Label
func configure(owner_app: FrontierCrewExpedition,owner_controller: FrontierRoverController) -> void:
	app=owner_app;controller=owner_controller;theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);offset_left=-410;offset_right=-24;offset_top=35;offset_bottom=-75
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll);var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(column)
	heading=FrontierInterfaceStyle.label(column,"차량 적재함",24)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(320,190);column.add_child(preview);preview.show_model("vehicles/scout_rover")
	status=FrontierInterfaceStyle.label(column,"",15);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	cost=FrontierResourceReadout.new();cost.custom_minimum_size.x=0;column.add_child(cost)
	progress=ProgressBar.new();progress.custom_minimum_size.y=20;column.add_child(progress)
	upgrade=action(column,"차량 적재 개조 I","rover_transport_upgrade")
	unload=action(column,"표시된 위치로 하역","rover_unload")
	cancel=action(column,"작업 취소","rover_cancel")
	var close:=Button.new();close.text="닫기 · Esc";column.add_child(close);close.pressed.connect(hide)
	var note:=FrontierInterfaceStyle.label(column,"로버의 화물은 차량 안에 그대로 보존됩니다.\n지상 차량은 착륙선 12m 내 정차 후 후방 화물함에서 적재하세요.",13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for i in app.business_panel.tabs.get_tab_count():
		var tab:=app.business_panel.tabs.get_tab_control(i)
		if tab.name!="착륙선":continue
		var row:=HBoxContainer.new();tab.add_child(row);tab.move_child(row,0)
		var icon:=TextureRect.new();icon.texture=load("res://assets/ui/previews/scout_rover.png");icon.custom_minimum_size=Vector2(58,48);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(icon)
		summary=FrontierInterfaceStyle.label(row,"",14);summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var button:=Button.new();button.text="차량 적재함";row.add_child(button);button.pressed.connect(func():app.open_menu(self))
	hide()
func action(parent: Node,caption: String,kind: String) -> Button:
	var button:=Button.new();button.text=caption;button.custom_minimum_size.y=42;parent.add_child(button)
	button.pressed.connect(func():
		var id:=FrontierRoverTransport.ship(controller.fleet())
		if kind=="rover_cancel":
			for key in controller.runtime().get("tasks",{}):
				if controller.runtime().tasks[key].actor==app.session.latest.self_id:id=key;break
		app.session.send_request(kind,{"id":id}))
	return button
func _process(_delta: float) -> void:
	if app.session.latest.is_empty():return
	var fleet:=controller.fleet();var aboard:=FrontierRoverTransport.ship(fleet)
	if summary!=null:summary.text="선내 %d / 1대 · 이 행성에 남길 차량 %d대"%[0 if aboard.is_empty() else 1,controller.local().size()]
func refresh() -> void:
	if app.session.latest.is_empty():return
	var fleet:=controller.fleet();var aboard:=FrontierRoverTransport.ship(fleet);var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	var near: bool=member.area=="surface" and FrontierCrewWorld.vector(member.position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
	var task: Dictionary={}
	for row in controller.runtime().get("tasks",{}).values():
		if row.kind in ["load","unload"]:task=row;break
	var level:=FrontierRoverTransport.level(fleet)
	heading.text="차량 적재함 · %d / 1"%(0 if aboard.is_empty() else 1)
	var point: Array=controller.runtime().get("unload_point",[])
	status.text="차량 적재 개조 I으로 한 대·6 운송 단위를 확보하세요." if level<1 else ("적재 공간이 비어 있습니다." if aboard.is_empty() else "%s · %.1f / 6 운송 단위\n%s"%[aboard,FrontierRoverTransport.units(fleet.vehicles[aboard]),"표시된 청록색 위치로 하역합니다." if point.size()==3 else "주변 하역 공간을 비워 주세요."])
	if not near:status.text+="\n착륙선 옆에서 작업할 수 있습니다."
	if not task.is_empty():status.text="%s · %.1f / %.0f초"%["적재 중" if task.kind=="load" else "하역 중",task.progress,task.seconds]
	cost.value="공동 창고 · "+FrontierCatalog.cost_text(FrontierRoverTransport.config().cost) if level<1 else "차량 화물과 장비 소유권 유지"
	upgrade.visible=level<1;upgrade.disabled=not near or app.session.latest.self_id!=app.session.latest.crew.owner_id
	unload.visible=level>0;unload.disabled=not near or aboard.is_empty() or point.size()!=3 or not task.is_empty();unload.text="표시 위치로 하역 · %.0f초"%FrontierRoverTransport.duration(member)
	cancel.visible=not task.is_empty();cancel.disabled=task.get("actor")!=app.session.latest.self_id
	progress.visible=not task.is_empty()
	if progress.visible:progress.max_value=task.seconds;progress.value=task.progress
