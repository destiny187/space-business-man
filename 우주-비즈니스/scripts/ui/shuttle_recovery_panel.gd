class_name FrontierShuttleRecoveryPanel
extends HBoxContainer
var app: FrontierCrewExpedition
var preview: FrontierEquipmentPreview
var choices: OptionButton
var detail: Label
var action: Button
var outcome: Label
var ids: Array=[]
var snapshot: Dictionary={}
var pending: int=-1
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;add_theme_constant_override("separation",18)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size=Vector2(140,145);add_child(preview)
	preview.show_model("ships/finch")
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(column)
	FrontierInterfaceStyle.label(column,"FINCH  이탈 승무원 회수",18)
	choices=OptionButton.new();column.add_child(choices);choices.item_selected.connect(func(_i: int):refresh())
	detail=FrontierInterfaceStyle.label(column,"",13,FrontierInterfaceStyle.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	action=Button.new();action.text="공동 원정선으로 회수";column.add_child(action)
	action.pressed.connect(func():
		if pending>=0 or ids.is_empty():return
		app.session.send_request("shuttle_recall",{"character_id":ids[choices.selected]}))
	outcome=FrontierInterfaceStyle.label(column,"",13);outcome.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	app.session.request_started.connect(func(sequence: int,kind: String,_args: Dictionary):
		if kind=="shuttle_recall":pending=sequence;outcome.text="회수 요청 중…";refresh())
	app.session.response_received.connect(func(sequence: int,result: Dictionary):
		if sequence!=pending:return
		pending=-1;outcome.text="회수 완료  화물과 개인 장비 보존" if result.get("ok",false) else str(result.get("error","회수 실패"));refresh())
func update_snapshot(value: Dictionary) -> void:
	snapshot=value
	var next: Array=[]
	for id in value.crew.get("shuttles",{}):
		if value.crew.shuttles[id].state=="sortie" and not value.crew.members[id].get("connected",false):next.append(id)
	if next!=ids:
		var selected: String=str(ids[choices.selected]) if not ids.is_empty() and choices.selected>=0 else ""
		ids=next;choices.clear()
		for id in ids:choices.add_item(value.crew.members[id].profile.name+"  연결 끊김")
		if selected in ids:choices.select(ids.find(selected))
	refresh()
func refresh() -> void:
	if snapshot.is_empty():return
	visible=not ids.is_empty() or not outcome.text.is_empty()
	choices.visible=not ids.is_empty();action.visible=not ids.is_empty()
	action.disabled=pending>=0 or not app.session.hosting or not snapshot.get("local_shuttle","").is_empty()
	if ids.is_empty():detail.text="";return
	var craft: Dictionary=snapshot.crew.shuttles[ids[choices.selected]]
	var cargo: Dictionary=craft.cargo.duplicate();cargo.stone=int(craft.rock)
	var used:=FrontierItemInventory.used(cargo,craft.cargo_equipment.size())
	detail.text="화물 %d / %d칸  가방 / 장비 / 화물 그대로 복귀\n소유자가 다시 접속하면 공동 원정선에서 재개합니다."%[used,int(FrontierShuttles.config().cargo_slots)]
	action.tooltip_text="호스트만 실행할 수 있습니다." if not app.session.hosting else "이탈한 승무원과 FINCH를 회수합니다. 자동 하역하지 않습니다."
