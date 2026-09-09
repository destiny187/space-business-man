class_name FrontierSuitDyePanel
extends HBoxContainer
var app: FrontierCrewExpedition
var preview: FrontierEquipmentPreview
var appearance: FrontierSuitAppearance
var part: String="helmet"
var draft: Dictionary={}
var expected: Dictionary={}
var pickers: Dictionary={}
var parts: Dictionary={}
var action: Button
var reset: Button
var message: Label
var cost_icon: TextureRect
var amount: Label
var receipt_revision:=0
var pending:=0
var sending:=false
var refreshing:=false
var was_visible:=false
func own() -> Dictionary:return app.session.latest.get("crew",{}).get("members",{}).get(app.session.latest.get("self_id",""),{})
func configure(owner: FrontierCrewExpedition) -> void:
	app=owner;name="염색";add_theme_constant_override("separation",18)
	preview=FrontierEquipmentPreview.new();preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL;preview.custom_minimum_size=Vector2(240,180);add_child(preview);preview.show_model(FrontierSuitAppearance.config().model)
	appearance=FrontierSuitAppearance.new();appearance.configure(preview.model)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);column.custom_minimum_size.x=300;add_child(column)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	var options:=VBoxContainer.new();options.add_theme_constant_override("separation",4);options.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(options)
	FrontierInterfaceStyle.label(options,"탐험복 염색",22)
	FrontierInterfaceStyle.label(options,"부위를 선택하고 색상을 눌러 변경",13,FrontierInterfaceStyle.MUTED)
	var grid:=GridContainer.new();grid.columns=3;options.add_child(grid)
	for key in FrontierSuitAppearance.config().parts:
		var button:=Button.new();button.text=FrontierSuitAppearance.config().parts[key];button.custom_minimum_size=Vector2(96,36);button.toggle_mode=true
		var gem: String=FrontierSuitAppearance.config().dye_costs[key].keys()[0]
		button.tooltip_text="%s 1개  /  T%d"%[FrontierResourceIcons.names()[gem],FrontierMineralWorld.tier(gem)]
		grid.add_child(button);parts[key]=button;button.pressed.connect(func():select_part(key))
	for channel in FrontierSuitAppearance.config().channels:
		var row:=HBoxContainer.new();options.add_child(row)
		var title:=FrontierInterfaceStyle.label(row,{"primary":"주색","secondary":"보조색","accent":"포인트색"}[channel],15);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var picker:=ColorPickerButton.new();picker.edit_alpha=false;picker.custom_minimum_size=Vector2(150,38);row.add_child(picker);pickers[channel]=picker
		var chooser:=picker.get_picker();chooser.sliders_visible=false;chooser.color_modes_visible=false;chooser.presets_visible=false
		picker.color_changed.connect(func(color: Color):
			if refreshing or (pending>0 or receipt_revision>0):return
			draft[channel]=color.to_html(false);render_preview();message.text="미리보기 중  적용하면 재료를 소비합니다.")
	var note:=FrontierInterfaceStyle.label(options,"한 부위의 3색을 함께 변경해도 같은 비용입니다.\n캐릭터를 드래그해 뒷면도 확인하세요.",13,FrontierInterfaceStyle.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var cost_row:=HBoxContainer.new();cost_row.alignment=BoxContainer.ALIGNMENT_CENTER;column.add_child(cost_row)
	var icon:=TextureRect.new();cost_icon=icon;icon.texture=FrontierResourceIcons.texture("sapphire");icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(32,32);icon.tooltip_text="사파이어";cost_row.add_child(icon)
	amount=FrontierInterfaceStyle.label(cost_row,"",16)
	action=Button.new();action.text="염색 적용";action.custom_minimum_size.y=40;column.add_child(action);action.pressed.connect(func():submit(false))
	reset=Button.new();reset.text="이 부위 기본색 복원  무료";column.add_child(reset);reset.pressed.connect(func():submit(true))
	message=FrontierInterfaceStyle.label(column,"",13);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size=Vector2(300,42)
	app.session.request_started.connect(func(sequence: int,kind: String,_args: Dictionary):
		if sending and kind=="suit_dye":pending=sequence)
	app.session.response_received.connect(func(sequence: int,result: Dictionary):
		if pending==0 or sequence!=pending:return
		pending=0
		if result.get("ok",false):
			receipt_revision=int(result.revision);message.text="색상 동기화 중"
		else:message.text=str(result.get("error","염색에 실패했습니다."));play("sfx_build_invalid"))
func play(id: String) -> void:
	if not is_visible_in_tree():return
	var player:=AudioStreamPlayer.new();player.bus="UI";player.volume_db=-15;player.stream=app.feedback.audio.stream(id);add_child(player);player.finished.connect(player.queue_free);player.play()
func select_part(key: String) -> void:
	if (pending>0 or receipt_revision>0):return
	part=key;expected=own().get("suit_dyes",{}).get(part,{}).duplicate();draft=expected.duplicate();message.text=""
	appearance.clear_dyes();appearance.sync(own());refreshing=true
	for channel in pickers:pickers[channel].color=appearance.paints["DYE::"+part+"::"+channel].get_shader_parameter("base_color")
	refreshing=false
	for key_value in parts:parts[key_value].button_pressed=key_value==part
	preview.model.rotation.y=PI if part=="backpack" else 0
	preview.request_render()
func render_preview() -> void:
	appearance.clear_dyes()
	for channel in draft:appearance.set_dye(part,channel,Color(draft[channel]))
	appearance.sync(own());preview.request_render()
func submit(restore: bool) -> void:
	if (pending>0 or receipt_revision>0) or sending:return
	var colors: Dictionary={} if restore else draft.duplicate()
	if colors==expected:message.text="변경할 색상이 없습니다.";return
	sending=true;message.text="염색 적용 중"
	var sent:=app.session.send_request("suit_dye",{"part":part,"colors":colors,"expected":expected.duplicate()})
	sending=false
	if not sent:pending=0;message.text="연결 상태를 확인하세요."
func _process(_delta: float) -> void:
	if receipt_revision>0 and int(app.session.latest.get("crew",{}).get("revision",0))>=receipt_revision:
		receipt_revision=0;select_part(part);message.text="염색이 적용되었습니다.";play("sfx_factory_complete")
	var showing:=is_visible_in_tree()
	if showing and not was_visible and pending==0:select_part(part)
	was_visible=showing
	if not showing:return
	if appearance.sync(own()):preview.request_render()
	var price_data: Dictionary=FrontierSuitAppearance.config().dye_costs[part]
	var gem: String=price_data.keys()[0]
	var count:=int(app.session.latest.get("inventory",{}).get(gem,0));var price:=int(price_data[gem])
	cost_icon.texture=FrontierResourceIcons.texture(gem);cost_icon.tooltip_text=FrontierResourceIcons.names()[gem]
	amount.text="%d  /  보유 %d"%[price,count];amount.modulate=Color("ef7777") if count<price else Color.WHITE
	action.disabled=(pending>0 or receipt_revision>0);reset.disabled=(pending>0 or receipt_revision>0)
	for button in parts.values():button.disabled=(pending>0 or receipt_revision>0)
	for picker in pickers.values():picker.disabled=(pending>0 or receipt_revision>0)
