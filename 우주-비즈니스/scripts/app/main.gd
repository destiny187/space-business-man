extends Node

const INK := Color("09151e")
const PAPER := Color("eef3ef")
const MUTED := Color("91a6b0")
const MINT := Color("94edcf")
const ORANGE := Color("ffc180")

var campaign := FrontierCampaign.new()
var simulation := FrontierSimulation.new()
var world: FrontierPlanetView
var ui: Control
var hud: Control
var menu: Control
var body: VBoxContainer
var notification: Label
var screen: String = "title"
var selected_event: String = ""
var selected_recovery: Array = []
var selected_crew: Array = []
var notification_time: float = 0.0
var sim_accumulator: float = 0.0
var refresh_time: float = 0.0
var save_time: float = 0.0
var mine_time: float = 0.0
var smoke_mode: bool = false
var audio: FrontierAudio
var binding_target: String = ""
var quitting: bool = false
var tool_heat: float = 0.0
var pulse_time: float = 0.0
var overheated: bool = false
var suppress_pulse: bool = false
var show_all_planets: bool = false
var menu_scroll: ScrollContainer

func _ready() -> void:
	DisplayServer.window_set_min_size(Vector2i(960,640))
	get_tree().auto_accept_quit = false
	campaign.persistence_enabled = false
	campaign.new_campaign()
	campaign.persistence_enabled = true
	_apply_settings()
	world = FrontierPlanetView.new()
	world.campaign = campaign
	add_child(world)
	audio = FrontierAudio.new()
	add_child(audio)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = _theme()
	canvas.add_child(ui)
	_create_hud()
	campaign.changed.connect(_on_changed)
	campaign.message.connect(func(value: String):
		toast(value)
		if value.contains("제작 완료"): audio.play("sfx_factory_complete"))
	world.rebuild({})
	_show_menu("title")
	_apply_client_settings.call_deferred()
	if "--smoke" in OS.get_cmdline_user_args():
		smoke_mode = true
		_smoke_setup()

func _apply_client_settings() -> void:
	# The root is still adding the initial scene during _ready().
	FrontierClientSettings.ensure(get_tree()).apply_all()

func _theme() -> Theme:
	var theme := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color","Label",PAPER)
	theme.set_color("font_color","Button",PAPER)
	theme.set_color("font_hover_color","Button",Color.WHITE)
	theme.set_color("font_disabled_color","Button",Color("6a7b7e"))
	theme.set_stylebox("normal","Button",_style(Color("20323c"),Color("36505a"),5,14))
	theme.set_stylebox("hover","Button",_style(Color("2a4d4d"),MINT,5,14))
	theme.set_stylebox("pressed","Button",_style(Color("356757"),MINT,5,14))
	theme.set_stylebox("disabled","Button",_style(Color("14232d"),Color("263842"),5,14))
	theme.set_stylebox("focus","Button",_style(Color(0,0,0,0),MINT,8,0))
	theme.set_stylebox("panel","PanelContainer",_style(Color("12222d"),Color("2b414c"),7,18))
	theme.set_constant("separation","VBoxContainer",12)
	theme.set_constant("separation","HBoxContainer",12)
	theme.set_stylebox("background","ProgressBar",_style(Color("263c45"),Color("263c45"),3,0))
	theme.set_stylebox("fill","ProgressBar",_style(MINT,MINT,3,0))
	theme.set_color("font_color","CheckBox",PAPER)
	return theme

