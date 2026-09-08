class_name FrontierItemBrowser
extends HBoxContainer
## Filtering is a view of actual slots; it never edits inventory or stack order.
signal changed
var search: LineEdit
var category: OptionButton
var order: OptionButton
const CATEGORIES: Array[String]=["all","mineral","gem","product","equipment"]
func _init() -> void:
	add_theme_constant_override("separation",6)
	search=LineEdit.new();search.placeholder_text="이름 검색";search.clear_button_enabled=true;search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;search.custom_minimum_size.x=110;add_child(search)
	search.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.PANEL,FrontierInterfaceStyle.LINE,6))
	category=OptionButton.new();category.fit_to_longest_item=false;category.custom_minimum_size.x=78;add_child(category)
	for label in ["전체","광물","보석","부품","장비"]:category.add_item(label)
	order=OptionButton.new();order.fit_to_longest_item=false;order.custom_minimum_size.x=84;add_child(order)
	for label in ["이름순","수량순"]:order.add_item(label)
	search.text_changed.connect(func(_value: String):changed.emit())
	category.item_selected.connect(func(_index: int):changed.emit())
	order.item_selected.connect(func(_index: int):changed.emit())
static func kind(resource: String) -> String:
	if not FrontierProductionTier2.product(resource).is_empty():return "product"
	return "gem" if FrontierMinerals.entry(resource).get("category")=="gem" else "mineral"
func matches(label: String,item_kind: String) -> bool:
	var query:=search.text.strip_edges().to_lower()
	return (category.selected==0 or CATEGORIES[category.selected]==item_kind) and (query.is_empty() or label.to_lower().contains(query))
func filtered() -> bool:return category.selected!=0 or not search.text.strip_edges().is_empty()
func apply(grid: GridContainer) -> int:
	var rows: Array=grid.get_children()
	rows.sort_custom(func(a: Node,b: Node):
		var aq:=int(a.get_meta("quantity",0));var bq:=int(b.get_meta("quantity",0))
		if order.selected==1 and aq!=bq:return aq>bq
		return str(a.get_meta("label","")).naturalnocasecmp_to(str(b.get_meta("label","")))<0)
	var count:=0
	for i in rows.size():
		var tile: Control=rows[i];grid.move_child(tile,i)
		tile.visible=matches(str(tile.get_meta("label","")),str(tile.get_meta("kind","")))
		if tile.visible:count+=1
	return count
static func tag(tile: Control,label: String,item_kind: String,quantity: int=1) -> void:
	tile.set_meta("label",label);tile.set_meta("kind",item_kind);tile.set_meta("quantity",quantity)
