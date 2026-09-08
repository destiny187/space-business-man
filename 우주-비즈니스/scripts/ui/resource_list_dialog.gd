class_name FrontierResourceListDialog
extends AcceptDialog
var grid: GridContainer
var browser: FrontierItemBrowser
var empty: Label
func configure(title_text: String,stock: Dictionary,quantities: bool=true) -> void:
	title=title_text;theme=FrontierInterfaceStyle.theme()
	add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	add_theme_stylebox_override("embedded_border",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,6))
	var column:=VBoxContainer.new();column.custom_minimum_size=Vector2(460,310);add_child(column)
	browser=FrontierItemBrowser.new();column.add_child(browser)
	if not quantities:browser.order.hide()
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	grid=GridContainer.new();grid.columns=4;scroll.add_child(grid)
	for id in stock:
		if quantities and int(stock[id])<=0:continue
		var tile:=FrontierItemTile.new();tile.picture=FrontierResourceIcons.texture(id);tile.caption=FrontierCatalog.entry("resources",id).name;tile.amount=str(int(stock[id])) if quantities else "";tile.tooltip_text=tile.caption;grid.add_child(tile)
		FrontierItemBrowser.tag(tile,tile.caption,FrontierItemBrowser.kind(id),int(stock[id]))
	empty=FrontierInterfaceStyle.label(column,"조건에 맞는 자원이 없습니다.",14)
	browser.changed.connect(refresh);refresh()
	confirmed.connect(queue_free);canceled.connect(queue_free)
func refresh() -> void:empty.visible=browser.apply(grid)==0
