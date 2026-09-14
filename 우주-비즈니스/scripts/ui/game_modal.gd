class_name FrontierGameModal
extends Window
## Embedded game surface: keeps Window exclusivity and cursor guards, without OS chrome.
signal confirmed
signal canceled
static var _active: WeakRef
var surface: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var primary: Button
var secondary: Button
var heading: Label
var eyebrow: Label
var symbol: TextureRect
var footer: HBoxContainer
var requested_size:=Vector2i(720,570)
var _shade: CanvasLayer
var _focus: WeakRef
var _resolved:=false

func _init() -> void:
	visible=false;borderless=true;unresizable=true;transient=true;exclusive=true
	wrap_controls=false;min_size=Vector2i(320,240)

func _ready() -> void:
	theme=FrontierInterfaceStyle.theme()
	var panel:=PanelContainer.new();surface=panel;add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,18))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
	var top:=HBoxContainer.new();column.add_child(top)
	symbol=FrontierInterfaceStyle.interface_icon("scan",24);top.add_child(symbol)
	var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;titles.add_theme_constant_override("separation",4);top.add_child(titles)
	eyebrow=FrontierInterfaceStyle.label(titles,"탐사 단말",12,FrontierInterfaceStyle.ACCENT)
	heading=FrontierInterfaceStyle.label(titles,title,24);heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var close:=Button.new();close.text="×";close.tooltip_text="닫기 (Esc)";close.custom_minimum_size=Vector2(42,42);close.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;top.add_child(close);close.pressed.connect(cancel)
	column.add_child(HSeparator.new())
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",14);scroll.add_child(content)
	column.add_child(HSeparator.new())
	footer=HBoxContainer.new();footer.alignment=BoxContainer.ALIGNMENT_END;column.add_child(footer)
	secondary=Button.new();secondary.text="돌아가기";secondary.custom_minimum_size=Vector2(112,46);footer.add_child(secondary);secondary.pressed.connect(cancel);secondary.hide()
	primary=Button.new();primary.text="닫기";primary.custom_minimum_size=Vector2(160,46);footer.add_child(primary);primary.pressed.connect(accept)
	primary.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.ACTIVE,FrontierInterfaceStyle.ACCENT,12))
	primary.add_theme_color_override("font_color",FrontierInterfaceStyle.ACCENT)
	close_requested.connect(cancel);window_input.connect(_window_input)
	visibility_changed.connect(_visibility)
	get_parent().get_viewport().size_changed.connect(_fit)
	if get_parent() is Control:get_parent().visibility_changed.connect(_owner_visibility)
	_shade=CanvasLayer.new();_shade.layer=80;_shade.visible=false;get_parent().get_viewport().add_child(_shade)
	var dim:=ColorRect.new();dim.color=Color(0.015,0.03,0.04,0.68);_shade.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(title_text: String,action: String="닫기",context: String="탐사 단말",icon: String="scan",confirmation: bool=false) -> void:
	title=title_text;heading.text=title_text;primary.text=action;eyebrow.text=context;symbol.texture=load("res://assets/ui/interface/"+icon+".svg");secondary.visible=confirmation

func present(dimensions: Vector2i=Vector2i(720,570)) -> void:
	if _active!=null:
		var previous_modal:=_active.get_ref() as FrontierGameModal
		if previous_modal!=null and previous_modal!=self and previous_modal.visible:previous_modal.cancel()
	_active=weakref(self)
	requested_size=dimensions;_resolved=false
	var previous:=get_parent().get_viewport().gui_get_focus_owner()
	_focus=weakref(previous) if previous!=null else null
	_fit();popup_centered(size);FrontierCursorPolicy.release()
	surface.modulate.a=0.0;create_tween().tween_property(surface,"modulate:a",1.0,0.14)
	# Destructive actions never receive initial keyboard focus.
	if secondary.visible:secondary.grab_focus()
	else:primary.grab_focus()

func _fit() -> void:
	var available:=Vector2i(get_parent().get_viewport().get_visible_rect().size)-Vector2i(40,40)
	size=Vector2i(mini(requested_size.x,available.x),mini(requested_size.y,available.y))
	if visible:position=(Vector2i(get_parent().get_viewport().get_visible_rect().size)-size)/2

func _owner_visibility() -> void:
	if visible and not get_parent().is_visible_in_tree():cancel()

func _visibility() -> void:
	if is_instance_valid(_shade):_shade.visible=visible
	if not visible and _focus!=null:
		var previous:=_focus.get_ref() as Control
		if previous!=null and previous.is_visible_in_tree():previous.grab_focus()

func _exit_tree() -> void:
	if is_instance_valid(_shade):_shade.queue_free()

func _input(event: InputEvent) -> void:
	if visible:_window_input(event)

func _window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode==KEY_ESCAPE or event.physical_keycode==KEY_ESCAPE):
		set_input_as_handled();cancel()

func accept() -> void:
	if _resolved or not visible or primary.disabled:return
	_resolved=true;hide();confirmed.emit()

func cancel() -> void:
	if _resolved or not visible:return
	_resolved=true;hide();canceled.emit()

func notice(text: String) -> Label:
	var label:=paragraph(text,FrontierInterfaceStyle.ACCENT,footer.get_parent())
	footer.get_parent().move_child(label,footer.get_index())
	return label

func paragraph(text: String,color: Color=FrontierInterfaceStyle.MUTED,parent: Node=null) -> Label:
	var label:=FrontierInterfaceStyle.label(content if parent==null else parent,text,14,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return label

func section(text: String) -> VBoxContainer:
	var box:=PanelContainer.new();box.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.PANEL,FrontierInterfaceStyle.LINE,14));content.add_child(box)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",10);box.add_child(body)
	if not text.is_empty():paragraph(text,FrontierInterfaceStyle.TEXT,body)
	return body

func metric(parent: Node,label: String,value: String,icon: String="",large: bool=false) -> void:
	var row:=HBoxContainer.new();parent.add_child(row)
	if not icon.is_empty():row.add_child(FrontierInterfaceStyle.interface_icon(icon,24))
	var caption:=paragraph(label,FrontierInterfaceStyle.MUTED,row);caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL;caption.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var number:=FrontierInterfaceStyle.label(row,value,30 if large else 18,FrontierInterfaceStyle.ACCENT if large else FrontierInterfaceStyle.TEXT);number.size_flags_vertical=Control.SIZE_SHRINK_CENTER

func resources(parent: Node,cost: Dictionary) -> void:
	var readout:=FrontierResourceReadout.new();readout.custom_minimum_size.x=0;parent.add_child(readout);readout.value=FrontierCatalog.cost_text(cost)

func item_card(parent: Node,texture: Texture2D,name_text: String,detail: String) -> void:
	var row:=HBoxContainer.new();parent.add_child(row)
	var image:=TextureRect.new();image.texture=texture;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.custom_minimum_size=Vector2(24,44) if texture!=null and texture.resource_path.ends_with(".svg") else Vector2(68,68);row.add_child(image)
	var labels:=VBoxContainer.new();labels.size_flags_horizontal=Control.SIZE_EXPAND_FILL;labels.size_flags_vertical=Control.SIZE_SHRINK_CENTER;labels.add_theme_constant_override("separation",4);row.add_child(labels)
	paragraph(name_text,FrontierInterfaceStyle.TEXT,labels);paragraph(detail,FrontierInterfaceStyle.MUTED,labels)

static func number(value: int) -> String:
	var raw:=str(absi(value));var result:=""
	for i in raw.length():
		if i>0 and (raw.length()-i)%3==0:result+=","
		result+=raw[i]
	return ("-" if value<0 else "")+result
