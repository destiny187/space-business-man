class_name FrontierSurveyJournal
extends HBoxContainer
var app: FrontierCrewExpedition
var grid: GridContainer
var details: VBoxContainer
var detail_column: VBoxContainer
var preview: FrontierEquipmentPreview
var search: LineEdit
var category: OptionButton
var location: OptionButton
var caption: Label
var previous: Button
var next: Button
var page_index:=0
var serial:=0
var selected_entry: Dictionary={}
var last_signature:=""
var query_delay:=0.0
var was_visible:=false
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",18)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;add_child(list)
	search=LineEdit.new();search.placeholder_text="발견한 이름 검색";search.clear_button_enabled=true;search.max_length=100;list.add_child(search)
	search.text_changed.connect(func(_s):page_index=0;query_delay=.25)
	var filters:=HBoxContainer.new();list.add_child(filters)
	category=OptionButton.new();filters.add_child(category)
	for title in ["전체","광물  보석","생물","탐험 장소","현장 사건","기업"]:category.add_item(title)
	location=OptionButton.new();filters.add_child(location)
	for title in ["전체 발견","현재 행성"]:location.add_item(title)
	for option in [category,location]:option.item_selected.connect(func(_i):page_index=0;refresh())
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.add_child(scroll)
	grid=GridContainer.new();grid.columns=3;scroll.add_child(grid)
	var pages:=HBoxContainer.new();list.add_child(pages)
	previous=Button.new();previous.text="‹";pages.add_child(previous);previous.pressed.connect(func():page_index-=1;refresh())
	caption=FrontierInterfaceStyle.label(pages,"",12);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	next=Button.new();next.text="›";pages.add_child(next);next.pressed.connect(func():page_index+=1;refresh())
	var reload:=Button.new();reload.text="↻";reload.tooltip_text="발견 기록 새로고침";pages.add_child(reload);reload.pressed.connect(refresh)
	detail_column=VBoxContainer.new();detail_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_column.custom_minimum_size.x=320;add_child(detail_column)
	var detail_scroll:=ScrollContainer.new();detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;detail_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;detail_column.add_child(detail_scroll)
	var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(content)
	preview=FrontierEquipmentPreview.new();preview.custom_minimum_size.y=120;content.add_child(preview);preview.hide()
	details=VBoxContainer.new();content.add_child(details)
	app.session.discoveries_received.connect(_receive)
func _process(delta: float) -> void:
	if not is_visible_in_tree():was_visible=false;return
	grid.columns=clampi(int((get_viewport_rect().size.x-132)/2/92),1,6)
	var signature:=str(app.session.latest.get("discoveries",{}))+str(app.session.latest.get("coopertech_clues",{}))+str(app.session.latest.get("location",""))+str(app.session.latest.get("crew",{}).get("survey",{}))+str(app.session.latest.get("crew",{}).get("corporations",{}))+str(app.session.latest.get("crew",{}).get("corporate_traces",{}))+str(app.session.latest.get("crew",{}).get("freight_records",{}))+str(app.session.surface.get("ecology",{}).get("observations",{}))
	if not was_visible or signature!=last_signature:last_signature=signature;refresh()
	was_visible=true
	if query_delay>0:
		query_delay-=delta
		if query_delay<=0:refresh()
func refresh() -> void:
	serial+=1
	app.session.request_discoveries(serial,search.text,["all","mineral","biology","discovery","incident","corporation"][category.selected],str(app.session.latest.get("location","")) if location.selected==1 else "",page_index)