func _style(color: Color,border: Color,radius: int,padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(parent: Node,text_value: String,size_value: int = 16,color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func _paragraph(parent: Node,text_value: String,color: Color = MUTED) -> Label:
	var label: Label = _label(parent,text_value,15,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(parent: Node,text_value: String,action: Callable,disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	if text_value.contains(" Cr"):
		button.icon=FrontierResourceIcons.menu_texture("credits")
	button.custom_minimum_size.y = 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = disabled
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	parent.add_child(row)
	return row

func _card(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	return column

func _create_hud() -> void:
	var flight := FrontierFlightHUD.new()
	flight.app = self
	hud = flight
	ui.add_child(hud)
	notification = _label(ui,"",16,MINT)
	notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notification.offset_left = -390
	notification.offset_right = 390
	notification.offset_top = 82
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.z_index = 30

func _primary(button: Button) -> Button:
	button.add_theme_stylebox_override("normal",_style(MINT,Color("b4ffe6"),5,14))
	button.add_theme_stylebox_override("hover",_style(Color("b6ffe5"),Color.WHITE,5,14))
	button.add_theme_stylebox_override("pressed",_style(Color("69c9ab"),MINT,5,14))
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",INK)
	button.add_theme_color_override("font_pressed_color",INK)
	return button

func _preview(parent: Node,key: String,height: float = 130) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",_style(Color("e5e2d6"),Color("2e4954"),5,0))
	frame.custom_minimum_size.y = height
	parent.add_child(frame)
	var texture := TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.custom_minimum_size.y = height
	var path: String = "res://assets/ui/previews/"+key+".png"
	if ResourceLoader.exists(path): texture.texture = load(path)
	frame.add_child(texture)

func _planet_portrait(parent: Node,key: String,height: float = 155) -> void:
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(0,height)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/materials/planet_portrait.gdshader")
	material.set_shader_parameter("soil",Color(FrontierCatalog.entry("planets",key).color))
	material.set_shader_parameter("seed",float(key.hash()%100))
	portrait.material = material
	parent.add_child(portrait)
	portrait.resized.connect(func(): material.set_shader_parameter("aspect",portrait.size.x/maxf(1,portrait.size.y)))

func _show_menu(kind: String) -> void:
	var old_scroll: float = menu_scroll.scroll_vertical if is_instance_valid(menu_scroll) and screen == kind else 0
	screen = kind
	notification.offset_top = 6
	world.controls_enabled = false
	if is_instance_valid(audio): audio.update_world(campaign.planet,true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	if is_instance_valid(menu): menu.free()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.025,0.052,0.077,0.40 if kind == "title" else 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	if kind == "title":
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		panel.offset_left = 48; panel.offset_right = 520; panel.offset_top = 54; panel.offset_bottom = -54
		panel.add_theme_stylebox_override("panel",_style(Color(0.025,0.055,0.075,0.94),Color("354e54"),8,32))
		menu.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		_title_menu(column)
		var caption: Label = _label(menu,"KEPLER SECTOR\nYOUR NEXT FRONTIER",15,MINT)
		caption.position = Vector2(855,654)
		return
	var shell := HBoxContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 28; shell.offset_right = -28; shell.offset_top = 28; shell.offset_bottom = -28
	shell.add_theme_constant_override("separation",26)
	menu.add_child(shell)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 174
	sidebar.add_theme_constant_override("separation",8)
	shell.add_child(sidebar)
	_label(sidebar,"LOCUS",33,PAPER)
	_label(sidebar,"PLANETARY VENTURES",10,MINT)
	var space := Control.new(); space.custom_minimum_size.y = 32; sidebar.add_child(space)
	for tab in [["earth","01   사업 본부"],["technology","02   기술 연구"],["build","03   건설 카탈로그"],["robots","04   자율장비"],["planet","05   행성 평가"],["journal","06   발견 기록"],["help","07   개척 가이드"],["settings","08   설정"]]:
		var page: String = tab[0]
		var button: Button = _button(sidebar,tab[1],func(): _show_menu(page))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",14)
		if kind == page:
			button.add_theme_stylebox_override("normal",_style(Color("24443f"),MINT,5,13))
			button.add_theme_color_override("font_color",MINT)
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; sidebar.add_child(spacer)
	_button(sidebar,"저장 · 복구",func(): _show_menu("pause"))
	_label(sidebar,"AVAILABLE CAPITAL",10,MUTED)
	_label(sidebar,_number(campaign.profile.credits)+" Cr",22,ORANGE)
	_label(sidebar,"EARTH / 지구 본부" if campaign.planet.is_empty() else "REMOTE / 연결 일시정지",11,MUTED)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",16)
	shell.add_child(column)
	var titles: Dictionary = {"earth":"당신의 다음 개척지", "technology":"가능성을 여는 기술", "robots":"당신의 자율 작업팀", "build":"행성 위에 그리는 미래", "planet":"오늘, 얼마나 달라졌나요", "journal":"미지의 세계가 남긴 것", "event":"발견 보고서", "settings":"나에게 맞는 원격 장비", "pause":"잠시, 연결을 멈췄습니다", "help":"한 걸음씩, 첫 행성부터", "cargo":"자원과 물류"}
	_label(column,"MISSION CONTROL  /  "+kind.to_upper(),11,MINT)
	_label(column,titles.get(kind,"원격 관제"),30)
	var line := HSeparator.new(); column.add_child(line)
	menu_scroll = ScrollContainer.new()
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(menu_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",16)
	menu_scroll.add_child(body)
	match kind:
		"earth": _earth_menu()
		"technology": _technology_menu()
		"build": _building_menu()
		"robots": _robots_menu()
		"planet": _planet_menu()
		"journal": _journal_menu()
		"event": _event_menu()
		"settings": _settings_menu()
		"help": _help_menu()
		"cargo": _cargo_menu()
		_: _pause_menu()
	menu_scroll.set_deferred("scroll_vertical",int(old_scroll))
	var bottom: HBoxContainer = _row(column)
	_label(bottom,"작업 화면에서는 시뮬레이션이 일시정지됩니다.",12,MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not campaign.planet.is_empty(): _primary(_button(bottom,"현장 복귀   ESC",_close_menu))
	else: _button(bottom,"시작 화면",func(): _show_menu("title"))
	menu.modulate.a = 0.3
	menu.create_tween().tween_property(menu,"modulate:a",1.0,0.16)

func _title_menu(column: VBoxContainer) -> void:
	_label(column,"L O C U S   /   01",14,MINT)
	var gap := Control.new(); gap.custom_minimum_size.y = 38; column.add_child(gap)
	_label(column,"우주\n비즈니스맨",56)
	_paragraph(column,"작은 위성 하나.\n당신의 첫 번째 우주 사업.",PAPER)
	_paragraph(column,"직접 채집하고, 로봇에게 맡기고,\n황무지에 새로운 내일을 만드세요.")
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(spacer)
	var solo_label: String="혼자 이어하기  →" if FileAccess.file_exists(FrontierCrewExpedition.selected_world_path(true)) or FileAccess.file_exists(FrontierCrewExpedition.selected_world_path(true)+".bak") else "혼자 게임 시작  →"
	_primary(_button(column,solo_label,func(): _start_expedition("solo"))).name="SoloStart"
	_button(column,"새 은하에서 혼자 시작",func(): _start_expedition("solo_new"))
	_button(column,"함께 플레이 · 최대 6명",func(): _start_expedition("multiplayer")).name="MultiplayerStart"
	_button(column,"설정 · 그래픽 / 시야거리 [F10]",func():FrontierClientSettings.ensure(get_tree()).open()).name="Settings"
	_button(column,"종료",_quit_game)
	_label(column,"혼자 플레이는 연결 설정 없이 바로 시작합니다.",12,MUTED)

func _start_expedition(mode: String) -> void:
	get_tree().set_meta("expedition_mode",mode)
	get_tree().change_scene_to_file("res://scenes/app/crew_expedition.tscn")

func _new_game() -> void:
	var error: String = campaign.new_campaign()
	if not error.is_empty(): toast(error); return
	_apply_settings()
	simulation = FrontierSimulation.new()
	sim_accumulator = 0
	save_time = 0
	world.rebuild({})
	selected_crew.clear()
	_show_menu("earth")

func _continue_game() -> void:
	if not campaign.load_campaign(): toast(campaign.store.last_error); return
	_apply_settings()
	simulation = FrontierSimulation.new()
	sim_accumulator = 0
	save_time = 0
	if not campaign.store.last_error.is_empty(): toast(campaign.store.last_error)
	world.rebuild(campaign.planet)
	if campaign.planet.is_empty(): _show_menu("earth")
	else: _close_menu()

func _close_menu() -> void:
	if campaign.planet.is_empty(): _show_menu("earth"); return
	if is_instance_valid(menu): menu.queue_free()
	screen = ""
	notification.offset_top = 82
	hud.visible = true
	world.controls_enabled = true
	world.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_hud()

func toast(text_value: String) -> void:
	notification.text = text_value
	notification_time = 4.5

func _act(error: String,success: String = "완료했습니다.") -> bool:
	toast(success if error.is_empty() else error)
	if error.is_empty():
		world.sync()
		if not screen.is_empty() and screen != "title": _show_menu(screen)
	return error.is_empty()

func _confirm(text_value: String,action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "작업 확인"
	dialog.dialog_text = text_value
	dialog.ok_button_text = "확정"
	dialog.cancel_button_text = "취소"
	ui.add_child(dialog)
	dialog.confirmed.connect(func(): action.call(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(460,180))

func _number(value: int) -> String:
	var raw: String = str(value)
	var result: String = ""
	for i in range(raw.length()):
		if i > 0 and (raw.length()-i)%3 == 0: result += ","
		result += raw[i]
	return result

func _buy_contract(kind: String) -> void:
	var error: String = campaign.buy_planet(kind,selected_crew)
	if not error.is_empty(): toast(error); return
	selected_crew.clear(); selected_recovery.clear()
	world.rebuild(campaign.planet)
	_close_menu()
	toast("원격 연결 완료 · 화면 왼쪽의 개척 가이드를 따라 시작하세요.")
	audio.play("ui_discovery")

func _earth_menu() -> void:
	if not campaign.planet.is_empty():
		var card: VBoxContainer = _card(body)
		var row: HBoxContainer = _row(card)
		var portrait := VBoxContainer.new(); portrait.custom_minimum_size.x = 260; row.add_child(portrait)
		_planet_portrait(portrait,campaign.planet.kind,190)
		var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(content)
		_label(content,"ACTIVE CONTRACT  /  운영 중",11,MINT)
		_label(content,campaign.planet.name,26)
		_paragraph(content,"현재 행성에서 자동화와 환경 개선을 진행하고 있습니다. 현지에서도 기술 연구와 수송 계약을 이용할 수 있습니다.")
		_primary(_button(content,"현장으로 연결  →",_close_menu))
		_button(content,"평가·판매 내역 보기",func(): _show_menu("planet"))
	else:
		if not campaign.state.last_report.is_empty():
			var report: Dictionary = campaign.state.last_report
			var summary: VBoxContainer = _card(body)
			_label(summary,"CONTRACT COMPLETE   /   "+report.grade,13,MINT)
			_label(summary,report.planet_name+" · 매각 완료",25)
			_paragraph(summary,"대금 %s Cr  ·  로봇 %d대 회수" % [_number(report.price),report.recovered])
		if campaign.profile.round == 0 and not show_all_planets:
			var card: VBoxContainer = _card(body)
			var row: HBoxContainer = _row(card)
			var image_column := VBoxContainer.new(); image_column.custom_minimum_size.x = 300; row.add_child(image_column)
			_planet_portrait(image_column,"basalt",230)
			var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(column)
			_label(column,"FIRST CONTRACT  /  첫 개척 추천",11,MINT)
			_label(column,"모래빛 위성에서 시작하세요",25)
			_paragraph(column,"기초 광물이 풍부한 작은 위성입니다. 원격 장비로 자원을 모으고 첫 로봇을 만드세요.")
			_paragraph(column,"01  직접 채집   →   02  첫 자동화   →   03  테라포밍",MINT)
			_primary(_button(column,"%s Cr  /  첫 행성 구매  →" % _number(FrontierCatalog.entry("planets","basalt").price),func(): _buy_contract("basalt")))
			_label(column,"계약 후 잔여 자금 %s Cr · 개척 가이드 제공" % _number(int(campaign.profile.credits)-int(FrontierCatalog.entry("planets","basalt").price)),12,MUTED)
			_button(body,"다른 행성도 살펴보기",func(): show_all_planets = true; _show_menu("earth"))
		else:
			var row: HBoxContainer = _row(body)
			for key in FrontierCatalog.table("planets"):
				var kind: String = key
				var definition: Dictionary = FrontierCatalog.entry("planets",kind)
				var card: VBoxContainer = _card(row)
				card.custom_minimum_size.x = 240
				_planet_portrait(card,kind,150)
				_label(card,definition.prefix+"  /  EXPLORATION",11,MINT)
				_label(card,definition.name,23)
				_paragraph(card,definition.description)
				_label(card,"%d°C  ·  독성 %d  ·  %.2f bar" % [definition.temperature,definition.toxicity,definition.pressure],12,MUTED)
				_primary(_button(card,"%s Cr  /  행성 구매" % _number(definition.price),func(): _buy_contract(kind),campaign.profile.credits < definition.price))
	if campaign.profile.round == 0 and campaign.planet.is_empty() and not show_all_planets: return
	var ship: Dictionary = FrontierCatalog.all().ships[int(campaign.profile.ship)]
	var transport: VBoxContainer = _card(body)
	_label(transport,"궤도 물류   /   " + ship.name,21)
	_paragraph(transport,"로봇 수송 %d슬롯  ·  궤도 회수 기술 %s" % [ship.slots,"보유" if campaign.has_tech("recovery") else "미보유"])
	if int(campaign.profile.ship) < 3:
		var upgrade: Dictionary = FrontierCatalog.all().ships[int(campaign.profile.ship)+1]
		_button(transport,"%s · %d슬롯으로 업그레이드  /  %s Cr" % [upgrade.name,upgrade.slots,_number(upgrade.price)],func(): _act(campaign.upgrade_ship(),"수송 계약을 업그레이드했습니다."),campaign.profile.credits < upgrade.price)
	if campaign.planet.is_empty() and not campaign.profile.hangar.is_empty():
		_label(body,"지구 보관소 · 다음 행성에 보낼 로봇",20)
		for robot in campaign.profile.hangar:
			var id: String = robot.id
			var checkbox := CheckBox.new()
			checkbox.text = "%s  /  %s  /  %s" % [robot.name,FrontierCatalog.entry("grades",robot.grade).name,_trait_text(robot)]
			checkbox.button_pressed = id in selected_crew
			checkbox.toggled.connect(func(on: bool):
				if on and id not in selected_crew: selected_crew.append(id)
				elif not on: selected_crew.erase(id))
			body.add_child(checkbox)
	_paragraph(body,"입문 추천: 첫 위성 구매 → 철·구리 채집 → 입문 로봇공학 구매 → 제작기·전력·충전기 건설 → 로봇 제작.")

func _technology_menu() -> void:
	_paragraph(body,"설계도는 다음 행성에도 남습니다. 지금 필요한 기술부터 선택하세요.")
	var visuals: Dictionary = {"robotics":"miner","atmosphere":"atmosphere","thermal":"thermal","water":"water","biotech":"biolab","recovery":"surveyor","analysis":"ruin","combat":"guardian","advanced":"surveyor","ancient":"reactor"}
	for rare in [false,true]:
		_label(body,"기초 연구" if not rare else "RARE EXCHANGE  /  희귀 연구",19,MINT)
		var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation",14); grid.add_theme_constant_override("v_separation",14); body.add_child(grid)
		for key in FrontierCatalog.table("technologies"):
			var id: String = key
			var definition: Dictionary = FrontierCatalog.entry("technologies",id)
			if definition.rare != rare: continue
			var card: VBoxContainer = _card(grid)
			card.custom_minimum_size.x = 370
			var row: HBoxContainer = _row(card)
			var picture := VBoxContainer.new(); picture.custom_minimum_size.x = 100; row.add_child(picture)
			_preview(picture,visuals[id],94)
			var text_column := VBoxContainer.new(); text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(text_column)
			var owned: bool = campaign.has_tech(id)
			_label(text_column,"연구 완료" if owned else ("희귀 설계도" if rare else "영구 설계도"),11,MINT if owned else MUTED)
			_label(text_column,definition.name,20)
			_paragraph(card,definition.description)
			if not definition.requires.is_empty() and not campaign.has_tech(definition.requires):
				_label(card,"선행 · "+FrontierCatalog.entry("technologies",definition.requires).name,12,ORANGE)
			elif rare and campaign.profile.round < 1: _label(card,"첫 행성 판매 후 거래 가능",12,ORANGE)
			var buy: Button = _button(card,"✓  연구 완료" if owned else "%s Cr · 연구 시작" % _number(definition.price),func(): _act(campaign.buy_technology(id),definition.name+" 연구 완료"),owned or campaign.profile.credits < definition.price or not campaign.has_tech(definition.requires) or (rare and campaign.profile.round < 1))
			if not owned: _primary(buy)

func _building_menu() -> void:
	if campaign.planet.is_empty(): _paragraph(body,"먼저 행성 계약을 시작하세요. 착륙 기지가 배치된 뒤 시설을 건설할 수 있습니다."); return
	var guide: Dictionary = FrontierOnboarding.current(campaign.state)
	if guide.get("id","") in ["solar","charger","factory"]:
		_paragraph(body,"지금 추천  ·  "+guide.title+"   /   "+guide.counter,MINT)
	else: _paragraph(body,"기지 보관함의 재료를 사용합니다. 배치 미리보기에서 위치를 정하고 설치하세요.")
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation",14); grid.add_theme_constant_override("v_separation",14); body.add_child(grid)
	var order: Array = ["solar","charger","factory","storage","atmosphere","thermal","water","biolab","reactor"]
	for key in order:
		var kind: String = key
		var definition: Dictionary = FrontierCatalog.entry("buildings",kind)
		var card: VBoxContainer = _card(grid)
		card.custom_minimum_size.x = 238
		_preview(card,kind,124)
		var unlocked: bool = campaign.has_tech(definition.tech)
		_label(card,"전력 +%d kW" % -definition.power if definition.power < 0 else "소비 전력 %d kW" % definition.power,11,MINT if definition.power < 0 else MUTED)
		_label(card,definition.name,19)
		_paragraph(card,definition.description)
		_resource_cost(card,_cost_status(definition.cost),MINT if FrontierCatalog.can_pay(campaign.planet.inventory,definition.cost) else ORANGE)
		if not unlocked: _label(card,FrontierCatalog.entry("technologies",definition.tech).name+" 필요",12,MUTED)
		var payable: bool = FrontierCatalog.can_pay(campaign.planet.inventory,definition.cost)
		var button: Button = _button(card,("배치 시작  →" if payable else "재료 부족") if unlocked else "설계도 필요",func(): _close_menu(); world.begin_build(kind),not unlocked or not payable)
		_primary(button)
	_label(body,"현재 시설 관리",22,MINT)
	for building in campaign.planet.buildings:
		if building.type == "base": continue
		var id: String = building.id
		var row: HBoxContainer = _row(_card(body))
		_label(row,"%s  /  %s" % [FrontierCatalog.entry("buildings",building.type).name,building.get("status","대기")],16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row,"정지" if building.enabled else "재가동",func(): _act(campaign.toggle_building(id)))
		_button(row,"철거·환불",func(): _confirm("시설을 철거하고 건설 재료를 보관함으로 반환합니다.",func(): _act(campaign.demolish(id),"시설을 철거했습니다.")))

func _resource_cost(parent: Node,source: String,color: Color) -> void:
	var readout:=FrontierResourceReadout.new()
	readout.custom_minimum_size.x=0
	readout.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	readout.add_theme_color_override("default_color",color)
	readout.value=source
	parent.add_child(readout)

func _cost_status(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in cost:
		parts.append("%s %d / %d" % [FrontierCatalog.entry("resources",key).name,campaign.planet.inventory.get(key,0),cost[key]])
	return " · ".join(parts)

func _craft_status(model: String) -> String:
	var definition: Dictionary = FrontierCatalog.entry("robots",model)
	if not campaign.has_tech(definition.tech): return "설계도 필요"
	var factories: Array = []
	for building in campaign.planet.buildings:
		if building.type == "factory": factories.append(building.id)
	if factories.is_empty(): return "제작기 건설 필요"
	for job in campaign.planet.jobs: factories.erase(job.factory_id)
	if factories.is_empty(): return "제작기 사용 중"
	if not FrontierCatalog.can_pay(campaign.planet.inventory,definition.cost): return "재료 부족"
	return ""

func _robots_menu() -> void:
	if campaign.planet.is_empty(): _paragraph(body,"행성에서 제작기를 건설하면 로봇을 제작할 수 있습니다. 회수한 로봇의 출발 편성은 사업 본부에서 설정하세요."); return
	_paragraph(body,"등급: 보급 70% · 개량 25% · 희귀 5%. 완성 시 등급과 특성이 공개되며 영구 보존됩니다.")
	_button(body,"보관함·초과 자원 관리",func(): _show_menu("cargo"))
	var models: HBoxContainer = _row(body)
	for key in FrontierCatalog.table("robots"):
		var model: String = key
		var definition: Dictionary = FrontierCatalog.entry("robots",model)
		var card: VBoxContainer = _card(models)
		card.custom_minimum_size.x = 238
		_preview(card,model,150)
		_label(card,definition.name,16)
		_resource_cost(card,_cost_status(definition.cost),MINT if FrontierCatalog.can_pay(campaign.planet.inventory,definition.cost) else ORANGE)
		_paragraph(card,"제작 %d초  /  %s" % [definition.seconds,"채광·운반 자동화" if definition.role == "miner" else "문명 작전·기지 경비"])
		var reason: String = _craft_status(model)
		_primary(_button(card,"제작 주문  →" if reason.is_empty() else reason,func(): _act(campaign.craft(model),"제작을 시작했습니다. 현장으로 돌아가면 시간이 진행됩니다."),not reason.is_empty()))
	for job in campaign.planet.jobs:
		var id: String = job.id
		var row: HBoxContainer = _row(_card(body))
		_label(row,"제작 중  %s   %.0f / %.0f초" % [FrontierCatalog.entry("robots",job.model).name,job.progress,job.seconds],16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row,"취소·재료 반환",func(): _act(campaign.cancel_craft(id)))
	_label(body,"현지 로봇  /  %d대" % campaign.planet.robots.size(),22,MINT)
	for robot in campaign.planet.robots:
		var id: String = robot.id
		var column: VBoxContainer = _card(body)
		var row: HBoxContainer = _row(column)
		var grade: Dictionary = FrontierCatalog.entry("grades",robot.grade)
		_label(row,"%s  ·  %s" % [robot.name,grade.name],20,Color(grade.color)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(row,"배터리 %.0f%%  /  내구 %.0f%%" % [robot.battery,robot.health],14,MUTED)
		_paragraph(column,"%s   /   %s   /   화물 %d" % [_trait_text(robot),robot.status,FrontierCatalog.total(robot.cargo)])
		var actions: HBoxContainer = _row(column)
		if FrontierCatalog.entry("robots",robot.model).role == "miner":
			var option := OptionButton.new()
			option.custom_minimum_size = Vector2(180,42)
			option.add_item("모든 자원")
			var keys: Array = FrontierCatalog.table("resources").keys()
			for key in keys: option.add_icon_item(FrontierResourceIcons.menu_texture(key),FrontierCatalog.entry("resources",key).name)
			option.selected = 0 if robot.filter == "all" else keys.find(robot.filter)+1
			option.item_selected.connect(func(index: int): _act(campaign.assign_robot(id,"all" if index == 0 else keys[index-1]),"작업 대상을 변경했습니다."))
			actions.add_child(option)
		_button(actions,"기지 회수·수리",func(): _act(campaign.rescue_robot(id),"수동장비 구조 서비스로 로봇을 복구했습니다."))
		_button(actions,"작업 정지" if robot.enabled else "작업 재개",func(): _act(campaign.toggle_robot(id)))

func _trait_text(robot: Dictionary) -> String:
	var names: PackedStringArray = []
	for key in robot.traits: names.append(FrontierCatalog.entry("traits",key).name)
	return " · ".join(names)

func _planet_menu() -> void:
	if campaign.planet.is_empty(): _paragraph(body,"평가할 활성 행성이 없습니다. 사업 본부에서 다음 행성을 선택하세요."); return
	var p: Dictionary = campaign.planet
	var report: Dictionary = FrontierEvaluator.report(p,selected_recovery)
	var header: HBoxContainer = _row(_card(body))
	_label(header,report.grade,68,MINT)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(column)
	_label(column,"%s   /   적합도 %.1f" % [p.name,report.score],25)
	_paragraph(column,"예상 매각 대금  %s Cr" % _number(report.price),PAPER)
	if report.restricted: _paragraph(column,"B등급 이상에는 대기·온도·물 각각 60 이상, 120초 안정화가 필요합니다.",ORANGE)
	var names: Dictionary = {"atmosphere":"대기 적합도", "temperature":"온도 적합도", "water":"수자원", "ecology":"생태 정착", "stability":"안정성"}
	for key in names:
		var row: HBoxContainer = _row(body)
		_label(row,names[key],16).custom_minimum_size.x = 140
		var progress := ProgressBar.new()
		progress.value = report.scores[key]
		progress.custom_minimum_size = Vector2(100,22)
		progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(progress)
		_label(row,"%.1f" % report.scores[key],16,MINT).custom_minimum_size.x = 60
	_paragraph(body,"기본 환경 가치 %s  +  잔존 시설·로봇 %s  +  발견 가치 %s  −  정리 비용 %s  ×  문명 계수 %.2f" % [_number(report.base),_number(report.residual),_number(report.discoveries),_number(report.cleanup),report.civilization])
	_label(body,"회수 로봇 선택  /  %d대 중 %d슬롯" % [selected_recovery.size(),campaign.ship_slots()],21,MINT)
	if not campaign.has_tech("recovery"): _paragraph(body,"궤도 회수 기술과 수송 슬롯을 구매하면 로봇을 다음 행성에 데려갈 수 있습니다.")
	for robot in p.robots:
		var id: String = robot.id
		var checkbox := CheckBox.new()
		checkbox.text = "%s  /  %s  /  %s" % [robot.name,FrontierCatalog.entry("grades",robot.grade).name,_trait_text(robot)]
		checkbox.disabled = not campaign.has_tech("recovery")
		checkbox.button_pressed = id in selected_recovery
		checkbox.toggled.connect(func(on: bool):
			if on and id not in selected_recovery: selected_recovery.append(id)
			elif not on: selected_recovery.erase(id)
			_show_menu("planet"))
		body.add_child(checkbox)
	_paragraph(body,"회수하지 않은 시설·로봇·현지 자원은 행성에 남습니다. 진행 중인 제작은 재료를 반환하고 종료합니다. 판매 후에는 이 행성에 다시 접근할 수 없습니다.")
	var planet_id: String = p.id
	_button(body,"%s Cr에 판매 · 사업 정산" % _number(report.price),func():
		_confirm("%s을 %s Cr에 판매합니다.\n선택한 로봇 %d대만 회수하며 나머지 현지 자산은 행성에 남습니다." % [p.name,_number(report.price),selected_recovery.size()],func():
			var error: String = campaign.sell_planet(planet_id,selected_recovery)
			if not error.is_empty(): toast(error); return
			selected_recovery.clear()
			world.end_build()
			world.rebuild({})
			_show_menu("earth")
			audio.play("ui_planet_sold")
			toast("행성 매각 완료. 다음 개척을 준비하세요.")),selected_recovery.size() > campaign.ship_slots() or not p.conflict.is_empty())

func _journal_menu() -> void:
	if campaign.planet.is_empty():
		_paragraph(body,"영구 도감에 기록한 발견: %d종. 새 행성에서 이상 신호를 조사하면 발견 기록이 추가됩니다." % campaign.profile.codex.size())
		var codex_names: Dictionary = {"ruin":"고대 문명의 잔해 · 보존, 유물 반출, 기술 분석", "microbe":"황산 적응 미생물 · 산소 생성력 55, 활동 온도 −45~90°C", "animal":"모슬링 · 생태 정착을 돕는 야생동물", "civilization":"지적 문명 · 보호 또는 전투 작전의 대상"}
		for key in campaign.profile.codex: _paragraph(_card(body),codex_names[key],PAPER)
		_label(body,"사업 정산 이력",22,MINT)
		for report in campaign.profile.history:
			_paragraph(_card(body),"%s  ·  %s등급  ·  매각 %s Cr  ·  순현금 변화 %s Cr  ·  %d대 회수" % [report.planet_name,report.grade,_number(report.price),_number(report.profit),report.recovered],PAPER)
		return
	var names: Dictionary = {"ruin":"고대 문명의 잔해", "microbe":"황산 적응 미생물", "animal":"야생동물 · 모슬링", "civilization":"지적 문명의 거주지"}
	_paragraph(body,"레이더의 보라색 원은 이상 신호입니다. 현장에서 접근해 E로 스캔하면 선택 가능한 행동이 공개됩니다.")
	for event in campaign.planet.events:
		var id: String = event.id
		var row: HBoxContainer = _row(_card(body))
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		_label(column,names[event.kind] if event.discovered else "미확인 이상 신호",21)
		var distance: float = FrontierCampaign.point(event.position).distance_to(FrontierCampaign.point(campaign.planet.player.position))
		_paragraph(column,"위치 [%d, %d]  ·  %.0fm" % [event.position[0],event.position[1],distance])
		if not event.choice.is_empty(): _paragraph(column,event.reward,MINT)
		_button(row,"보고서 열기",func(): selected_event = id; _show_menu("event"),not event.discovered)

func _event_menu() -> void:
	var event: Dictionary = FrontierCampaign.find_by_id(campaign.planet.get("events",[]),selected_event)
	if event.is_empty(): _paragraph(body,"발견 기록을 찾을 수 없습니다."); return
	var stories: Dictionary = {
		"ruin":["신호 #01 / 오래된 약속","먼지 아래 드러난 기둥에는 인류의 기록보다 오래된 문양이 새겨져 있습니다. 아직 에너지가 남아 있는 중심부에서 반복되는 신호가 들립니다."],
		"microbe":["신호 #02 / 불가능한 생명","황산 대기에서도 살아가는 미생물 군집입니다. 산소 생성력 55. 온도 −45~90°C에서 활동하며 독성을 낮추고 대기를 바꿀 수 있습니다."],
		"animal":["신호 #03 / 작은 동행자","둥근 귀를 가진 모슬링이 장비의 발자국을 따라옵니다. 물과 온화한 환경이 갖춰지면 생태 정착을 돕습니다. 지구의 수집가도 관심을 보입니다."],
		"civilization":["신호 #04 / 우리가 먼저가 아니었다","이 행성에는 이미 지적 문명이 살아가고 있습니다. 그들은 원격장비를 바라보고 신호를 보냅니다. 지금의 선택은 이 행성의 미래와 판매 가치에 남습니다."]}
	_label(body,stories[event.kind][0],26,MINT)
	_paragraph(body,stories[event.kind][1],PAPER)
	if not event.choice.is_empty():
		_label(body,"확정된 결과",20)
		_paragraph(body,event.reward,MINT)
		if event.choice.ends_with("_pending"): _paragraph(body,"문명 방어력: %.0f%%. 현장으로 돌아가면 경비로봇이 작전을 진행합니다." % event.health)
		_button(body,"발견 목록",func(): _show_menu("journal"))
		return
	var choices: Dictionary = {
		"ruin":[["preserve","유적 보존","행성 판매 가치 +1,600 Cr. 유적을 현지에 남깁니다."],["extract","유물 반출·판매","지구로 반출하여 1,800 Cr를 받습니다. 행성 잔존 가산은 사라집니다."],["analyze","고대 기술 분석","분석 기술 필요. 고대 에너지 코어 기술을 해독합니다."]],
		"microbe":[["cultivate","배양·환경 정착","독성 감소와 산소 생성을 시작합니다."],["observe","관찰 기록만 남기기","원래의 군집을 유지하고 도감에 기록합니다."]],
		"animal":[["protect","서식지 보호","물·온도 조건 충족 시 생태 정착 촉진. 행성 가치 +800 Cr."],["capture","지구 반출·판매","모슬링을 반출하여 900 Cr를 받습니다. 현지 생태 효과는 얻지 못합니다."]],
		"civilization":[["protect","살려두기·보호","무작위 기술 또는 보물을 받습니다. 행성 판매 단가가 55% 하락합니다."],["destroy","전투 AI로 파괴","경비로봇이 필요합니다. 전투·수리 부담과 정리 비용 600 Cr가 발생합니다."],["enslave","노예화·강제 통제","경비로봇이 필요합니다. 작전 완료 후 채광 +20%, 행성 판매 가치 −20%."]]}
	for item in choices[event.kind]:
		var choice: String = item[0]
		var card: VBoxContainer = _card(body)
		_label(card,item[1],20)
		_paragraph(card,item[2])
		_button(card,"선택 확정",func(): _confirm("이 선택은 되돌릴 수 없습니다.\n" + str(item[2]),func(): _act(campaign.choose_event(selected_event,choice),"발견 결과를 기록했습니다.")))

func _settings_menu() -> void:
	var graphics_card: VBoxContainer = _card(body)
	_label(graphics_card,"그래픽 품질",22,MINT)
	var graphics_choice := OptionButton.new()
	graphics_choice.name = "GraphicsQuality"
	graphics_choice.custom_minimum_size.y = 42
	var graphics_keys: Array = FrontierGraphics.data().profiles.keys()
	var current_quality: String = FrontierGraphics.resolve(str(campaign.profile.settings.get("graphics","balanced")))
	for key in graphics_keys: graphics_choice.add_item(FrontierGraphics.data().profiles[key].name)
	graphics_choice.select(graphics_keys.find(current_quality))
	graphics_card.add_child(graphics_choice)
	var quality_detail: Label = _paragraph(graphics_card,FrontierGraphics.data().profiles[current_quality].description)
	graphics_choice.item_selected.connect(func(index: int):
		var key: String = graphics_keys[index]
		campaign.profile.settings.graphics = key
		world.apply_graphics(key)
		quality_detail.text = FrontierGraphics.data().profiles[key].description
		toast("그래픽 품질을 적용했습니다. 설정·진행 저장으로 보관할 수 있습니다."))
	_paragraph(graphics_card,"즉시 적용됩니다. 화면이 끊기면 ‘균형’ 또는 ‘성능 우선’으로 낮추세요. UI 해상도는 유지됩니다.",MUTED)
	_paragraph(body,"수동장비 조작: WASD 이동 · Shift 질주 · Space 점프 · 마우스 시점 · 좌클릭 연속 채광 · E 스캔/반납")
	_paragraph(body,"건설: B 목록 · 마우스 위치 선택 · Q 회전 · 좌클릭 설치 · 우클릭 취소. V는 현장 전체를 보는 관찰 카메라입니다.")
	_label(body,"마우스 감도",20)
	var slider := HSlider.new()
	slider.min_value = 0.0008
	slider.max_value = 0.006
	slider.step = 0.0001
	slider.value = campaign.profile.settings.sensitivity
	slider.custom_minimum_size.y = 36
	slider.value_changed.connect(func(value: float): campaign.profile.settings.sensitivity = value)
	body.add_child(slider)
	_label(body,"전체 음량",20)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = campaign.profile.settings.volume
	volume.custom_minimum_size.y = 36
	volume.value_changed.connect(func(value: float):
		campaign.profile.settings.volume = value
		AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,0.001)))
		AudioServer.set_bus_mute(0,value <= 0))
	body.add_child(volume)
	var fullscreen := CheckBox.new()
	fullscreen.text = "전체 화면"
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(value: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		campaign.profile.settings.fullscreen = value)
	body.add_child(fullscreen)
	_button(body,"설정·진행 저장",func(): _act(campaign.save(),"저장했습니다."))
	_label(body,"키 설정  ·  ESC 취소 / 마우스 좌·우클릭 고정",20)
	for action in FrontierInput.DEFAULTS:
		var key: String = action
		var row: HBoxContainer = _row(body)
		_label(row,FrontierInput.LABELS[key]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button(row,FrontierInput.text(key),func(): binding_target = key; toast("새 키를 누르세요. ESC로 취소합니다."))
	_button(body,"기본 키 설정 복원",func(): campaign.profile.settings.erase("bindings"); FrontierInput.apply(campaign.profile.settings); _show_menu("settings"))
	_paragraph(body,"저장 위치: " + ProjectSettings.globalize_path("user://campaign.json"))

func _apply_settings() -> void:
	var settings: Dictionary = campaign.profile.settings
	FrontierInput.apply(settings)
	if is_instance_valid(world): world.apply_graphics(str(settings.get("graphics","balanced")))
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(settings.volume,0.001)))
	AudioServer.set_bus_mute(0,settings.volume <= 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _help_menu() -> void:
	var guide: Dictionary = FrontierOnboarding.current(campaign.state)
	var enabled: bool = campaign.profile.get("onboarding",{}).get("enabled",false)
	var guide_card: VBoxContainer = _card(body)
	_label(guide_card,"개척 가이드",23,MINT)
	_paragraph(guide_card,"실제 이동·채집·반납·건설·자동 운반을 확인해 다음 단계로 안내합니다. 순서는 강제하지 않으며, 진행도는 사업 기록에 함께 저장됩니다.")
	_button(guide_card,"가이드 숨기기" if enabled else "가이드 켜기",func(): _act(campaign.set_guide(not enabled),"개척 가이드 설정을 변경했습니다."))
	if not guide.is_empty():
		_label(guide_card,"지금 할 일  /  "+guide.title,20)
		_paragraph(guide_card,guide.detail,PAPER)
		var page: String = guide.menu
		if page != "help": _primary(_button(guide_card,"해당 화면으로 이동  →",func(): _show_menu(page)))
	var completed: Array = campaign.profile.get("onboarding",{}).get("completed",[])
	for i in range(FrontierOnboarding.STEPS.size()):
		var done: bool = FrontierOnboarding.STEPS[i] in completed
		var row: HBoxContainer = _row(_card(body))
		_label(row,"✓" if done else "%02d" % (i+1),22,MINT if done else MUTED).custom_minimum_size.x = 42
		var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(col)
		_label(col,FrontierOnboarding.TITLES[i],17,MINT if done else PAPER)
		_paragraph(col,FrontierOnboarding.DESCRIPTIONS[i])
	_label(body,"M-02 도구 운용",22,MINT)
	_paragraph(body,"좌클릭 유지: 광물 흡입. 우클릭: 펄스 파쇄·사격. 과열되면 잠시 냉각해야 합니다. 펄스는 가까운 광물을 파쇄하고, 승인된 문명 작전에 화력을 보탭니다. 중립 발견에는 피해를 주지 않습니다.")

	var lessons: Array = [
		["01  원격 연결","당신은 지구에서 수동장비를 조종합니다. 마우스로 둘러보고 이동 키로 광맥에 접근하세요. 좌클릭을 누르면 채광합니다. 화물 한도는 140이며 기지·보관함 근처에서 상호작용 키로 반납합니다."],
		["02  첫 작업팀","기술 상점에서 입문 로봇공학을 구매하세요. 태양광 발전기 → 충전 패드 → 로봇 제작기를 건설한 뒤 로봇 메뉴에서 채광로봇을 주문합니다. 철 100·구리 10이 필요하며 현장에서 18초 후 출고됩니다."],
		["03  자동화 관리","로봇 메뉴에서 자원을 지정할 수 있습니다. 배터리가 부족하면 전력이 공급되는 충전기로 복귀합니다. 보관함 포화 시 저장고를 확장하고, 경로가 막히거나 장비가 파손되면 기지 회수·수리를 사용하세요."],
		["04  행성을 바꾸는 설비","대기·온도·물·생태 기술과 설비를 준비하세요. 발전량이 수요보다 커야 모두 가동됩니다. 물 순환기는 얼음을 소비하고 생태 배양기는 대기·온도·물이 개선된 뒤 작동합니다. 시설 관리에서 대기 이유를 확인할 수 있습니다."],
		["05  발견과 매각","보라색 레이더 신호에 접근해 조사하세요. 발견마다 보상과 행성 가치가 달라집니다. 대기·온도·물 적합도 각각 60 이상을 120초 유지하면 B등급 이상이 가능합니다. 평가 메뉴에서 가격 내역을 확인하고 판매합니다."],
		["06  다음 사업","궤도 회수 기술과 우주선 슬롯을 구매하면 판매 전에 로봇을 선택해 지구로 회수할 수 있습니다. 다음 행성 구매 전 보관소에서 출발 로봇을 선택하세요. 기술은 영구 보유하고 로봇 등급·특성은 유지됩니다."],
		["저장과 복구","메뉴를 열면 시간이 멈춥니다. 현장에서는 60초마다 자동 저장하며 중요한 구매·제작 완료·매각도 저장합니다. 진행이 막히면 일시정지 메뉴의 사업 안전 시작점으로 복구할 수 있습니다. 현재 회차의 진행은 되돌아갑니다."]]
	for lesson in lessons:
		var card: VBoxContainer = _card(body)
		_label(card,lesson[0],21,MINT)
		_paragraph(card,lesson[1],PAPER)

func _cargo_menu() -> void:
	if campaign.planet.is_empty(): return
	_label(body,"공유 보관함  %d / %d" % [FrontierCatalog.total(campaign.planet.inventory),campaign.capacity()],23,MINT)
	_paragraph(body,"보관함이 가득 차면 저장고를 건설하거나 남는 자원을 폐기하세요. 로봇 메뉴에서 다른 자원을 지정하면 한 자원만 쌓이는 것을 줄일 수 있습니다.")
	for key in FrontierCatalog.table("resources"):
		var resource: String = key
		var amount: int = campaign.planet.inventory.get(key,0)
		var row: HBoxContainer = _row(_card(body))
		row.add_child(FrontierResourceIcons.view(key))
		_label(row,"%s  %d" % [FrontierCatalog.entry("resources",key).name,amount],20).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var removed: int = mini(100,amount)
		_button(row,"%d개 폐기" % removed,func(): _confirm("%s %d개를 폐기합니다. 되돌릴 수 없습니다." % [FrontierCatalog.entry("resources",resource).name,removed],func(): _act(campaign.discard_inventory(resource,removed),"보관 공간을 확보했습니다.")),amount == 0)

func _pause_menu() -> void:
	_paragraph(body,"메뉴를 연 동안 시뮬레이션은 일시정지됩니다. F5로 빠르게 저장할 수 있습니다.")
	_button(body,"조작·사업 도움말",func(): _show_menu("help"))
	if not campaign.planet.is_empty(): _button(body,"보관함·초과 자원 관리",func(): _show_menu("cargo"))
	_button(body,"진행 저장",func(): _act(campaign.save(),"현재 진행을 저장했습니다."))
	_button(body,"마지막 저장 불러오기",func(): _confirm("저장 이후 진행은 사라집니다.",_continue_game))
	_button(body,"사업 안전 시작점으로 복구",func(): _confirm("현재 회차의 진행·구매·보상을 모두 되돌리고 마지막 지구 출발 전 상태로 복구합니다.",func():
		var error: String = campaign.restart_business()
		if not error.is_empty(): toast(error); return
		_apply_settings()
		simulation = FrontierSimulation.new()
		sim_accumulator = 0
		selected_crew.clear()
		selected_recovery.clear()
		world.end_build()
		world.rebuild({})
		_show_menu("earth")))
	_button(body,"저장하고 종료",_quit_game)

func _process(delta: float) -> void:
	notification_time = maxf(0,notification_time-delta)
	notification.visible = notification_time > 0
	if screen.is_empty() and not campaign.planet.is_empty():
		sim_accumulator += minf(delta,0.25)
		while sim_accumulator >= 0.1:
			simulation.step(campaign,0.1)
			sim_accumulator -= 0.1
		save_time += delta
		if save_time >= 60:
			save_time = 0
			var error: String = campaign.save()
			if not error.is_empty(): toast(error)
		mine_time -= delta
		pulse_time = maxf(0,pulse_time-delta)
		tool_heat = maxf(0,tool_heat-delta*float(FrontierCatalog.all().manual_tool.cooling_per_second))
		if overheated and tool_heat <= float(FrontierCatalog.all().manual_tool.restart_heat): overheated = false
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): suppress_pulse = false
		if not world.orbit_mode and world.build_kind.is_empty():
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not suppress_pulse and pulse_time <= 0: _fire_pulse()
			elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mine_time <= 0:
				mine_time = float(FrontierCatalog.all().manual_tool.mine_interval)
				if world.target.get("kind","") == "resource": _mine_target(world.target,int(FrontierCatalog.all().manual_tool.mine_amount))
		audio.set_suction(world.suction_strength)
	else: audio.set_suction(0)
	refresh_time += delta
	if refresh_time >= 0.25:
		refresh_time = 0
		world.sync()
		audio.update_world(campaign.planet,not screen.is_empty())
		if screen.is_empty(): _update_hud()

func _update_hud() -> void:
	if campaign.planet.is_empty(): return
	FrontierOnboarding.sync(campaign.state)
	if hud is FrontierFlightHUD: hud.refresh()

func _on_changed() -> void:
	if is_instance_valid(world): world.sync()
	if is_instance_valid(hud) and screen.is_empty(): _update_hud()

func _input(event: InputEvent) -> void:
	if binding_target.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		binding_target = ""
		toast("키 변경을 취소했습니다.")
		return
	var error: String = FrontierInput.rebind(campaign.profile.settings,binding_target,event.physical_keycode)
	if not error.is_empty(): toast(error); return
	binding_target = ""
	_show_menu("settings")
	toast("키를 변경했습니다. 설정·진행 저장으로 보존하세요.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if screen == "title": return
			if not world.build_kind.is_empty(): world.end_build()
			elif screen.is_empty(): _show_menu("pause")
			elif not campaign.planet.is_empty(): _close_menu()
			return
		if not screen.is_empty(): return
		for key in ["build","robots","technology","journal","planet","help"]:
			if FrontierInput.matches(event,key): _show_menu(key); return
		if FrontierInput.matches(event,"camera"): world.toggle_camera()
		elif FrontierInput.matches(event,"rotate"): world.build_rotation = (world.build_rotation+90)%360
		elif FrontierInput.matches(event,"save"): toast("저장 완료" if campaign.save().is_empty() else campaign.store.last_error)
		elif FrontierInput.matches(event,"interact"): _interact()
	if screen.is_empty() and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and not world.build_kind.is_empty():
			suppress_pulse = true
			world.end_build()
		elif event.button_index == MOUSE_BUTTON_LEFT and not world.build_kind.is_empty():
			var error: String = campaign.build(world.build_kind,world.ghost_location,world.build_rotation)
			toast("시설을 건설했습니다." if error.is_empty() else error)
			audio.play("sfx_build_place" if error.is_empty() else "sfx_build_invalid")
			if error.is_empty():
				world.building_feedback(world.ghost_location)
				world.end_build()

func _interact() -> void:
	var target: Dictionary = world.target
	if target.is_empty():
		var error: String = campaign.deposit()
		if error.is_empty(): toast("화물을 반납했습니다.")
		return
	match target.kind:
		"resource": _mine_target(target,int(FrontierCatalog.all().manual_tool.mine_amount))
		"building":
			var b: Dictionary = FrontierCampaign.find_by_id(campaign.planet.buildings,target.id)
			if b.type in ["base","storage"]:
				if _act(campaign.deposit(),"화물을 기지 보관함에 반납했습니다."): audio.play("sfx_pickup_resource")
			else: _show_menu("build")
		"event":
			var error: String = campaign.discover(target.id)
			if not error.is_empty(): toast(error); return
			selected_event = target.id
			audio.play("ui_discovery")
			_show_menu("event")

func _mine_target(target: Dictionary,amount: int) -> void:
	var node: Dictionary = FrontierCampaign.find_by_id(campaign.planet.nodes,target.id)
	if node.is_empty(): return
	var before: int = node.amount
	var point: Vector3 = target.position
	var error: String = campaign.mine(target.id,amount)
	if not error.is_empty(): toast(error); return
	var collected: int = before-int(node.amount)
	world.mining_feedback(target.id,point,node.resource,collected,node.amount <= 0)
	hud.feedback(node.resource,collected)
	audio.play("sfx_mine_hit_metal",point)
	if node.amount <= 0: audio.play("sfx_mine_break",point)

func _fire_pulse() -> void:
	if overheated:
		pulse_time = 0.4
		toast("도구 냉각 중 · 잠시 발사를 멈추세요.")
		return
	pulse_time = float(FrontierCatalog.all().manual_tool.pulse_interval)
	tool_heat = minf(100,tool_heat+float(FrontierCatalog.all().manual_tool.pulse_heat))
	overheated = tool_heat >= 100
	var hit: Dictionary = world.ray_hit(float(FrontierCatalog.all().manual_tool.pulse_range))
	var destination: Vector3 = world.camera.global_position-world.camera.global_basis.z*float(FrontierCatalog.all().manual_tool.pulse_range)
	var target_id: String = ""
	if not hit.is_empty():
		destination = hit.position
		if hit.collider.has_meta("id"): target_id = hit.collider.get_meta("id")
		var kind: String = hit.collider.get_meta("kind","")
		if kind == "resource": _mine_target({"id":target_id,"position":destination},int(FrontierCatalog.all().manual_tool.pulse_amount))
		elif kind == "event" and target_id == campaign.planet.conflict:
			var error: String = campaign.pulse_attack(target_id)
			if not error.is_empty(): toast(error)
			else: hud.hit_time = 0.22
	world.fire_feedback(destination,target_id)
	audio.play("sfx_combat_pulse")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: _quit_game()

func _quit_game() -> void:
	if quitting: return
	if not smoke_mode and screen != "title":
		var error: String = campaign.save()
		if not error.is_empty(): toast(error); return
	_shutdown()

func _shutdown() -> void:
	quitting = true
	hud.visible = false
	hud.set_process(false)
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	var tree: SceneTree = get_tree()
	world.controls_enabled = false
	world.queue_free()
	audio.queue_free()
	await tree.process_frame
	await tree.process_frame
	await tree.create_timer(0.15).timeout
	tree.quit()

func _smoke_setup() -> void:
	campaign.persistence_enabled = false
	campaign.new_campaign()
	simulation = FrontierSimulation.new()
	sim_accumulator = 0
	campaign.profile.onboarding.enabled = false
	campaign.buy_planet("basalt")
	for key in ["robotics","atmosphere","thermal","water","biotech","recovery"]: campaign.buy_technology(key)
	campaign.planet.inventory = {"iron":2000,"copper":800,"stone":800,"ice":500,"crystal":30}
	for entry in [["solar",Vector2(8,6)],["solar",Vector2(15,6)],["factory",Vector2(-8,5)],["charger",Vector2(-4,9)],["atmosphere",Vector2(-7,-5)],["water",Vector2(7,-5)],["thermal",Vector2(0,-10)],["biolab",Vector2(12,12)]]:
		var error: String = campaign.build(entry[0],entry[1])
		if not error.is_empty(): push_warning("Smoke setup %s: %s" % [entry[0],error])
	simulation.step(campaign,0.1)
	campaign.craft("miner")
	for i in range(220): simulation.step(campaign,0.1)
	world.rebuild(campaign.planet)
	_close_menu()
	world.toggle_camera()
	world.orbital_camera.position = Vector3(23,19,29)
	world.orbital_camera.look_at(Vector3(0,0,-3))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			var path: String = argument.trim_prefix("--capture=")
			get_tree().create_timer(4).timeout.connect(func():
				get_viewport().get_texture().get_image().save_png(path)
				print("SMOKE_CAPTURE ",path)
				_quit_game())
