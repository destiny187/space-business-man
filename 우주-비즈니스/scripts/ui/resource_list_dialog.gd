class_name FrontierResourceListDialog
extends FrontierGameModal
var grid: GridContainer
var browser: FrontierItemBrowser
var empty: Label
func show_stock(title_text: String,stock: Dictionary,quantities: bool=true) -> void:
	configure_resources(title_text)
	var column:=content
	browser=FrontierItemBrowser.new();column.add_child(browser)
	if not quantities:browser.order.hide()
	grid=GridContainer.new();grid.columns=4;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_child(grid)
	for id in stock:
		if quantities and int(stock[id])<=0:continue
		var tile:=FrontierItemTile.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.custom_minimum_size=Vector2(110,112);tile.picture=FrontierResourceIcons.texture(id);tile.caption=FrontierCatalog.entry("resources",id).get("name",id);tile.amount=str(int(stock[id])) if quantities else "";tile.tooltip_text=tile.caption;grid.add_child(tile)
		FrontierItemBrowser.tag(tile,tile.caption,FrontierItemBrowser.kind(id),int(stock[id]))
	empty=FrontierInterfaceStyle.label(column,"조건에 맞는 자원이 없습니다.",14)
	browser.changed.connect(refresh);refresh()
	confirmed.connect(queue_free);canceled.connect(queue_free)
func refresh() -> void:empty.visible=browser.apply(grid)==0

func configure_resources(title_text: String) -> void:
	super.configure(title_text,"닫기","관측과 보관 기록","inventory")
