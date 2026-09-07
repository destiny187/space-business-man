class_name FrontierNavigationRecords
extends Window
signal selected(ordinal: int)
var journal: FrontierNavigationJournal
var entries: ItemList
var search: LineEdit
var filter: OptionButton
var caption: Label
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
	for label in ["전체 기록","★ 즐겨찾기","▣ 개발 중"]:filter.add_item(label)
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
	page=clampi(page,0,maxi(0,(pages.size()-1)/50))
	caption.text="탐험한 항성계 %d  ·  행성 기록 %d  ·  %d / %d"%[journal.data.systems.size(),pages.size(),page+1,maxi(1,int(ceil(pages.size()/50.0)))]
	if not journal.error.is_empty():caption.text=journal.error
	for index in range(page*50,mini(pages.size(),(page+1)*50)):
		var ordinal: int=pages[index];var body:=FrontierUniverse.body(journal.manifest,ordinal)
		entries.add_item(body.name+"    "+journal.status(ordinal));entries.set_item_metadata(entries.item_count-1,ordinal)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		hide();get_viewport().set_input_as_handled()