func _receive(reply_serial: int,value: Dictionary) -> void:
	if reply_serial!=serial:return
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	page_index=int(value.page)
	caption.text="%d개  %d / %d"%[int(value.total),page_index+1,maxi(1,ceili(float(value.total)/24))]
	previous.disabled=page_index==0;next.disabled=(page_index+1)*24>=int(value.total)
	var retained: Dictionary={}
	for entry in value.entries:
		var tile:=FrontierItemTile.new();tile.picture=load("res://assets/ui/discoveries/"+str(entry.row.template)+".png") if entry.kind in ["discovery","incident"] and ResourceLoader.exists("res://assets/ui/discoveries/"+str(entry.row.template)+".png") else FrontierResourceIcons.texture(entry.icon)
		if entry.kind=="incident" and entry.row.has("native"):tile.picture=FrontierResourceIcons.texture(FrontierResourceIcons.specimen_id(FrontierEcologyCatalog.form(entry.row.native.form_id)))
		if entry.kind=="corporation":tile.picture=load(FrontierCorporations.icon_path(entry.company))
		if entry.kind=="freight_incident":tile.picture=load(FrontierFreightSalvage.icon(entry.row.id));tile.amount="%d / %d"%[int(entry.row.stage),FrontierFreightSalvage.last_stage(entry.row.id)]
		if entry.kind=="coopertech_clue":tile.picture=load(FrontierCorporations.icon_path("coopertech"));tile.amount="%d / 2"%int(entry.row.stage)
		if entry.kind=="corporate_trace":tile.picture=load("res://assets/ui/corporations/trace_"+str(entry.company)+".png");tile.amount="%d / 2"%int(entry.row.stage)
		tile.caption=entry.name;tile.tooltip_text=entry.name;tile.set_meta("key",entry.key);grid.add_child(tile)
		tile.pressed.connect(func():select(entry))
		if entry.key==selected_entry.get("key",""):retained=entry
	if retained.is_empty() and not value.entries.is_empty():retained=value.entries[0]
	select(retained)
	if value.entries.is_empty():
		var empty:=FrontierInterfaceStyle.label(grid,"E를 유지해 현장의 생물·광물·장비를 조사하세요." if search.text.is_empty() and category.selected==0 and location.selected==0 else "장비의 표식을 E로 조사하면 기업이 기록됩니다." if category.selected==5 and search.text.is_empty() else "조건에 맞는 발견이 없습니다.",14);empty.custom_minimum_size.x=220;empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func select(entry: Dictionary) -> void:
	selected_entry=entry
	for tile in grid.get_children():
		if tile is FrontierItemTile:tile.selected=tile.get_meta("key","")==entry.get("key","");tile.queue_redraw()
	for child in details.get_children():details.remove_child(child);child.queue_free()
	preview.hide()
	preview.custom_minimum_size.y=120
	if entry.is_empty():return
	var heading:=FrontierInterfaceStyle.label(details,entry.name,20);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var source:=FrontierUniverse.body_from_id(app.session.manifest,entry.row.body_id)
	FrontierInterfaceStyle.label(details,"발견  "+str(source.get("name",entry.row.body_id)),12,FrontierInterfaceStyle.MUTED)
	if entry.kind=="corporation":
		var company:=FrontierCorporations.company(entry.company)
		var item:=FrontierCorporations.asset(entry.row.asset)
		preview.custom_minimum_size.y=160;preview.show();preview.show_model(item.model)
		FrontierCorporateIdentity.frame_preview(preview,entry.row.asset)
		FrontierInterfaceStyle.label(details,company.role,15,FrontierInterfaceStyle.ACCENT)
		FrontierCorporateIdentity.add_to(details,entry.row.asset)
		var note:=FrontierInterfaceStyle.label(details,company.description,14);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var source_label:=FrontierInterfaceStyle.label(details,"첫 식별  "+str(item.name),13);source_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	elif entry.kind=="coopertech_clue":
		preview.custom_minimum_size.y=170;preview.show();preview.show_model(entry.row.model);FrontierCorporateIdentity.frame_trace_preview(preview)
		FrontierCorporateIdentity.add_to(details,"coopertech_robot")
		for text in [FrontierCooperTechClues.STATES[int(entry.row.stage)],"출처  "+str(entry.row.source),"지상 좌표  %.0f, %.0f"%[entry.row.position[0],entry.row.position[2]],"착륙 후 Tab 지도와 현장 표식을 따라 이동하세요. 실제 전투로봇을 제압하고 부품을 회수하면 이 기록도 종결됩니다." if int(entry.row.stage)<2 else "동일한 현장 로봇의 부품 회수가 확인되었습니다. 단서 자체는 별도 보상을 지급하지 않습니다."]:
			var line:=Label.new();line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.text=text;details.add_child(line)
		var locate:=Button.new();locate.text="현장 지도에서 좌표 보기" if app.surface_world!=null and app.surface_world.body.id==entry.row.body_id else "항성계에서 목적 행성 보기";details.add_child(locate)
		locate.pressed.connect(func():
			app.close_menus()
			if app.surface_world!=null and app.surface_world.body.id==entry.row.body_id:app.planet_map.show_clue(entry.row)
			else:app.navigation_ui.show_target(int(entry.row.body)))
	elif entry.kind=="freight_incident":
		preview.custom_minimum_size.y=150;preview.show();preview.show_model(entry.row.model);FrontierCorporateIdentity.frame_trace_preview(preview)
		var stage:=int(entry.row.stage)
		var service:=FrontierFreightSalvage.maintenance(entry.row.id);var finished:=stage==FrontierFreightSalvage.last_stage(entry.row.id)
		for text in [FrontierFreightSalvage.states(entry.row.id)[stage],str(entry.row.call_sign),"교체 부품  "+str(entry.row.cargo) if service else "봉인 화물  "+str(entry.row.cargo),"작업장  "+str(entry.row.port_name) if service else "인계 항만  "+str(entry.row.port_name),("완료 대금  %d C 지급 완료" if finished else "작업 완료 후 공동 자금  +%d C")%int(entry.row.payment),"부품 거치대에서 카트리지를 적재해 작업장으로 운반하세요. 설치 후 E를 유지해 정비하면 드릴이 재가동됩니다." if service and not finished else ("외부 거치대는 선박마다 화물 한 개를 고정합니다. 지정 항만까지 직접 운반하세요." if not finished else "이 작업의 보상은 다시 지급되지 않습니다.")]:
			if str(text).is_empty():continue
			var line:=Label.new();line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.text=text;line.add_theme_font_size_override("font_size",14);details.add_child(line)
		var locate:=Button.new();locate.text="지도에서 작업장 보기" if service else "지도에서 인계 행성 보기";details.add_child(locate)
		locate.pressed.connect(func():app.close_menus();app.navigation_ui.show_target(int(entry.row.body)))
		if service:
			var supply:=Button.new();supply.text="지도에서 교체 부품 수령지 보기";details.add_child(supply)
			supply.pressed.connect(func():app.close_menus();app.navigation_ui.show_target(int(entry.row.source_body)))
	elif entry.kind=="corporate_trace":
		preview.custom_minimum_size.y=150;preview.show();preview.show_model(entry.row.model)
		FrontierCorporateIdentity.frame_trace_preview(preview)
		var identity:=HBoxContainer.new();details.add_child(identity)
		var mark:=TextureRect.new();mark.texture=load(FrontierCorporations.icon_path(entry.company));mark.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;mark.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;mark.custom_minimum_size=Vector2(40,40);identity.add_child(mark)
		FrontierInterfaceStyle.label(identity,FrontierCorporations.company(entry.company).name,18)
		for text in [entry.row.activity,entry.row.status,"공동 조사 %d / 2"%int(entry.row.stage),entry.row.evidence if int(entry.row.stage)==2 else "650m 이내로 접근해 E를 유지하면 활동 기록을 읽을 수 있습니다.","연결 거점  "+str(entry.row.site_name)]:
			var line:=Label.new();line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.text=text;line.add_theme_font_size_override("font_size",14);line.add_theme_color_override("font_color",FrontierInterfaceStyle.TEXT);details.add_child(line)
		var clue: Dictionary=app.session.latest.get("coopertech_clues",{}).get(entry.row.id,{})
		if not clue.is_empty():
			var ground:=Button.new();ground.text="폐기 로봇 좌표 · "+FrontierCooperTechClues.STATES[int(clue.stage)];details.add_child(ground)
			ground.pressed.connect(func():app.close_menus();app.navigation_ui.show_target(int(clue.body)))
	elif entry.kind=="discovery":
		var d:=FrontierExplorationDiscoveries.definition(entry.row.template)
		preview.show();preview.show_model(d.model)
		var index:=int(entry.row.stage)
		var text: String=d.knowledge if entry.row.claimed else "다음 조사  "+str(d.stages[index].label)
		var label:=FrontierInterfaceStyle.label(details,text,14);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		FrontierInterfaceStyle.label(details,"T%d  조사 %d / %d"%[int(d.tier),index,d.stages.size()],13)
		var at: Array=entry.row.position
		FrontierInterfaceStyle.label(details,"현장 좌표  %.0f / %.0f"%[float(at[0]),float(at[2])],13)
		for resource in d.reward:
			var line:=HBoxContainer.new();details.add_child(line);line.add_child(FrontierResourceIcons.view(resource,24));FrontierInterfaceStyle.label(line,str(int(d.reward[resource])),14)
		if not entry.row.clue.is_empty():
			var clue: Dictionary=entry.row.clue
			FrontierInterfaceStyle.label(details,"광맥 단서  %s  %.0f / %.0f"%[FrontierCatalog.entry("resources",clue.resource).name,float(clue.position[0]),float(clue.position[2])],13)
		if not entry.row.sample.is_empty():FrontierInterfaceStyle.label(details,"확보 계통  "+str(FrontierEcologyCatalog.form(entry.row.sample.form_id).name),13)
	elif entry.kind=="incident":
		var d:=FrontierExplorationIncidents.definition(entry.row.template)
		if d.mode=="robot":FrontierCorporateIdentity.add_to(details,"coopertech_robot")
		preview.show()
		if entry.row.has("native"):
			preview.show_specimen(entry.row.native)
			var individual:=FrontierInterfaceStyle.label(details,FrontierNativeIncidents.title(entry.row.native)+" · %.2fm / 기본 개체 %.0f%%"%[float(entry.row.native.height),float(entry.row.native.factor)*100],13);individual.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		else:preview.show_model(d.model)
		FrontierInterfaceStyle.label(details,"T%d  %s"%[int(d.tier),"회수 완료" if entry.row.claimed else "현장 진행 중"],13)
		var equipment: String=d.get("equipment",{}).get(str(int(entry.row.tier)),"")
		if equipment!="":FrontierInterfaceStyle.label(details,"회수 장비  "+str(FrontierEquipment.config().items[equipment].name),13)
		var note:=FrontierInterfaceStyle.label(details,d.hint,14);note.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
		FrontierInterfaceStyle.label(details,"현장 좌표  %.0f / %.0f"%[float(entry.row.position[0]),float(entry.row.position[2])],13)
		var reward:=FrontierNativeIncidents.reward(entry.row)
		for resource in reward:
			var line:=HBoxContainer.new();details.add_child(line);line.add_child(FrontierResourceIcons.view(resource,24));FrontierInterfaceStyle.label(line,str(int(reward[resource])),14)
	elif entry.kind=="biology":
		for index in app.form_options.item_count:
			if app.form_options.get_item_metadata(index)==entry.row.form_id:app.form_options.select(index);break
		var form:=FrontierEcologyCatalog.form(entry.row.form_id)
		var model_path: String="bestiary/"+str(form.lods.near.path).get_file().trim_suffix(".glb")
		preview.show();preview.show_model(model_path);preview.tooltip_text="드래그하여 회전"
		var info:=FrontierSurfaceSurvey.biology_info(form)
		var condition:=FrontierInterfaceStyle.label(details,info.condition,13,FrontierInterfaceStyle.ACCENT);condition.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		for note in info.notes:
			if note.icon!="build":continue
			var label:=FrontierInterfaceStyle.label(details,note.text,13);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	else:
		details.add_child(FrontierResourceIcons.view(entry.icon,72))
		FrontierInterfaceStyle.label(details,"채집기 %d등급  매장량은 현장 재조사"%int(entry.row.tier),13)
		var uses: PackedStringArray=[]
		for id in FrontierProductionTier2.config().products:
			var recipe:=FrontierProductionTier2.product(id)
			if int(recipe.tier)<=2 and recipe.cost.has(entry.row.resource):uses.append(recipe.name)
		if FrontierMinerals.entry(entry.row.resource).get("category")=="gem":uses.append("개인 증강  우주선 증강 장치")
		if not uses.is_empty():
			var note:=FrontierInterfaceStyle.label(details,"사용처  "+"  ".join(uses),13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
