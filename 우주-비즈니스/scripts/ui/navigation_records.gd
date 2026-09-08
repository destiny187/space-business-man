class_name FrontierNavigationRecords
extends Window
signal selected(ordinal: int)
var journal: FrontierNavigationJournal
var entries: ItemList
var search: LineEdit
var filter: OptionButton
var caption: Label
var supply_sites: Array=[]
var page:=0
var pages: Array[int]=[]
func _ready() -> void:
	theme=FrontierInterfaceStyle.theme()
	title="항해 기록";size=Vector2i(680,540);min_size=Vector2i(400,320);exclusive=true;visible=false
	close_requested.connect(hide)
	var background:=ColorRect.new();background.color=FrontierInterfaceStyle.INK;background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background);background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new();add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	var column:=VBoxContainer.new();margin.add_child(column)
	caption=Label.new();column.add_child(caption)
	search=LineEdit.new();search.placeholder_text="영어 행성 이름 검색";column.add_child(search);search.text_changed.connect(func(_v):page=0;refresh())
	filter=OptionButton.new();column.add_child(filter)
	for label in ["전체 기록","★ 즐겨찾기","▣ 개발 중","▣ 생산 거점"]:filter.add_item(label)
	filter.item_selected.connect(func(_v):page=0;refresh())
	entries=ItemList.new();entries.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box());entries.size_flags_vertical=Control.SIZE_EXPAND_FILL;entries.auto_height=false;column.add_child(entries)
	entries.item_activated.connect(func(i):selected.emit(int(entries.get_item_metadata(i)));hide())
	var actions:=GridContainer.new();actions.columns=2;column.add_child(actions)
	button(actions,"이전",func():page=maxi(0,page-1);refresh())
	button(actions,"다음",func():if (page+1)*50<pages.size():page+=1;refresh())
	button(actions,"선택 항로 설정",func():
		if not entries.get_selected_items().is_empty():selected.emit(int(entries.get_item_metadata(entries.get_selected_items()[0])));hide())
	button(actions,"Earth 귀환",func():selected.emit(int(journal.manifest.settings.get("starting_ordinal",2)));hide())
	var note:=Label.new();note.text="항로 선택 후 출발 · 상태는 마지막 확인 기록";column.add_child(note)
func button(parent: Node,label: String,action: Callable) -> void:
	var b:=Button.new();b.text=label;parent.add_child(b);b.pressed.connect(action)
func refresh() -> void:
	if journal==null or entries==null:return
	pages=journal.ordinals(filter.selected,search.text);entries.clear()
	if filter.selected==3:
		pages.clear()
		for row in supply_sites:
			if search.text.is_empty() or str(row.name).to_lower().contains(search.text.to_lower()):pages.append(int(row.ordinal))
	page=clampi(page,0,maxi(0,(pages.size()-1)/50))
	caption.text="탐험한 항성계 %d  ·  행성 기록 %d  ·  %d / %d"%[journal.data.systems.size(),pages.size(),page+1,maxi(1,int(ceil(pages.size()/50.0)))]
	if not journal.error.is_empty():caption.text=journal.error
	for index in range(page*50,mini(pages.size(),(page+1)*50)):
		var ordinal: int=pages[index];var body:=FrontierUniverse.body(journal.manifest,ordinal)
		var supply: Dictionary={}
		for row in supply_sites:
			if int(row.ordinal)==ordinal:supply=row;break
		var status:=journal.status(ordinal) if supply.is_empty() else FrontierPlanetSupply.role_name(supply.role)+(" · 운영 정지" if supply.paused else (" · 원격 운영" if supply.get("remote",false) else " · 현장 운영"))
		var icon: Texture2D=null if supply.is_empty() else FrontierResourceIcons.menu_texture(FrontierPlanetSupply.config().roles.get(supply.role,{}).get("icon","stone"))
		entries.add_item(body.name+"    "+status,icon);entries.set_item_metadata(entries.item_count-1,ordinal)
		if not supply.is_empty():entries.set_item_tooltip(entries.item_count-1,"현장 창고 · "+FrontierCatalog.cost_text(supply.inventory))

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		hide();get_viewport().set_input_as_handled()
