class_name FrontierAugmentationPanel
extends HBoxContainer
## Local preparation never reserves gems. Only the matching host receipt confirms growth.
var app: FrontierCrewExpedition
var body: FrontierAugmentationBody
var tree: FrontierAugmentationTree
var branch_requirement: Label
var field: String="mobility"
var loaded:=false
var shown_level:=0
var phase: String="ready"
var pending_sequence:=0
var sending:=false
var receipt_revision:=0
var phase_time:=0.0
var comparison: Label
var field_name: Label
var level_text: Label
var stat_bar: ProgressBar
var steps: Array[ColorRect]=[]
var gems: Dictionary={}
var bag_heading: Label
var gem_row: HBoxContainer
var slot: FrontierAugmentationSlot
var requirement: Label
var action: Button
var message: Label
var speaker: AudioStreamPlayer
var process_sound: AudioStreamPlayer
var last_receipt: Dictionary={}
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;size_flags_vertical=Control.SIZE_EXPAND_FILL
	var tree_scroll:=ScrollContainer.new();tree_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tree_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(tree_scroll)
	tree=FrontierAugmentationTree.new();tree_scroll.add_child(tree);tree.field_selected.connect(select_field)
	var right_shell:=VBoxContainer.new();right_shell.custom_minimum_size.x=310;add_child(right_shell)
	var detail_scroll:=ScrollContainer.new();detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right_shell.add_child(detail_scroll)
	var right:=VBoxContainer.new();right.custom_minimum_size.x=292;right.add_theme_constant_override("separation",6);detail_scroll.add_child(right)
	body=FrontierAugmentationBody.new();right.add_child(body);body.custom_minimum_size=Vector2(292,130);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.size_flags_vertical=Control.SIZE_FILL
	for button in body.buttons.values():button.hide()
	field_name=FrontierInterfaceStyle.label(right,"",22)
	level_text=FrontierInterfaceStyle.label(right,"",13,FrontierInterfaceStyle.MUTED)
	var levels:=HBoxContainer.new();levels.add_theme_constant_override("separation",5);right.add_child(levels)
	for i in int(FrontierCrewAugmentation.config().maximum_level):
		var step:=ColorRect.new();step.custom_minimum_size=Vector2(44,5);levels.add_child(step);steps.append(step)
	comparison=FrontierInterfaceStyle.label(right,"",17)
	branch_requirement=FrontierInterfaceStyle.label(right,"",13,FrontierInterfaceStyle.WARNING)
	stat_bar=ProgressBar.new();stat_bar.show_percentage=false;stat_bar.custom_minimum_size.y=5;right.add_child(stat_bar)
	bag_heading=FrontierInterfaceStyle.label(right,"내 배낭",13,FrontierInterfaceStyle.MUTED)
	var bag_row:=HBoxContainer.new();gem_row=bag_row;bag_row.add_theme_constant_override("separation",6);right.add_child(bag_row)
	for id in ["sapphire","ruby","emerald"]:
		var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(84,64);tile.picture=FrontierResourceIcons.texture(id);tile.cargo_payload={"augmentation_gem":id};tile.tooltip_text=FrontierResourceIcons.names()[id]+"  클릭 또는 투입 슬롯에 끌어놓기";bag_row.add_child(tile);gems[id]=tile
		tile.pressed.connect(func():prepare_gem(id))
	var input_row:=HBoxContainer.new();right_shell.add_child(input_row)
	slot=FrontierAugmentationSlot.new();slot.custom_minimum_size=Vector2(64,60);slot.tooltip_text="투입할 보석  클릭해 준비/해제";input_row.add_child(slot);slot.gem_dropped.connect(prepare_gem)
	slot.pressed.connect(func():
		if loaded:loaded=false;set_phase("ready");refresh()
		else:prepare_gem(definition().gem))
	requirement=FrontierInterfaceStyle.label(input_row,"",14);requirement.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;requirement.custom_minimum_size.x=185
	var spacer:=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(spacer)
	action=Button.new();action.custom_minimum_size.y=40;right_shell.add_child(action);action.pressed.connect(submit)
	message=FrontierInterfaceStyle.label(right_shell,"",13);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size=Vector2(292,24)
	speaker=AudioStreamPlayer.new();speaker.bus="UI";speaker.volume_db=-12;add_child(speaker)
	process_sound=AudioStreamPlayer.new();process_sound.bus="SFX";process_sound.volume_db=-27;process_sound.stream=app.feedback.audio.stream("sfx_robot_charge",true);add_child(process_sound)
	app.session.request_started.connect(requested);app.session.response_received.connect(responded)
	visibility_changed.connect(func():
		if not is_visible_in_tree():speaker.stop();process_sound.stop()
		else:refresh())
func member() -> Dictionary:return app.session.latest.get("crew",{}).get("members",{}).get(app.session.latest.get("self_id",""),{})
func bag() -> Dictionary:return app.session.latest.get("inventory",{})
func definition() -> Dictionary:return FrontierCrewAugmentation.config().fields[field]
func busy() -> bool:return pending_sequence>0 or sending or phase=="success" or receipt_revision>int(app.session.latest.get("crew",{}).get("revision",0))
func select_field(key: String) -> void:
	if busy() or not FrontierCrewAugmentation.config().fields.has(key):return
	field=key;loaded=false;set_phase("ready");message.text="";refresh()
func open() -> void:
	if not busy():loaded=false;set_phase("ready");message.text=""
	app._suit_color(body.preview.character,int(member().get("profile",{}).get("tint",0)))
	refresh()
