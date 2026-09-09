class_name FrontierInterfaceStyle
extends RefCounted
const INK:=Color("10191f")
const PANEL:=Color("17232b")
const LINE:=Color("31434d")
const TEXT:=Color("e6e8df")
const MUTED:=Color("a4b5bd")
const ACCENT:=Color("83d9c5")
const WARNING:=Color("efb46f")
const DANGER:=Color("ff7777")
static func box(color: Color=PANEL,border: Color=LINE,padding: int=16) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(3);s.set_content_margin_all(padding);return s
static func theme() -> Theme:
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	var t:=Theme.new();t.default_font=font;t.default_font_size=15
	for type in ["Label","Button","OptionButton","LineEdit","TabContainer","RichTextLabel"]:
		t.set_color("font_color",type,TEXT);t.set_color("font_focus_color",type,TEXT);t.set_color("font_hover_color",type,TEXT);t.set_color("font_disabled_color",type,MUTED);t.set_constant("outline_size",type,0)
	for type in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,box(PANEL,LINE,10));t.set_stylebox("hover",type,box(Color("263941"),ACCENT,10));t.set_stylebox("pressed",type,box(Color("29463f"),ACCENT,10));t.set_stylebox("disabled",type,box(INK,LINE,10));t.set_stylebox("focus",type,box(Color.TRANSPARENT,ACCENT,2))
	for type in ["LineEdit","PanelContainer","PopupPanel"]:t.set_stylebox("normal" if type=="LineEdit" else "panel",type,box())
	t.set_stylebox("panel","TabContainer",box(INK,LINE,12));t.set_stylebox("tab_selected","TabContainer",box(PANEL,ACCENT,10));t.set_stylebox("tab_unselected","TabContainer",box(INK,INK,10));t.set_color("font_selected_color","TabContainer",ACCENT);t.set_color("font_unselected_color","TabContainer",MUTED)
	t.set_stylebox("background","ProgressBar",box(INK,INK,0));t.set_stylebox("fill","ProgressBar",box(ACCENT,ACCENT,0))
	t.set_constant("separation","VBoxContainer",12);t.set_constant("separation","HBoxContainer",12)
	return t
static func label(parent: Node,text: String,size: int=14,color: Color=TEXT) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
static func icon(model: String) -> Texture2D:
	var path: String="res://assets/ui/equipment/"+model.get_file()+".png"
	return load(path) if ResourceLoader.exists(path) else load("res://assets/ui/previews/"+model.get_file()+".png")
