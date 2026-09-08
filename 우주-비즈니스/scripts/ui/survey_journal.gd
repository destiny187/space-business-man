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
	for title in ["전체","광물 · 보석","생물"]:category.add_item(title)
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
	var signature:=str(app.session.latest.get("location",""))+str(app.session.latest.get("crew",{}).get("survey",{}))+str(app.session.surface.get("ecology",{}).get("observations",{}))
	if not was_visible or signature!=last_signature:last_signature=signature;refresh()
	was_visible=true
	if query_delay>0:
		query_delay-=delta
		if query_delay<=0:refresh()
func refresh() -> void:
	serial+=1
	app.session.request_discoveries(serial,search.text,["all","mineral","biology"][category.selected],str(app.session.latest.get("location","")) if location.selected==1 else "",page_index)
func _receive(reply_serial: int,value: Dictionary) -> void:
	if reply_serial!=serial:return
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	page_index=int(value.page)
	caption.text="%d개 · %d / %d"%[int(value.total),page_index+1,maxi(1,ceili(float(value.total)/24))]
	previous.disabled=page_index==0;next.disabled=(page_index+1)*24>=int(value.total)
	var retained: Dictionary={}
	for entry in value.entries:
		var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(entry.icon);tile.caption=entry.name;tile.tooltip_text=entry.name;tile.set_meta("key",entry.key);grid.add_child(tile)
		tile.pressed.connect(func():select(entry))
		if entry.key==selected_entry.get("key",""):retained=entry
	if retained.is_empty() and not value.entries.is_empty():retained=value.entries[0]
	select(retained)
	if value.entries.is_empty():
		var empty:=FrontierInterfaceStyle.label(grid,"E를 유지해 생물·광물을 조사하세요." if search.text.is_empty() and category.selected==0 and location.selected==0 else "조건에 맞는 발견이 없습니다.",14);empty.custom_minimum_size.x=220;empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func select(entry: Dictionary) -> void:
	selected_entry=entry
	for tile in grid.get_children():
		if tile is FrontierItemTile:tile.selected=tile.get_meta("key","")==entry.get("key","");tile.queue_redraw()
	for child in details.get_children():details.remove_child(child);child.queue_free()
	preview.hide()
	if entry.is_empty():return
	var heading:=FrontierInterfaceStyle.label(details,entry.name,20);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var source:=FrontierUniverse.body_from_id(app.session.manifest,entry.row.body_id)
	FrontierInterfaceStyle.label(details,"발견 · "+str(source.get("name",entry.row.body_id)),12,FrontierInterfaceStyle.MUTED)
	if entry.kind=="biology":
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
		FrontierInterfaceStyle.label(details,"채집기 %d등급 · 매장량은 현장 재조사"%int(entry.row.tier),13)
		var uses: PackedStringArray=[]
		for id in FrontierProductionTier2.config().products:
			var recipe:=FrontierProductionTier2.product(id)
			if int(recipe.tier)<=2 and recipe.cost.has(entry.row.resource):uses.append(recipe.name)
		if FrontierMinerals.entry(entry.row.resource).get("category")=="gem":uses.append("개인 증강 · 우주선 증강 장치")
		if not uses.is_empty():
			var note:=FrontierInterfaceStyle.label(details,"사용처 · "+" · ".join(uses),13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