func prepare_gem(id: String) -> void:
	if busy():return
	var gate:=FrontierCrewAugmentation.unlock_reason(member(),field)
	if not gate.is_empty():reject(gate);return
	if id!=definition().gem:reject("이 부위에는 %s가 필요합니다."%FrontierResourceIcons.names()[definition().gem]);return
	if shown_level>=int(FrontierCrewAugmentation.config().maximum_level):reject("최고 증강 단계입니다.");return
	var required: int=FrontierCrewAugmentation.cost(field,shown_level)[id]
	if int(bag().get(id,0))<required:reject("재료가 부족합니다.");return
	loaded=true;set_phase("prepared");message.text="실행하면 보석을 소비합니다.";play("sfx_pickup_resource");refresh()
func reject(reason: String) -> void:
	loaded=false;set_phase("error");message.text=reason;play("sfx_build_invalid");refresh()
func play(id: String) -> void:
	if not is_visible_in_tree():return
	speaker.stream=app.feedback.audio.stream(id);speaker.play()
func set_phase(value: String) -> void:
	phase=value;phase_time=0;body.preview.change_phase(value)
	if value!="waiting":process_sound.stop()
func submit() -> void:
	if busy():return
	if not loaded:
		prepare_gem(definition().gem)
		if not loaded:return
	var level:=shown_level
	sending=true;set_phase("waiting");message.text="장치 처리  결과 확인 중";process_sound.play();refresh()
	var sent:=app.session.send_request("augmentation_upgrade",{"station_id":"ship:augmentation","field":field,"expected_level":level})
	sending=false
	if not sent:pending_sequence=0;reject("연결 상태를 확인한 뒤 다시 실행하세요.")
func requested(sequence: int,kind: String,_args: Dictionary) -> void:
	if sending and kind=="augmentation_upgrade":pending_sequence=sequence
func responded(sequence: int,value: Dictionary) -> void:
	if sequence!=pending_sequence or pending_sequence==0:return
	pending_sequence=0;last_receipt=value.duplicate(true)
	if not value.get("ok",false):reject(str(value.get("error","증강할 수 없습니다.")));return
	loaded=false;receipt_revision=int(value.revision);set_phase("success")
	message.text="증강 완료  %d단계"%int(value.augmentation.level)
	play("sfx_factory_complete");refresh()
func refresh() -> void:
	var own:=member()
	if own.is_empty():return
	var current:=FrontierCrewAugmentation.level(own,field)
	if not busy():
		if shown_level!=current and loaded:loaded=false;set_phase("ready");message.text="단계가 바뀌었습니다. 보석을 다시 준비하세요."
		shown_level=current
	var maximum:=int(FrontierCrewAugmentation.config().maximum_level)
	field_name.text=definition().name
	level_text.text="%d / %d 단계"%[current,maximum]
	comparison.text=("누적 효과  "+FrontierCrewAugmentation.stat_text(own,field)) if current>=maximum else ("%s %+.0f%%"%[definition().stat,float(definition().increment)*100])
	comparison.tooltip_text="현재 누적 효과: "+FrontierCrewAugmentation.stat_text(own,field)
	comparison.add_theme_color_override("font_color",FrontierInterfaceStyle.ACCENT)
	level_text.text+="  /  "+("강화 완료" if current>=maximum else "이번 강화 효과")
	branch_requirement.text=FrontierCrewAugmentation.unlock_reason(own,field)
	branch_requirement.visible=not branch_requirement.text.is_empty()
	stat_bar.max_value=maximum;stat_bar.value=current;stat_bar.hide()
	tree.refresh(own,field,busy())
	for i in steps.size():steps[i].color=FrontierInterfaceStyle.ACCENT if i<current else FrontierInterfaceStyle.LINE
	var required:=int(definition().base_cost)*(current+1)
	for id in gems:
		gems[id].visible=int(bag().get(id,0))>0;gems[id].amount=str(int(bag().get(id,0)));gems[id].selected=id==definition().gem;gems[id].disabled=busy();gems[id].queue_redraw()
	body.selected=definition().body;body.preview.field=definition().body;body.preview.appearance.sync(own)
	for button in body.buttons.values():button.disabled=busy()
	body.preview.load_gem(str(definition().gem) if loaded or phase in ["waiting","success"] else "")
	slot.selected=loaded;slot.disabled=busy()
	slot.picture=FrontierResourceIcons.texture(definition().gem);slot.amount=str(required);slot.queue_redraw()
	requirement.text="최고 단계" if current>=maximum else "보유 %d / 필요 %d\n%s"%[int(bag().get(definition().gem,0)),required,"투입 준비됨" if loaded else "보석 슬롯 클릭"]
	requirement.modulate=FrontierInterfaceStyle.TEXT if int(bag().get(definition().gem,0))>=required else FrontierInterfaceStyle.DANGER
	action.disabled=busy() or current>=maximum or not branch_requirement.text.is_empty()
	action.text="처리 중…" if busy() else ("최고 단계" if current>=maximum else ("증강 실행" if loaded else "보석 투입 후 증강"))
	message.modulate=FrontierInterfaceStyle.WARNING if phase=="error" else FrontierInterfaceStyle.ACCENT
	message.visible=not message.text.is_empty()
func _process(delta: float) -> void:
	if not app.session.active:
		pending_sequence=0;sending=false;receipt_revision=0;loaded=false
		if phase!="ready":set_phase("ready")
		return
	phase_time+=delta
	if phase=="success" and phase_time>=1.1 and int(app.session.latest.crew.revision)>=receipt_revision:set_phase("ready")
	if phase=="waiting" and phase_time>8:message.text="응답을 기다리고 있습니다. 창을 닫아도 결과는 기록됩니다."
	if is_visible_in_tree():
		var compact:=get_viewport().get_visible_rect().size.y<720
		body.custom_minimum_size.y=92 if compact else 185
		gem_row.hide();bag_heading.hide()
		refresh()
