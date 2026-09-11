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
const HOVER:=Color("22333d")
const ACTIVE:=Color("203b38")
const SPACE:=6
const ICON_SIZE:=20
static func box(color: Color=PANEL,border: Color=LINE,padding: int=16) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=color;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(3);s.set_content_margin_all(padding);return s
static func theme() -> Theme:
	var font:=FontVariation.new();font.base_font=load("res://assets/fonts/NotoSansKR.ttf");font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	var t:=Theme.new();t.default_font=font;t.default_font_size=15
	for type in ["Label","Button","OptionButton","LineEdit","TabContainer","RichTextLabel"]:
		t.set_color("font_color",type,TEXT);t.set_color("font_focus_color",type,TEXT);t.set_color("font_hover_color",type,TEXT);t.set_color("font_disabled_color",type,MUTED);t.set_constant("outline_size",type,0)
	for type in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,box(PANEL,LINE,10));t.set_stylebox("hover",type,box(HOVER,LINE,10));t.set_stylebox("pressed",type,box(ACTIVE,ACCENT,10));t.set_stylebox("disabled",type,box(INK,LINE,10));t.set_stylebox("focus",type,box(Color.TRANSPARENT,ACCENT,2))
		t.set_constant("h_separation",type,SPACE);t.set_color("font_pressed_color",type,ACCENT)
	for type in ["LineEdit","PanelContainer","PopupPanel"]:t.set_stylebox("normal" if type=="LineEdit" else "panel",type,box())
	t.set_stylebox("focus","LineEdit",box(Color.TRANSPARENT,ACCENT,0))
	t.set_color("caret_color","LineEdit",ACCENT);t.set_color("selection_color","LineEdit",ACTIVE)
	t.set_stylebox("panel","TabContainer",box(INK,LINE,12))
	for type in ["TabContainer","TabBar"]:
		var selected:=box(PANEL,ACCENT,10);selected.set_border_width_all(0);selected.border_width_bottom=2
		t.set_stylebox("tab_selected",type,selected);t.set_stylebox("tab_unselected",type,box(Color.TRANSPARENT,Color.TRANSPARENT,10));t.set_stylebox("tab_hovered",type,box(HOVER,Color.TRANSPARENT,10));t.set_stylebox("tab_focus",type,box(Color.TRANSPARENT,ACCENT,0))
		t.set_color("font_selected_color",type,ACCENT);t.set_color("font_unselected_color",type,MUTED);t.set_color("font_hovered_color",type,TEXT)
		t.set_stylebox("tab_disabled",type,box(Color.TRANSPARENT,Color.TRANSPARENT,10));t.set_color("font_disabled_color",type,MUTED)
	t.set_stylebox("background","ProgressBar",meter_box(INK));t.set_stylebox("fill","ProgressBar",meter_box(ACCENT))
	for type in ["VScrollBar","HScrollBar"]:
		t.set_stylebox("scroll",type,box(INK,Color.TRANSPARENT,4));t.set_stylebox("grabber",type,box(LINE,Color.TRANSPARENT,4));t.set_stylebox("grabber_highlight",type,box(MUTED,Color.TRANSPARENT,4));t.set_stylebox("grabber_pressed",type,box(ACCENT,Color.TRANSPARENT,4))
	t.set_stylebox("panel","PopupMenu",box(INK,LINE,12));t.set_stylebox("hover","PopupMenu",box(HOVER,Color.TRANSPARENT,6));t.set_color("font_color","PopupMenu",TEXT);t.set_color("font_hover_color","PopupMenu",ACCENT);t.set_constant("v_separation","PopupMenu",12)
	t.set_stylebox("panel","TooltipPanel",box(INK,LINE,12));t.set_color("font_color","TooltipLabel",TEXT);t.set_font_size("font_size","TooltipLabel",12)
	for type in ["HSeparator","VSeparator"]:
		var separator:=StyleBoxLine.new();separator.color=LINE;separator.thickness=1;separator.vertical=type=="VSeparator";t.set_stylebox("separator",type,separator);t.set_constant("separation",type,SPACE)
	t.set_constant("separation","VBoxContainer",12);t.set_constant("separation","HBoxContainer",12)
	return t
static func meter_box(color: Color) -> StyleBoxFlat:
	var style:=box(color,Color.TRANSPARENT,0);style.set_border_width_all(0);style.set_corner_radius_all(2);return style
static func hud_shadow(control: Control) -> void:
	control.add_theme_color_override("font_shadow_color",Color("081218e0"));control.add_theme_constant_override("shadow_offset_x",1);control.add_theme_constant_override("shadow_offset_y",1)
static func interface_icon(id: String,pixels: int=ICON_SIZE) -> TextureRect:
	var view:=TextureRect.new();view.texture=load("res://assets/ui/interface/"+id+".svg");view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.custom_minimum_size=Vector2.ONE*pixels;view.mouse_filter=Control.MOUSE_FILTER_IGNORE;return view
static func label(parent: Node,text: String,size: int=14,color: Color=TEXT) -> Label:
	var l:=Label.new();l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l
static func icon(model: String) -> Texture2D:
	var path: String="res://assets/ui/equipment/"+model.get_file()+".png"
	return load(path) if ResourceLoader.exists(path) else load("res://assets/ui/previews/"+model.get_file()+".png")
