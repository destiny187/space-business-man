class_name FrontierStatusMeter
extends VBoxContainer
## One compact header above each gauge; all status icons share the same color.
var bar: ProgressBar
var value_label: Label
var symbol: TextureRect
var fill: StyleBoxFlat

func configure(kind: String,caption: String) -> void:
	name=kind.capitalize()+"Meter";tooltip_text=caption
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x=192;size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation",3)
	var header:=HBoxContainer.new();header.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(header)
	symbol=FrontierInterfaceStyle.interface_icon(kind);symbol.self_modulate=FrontierInterfaceStyle.ACCENT;header.add_child(symbol)
	value_label=FrontierInterfaceStyle.label(header,"",12);value_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;FrontierInterfaceStyle.hud_shadow(value_label)
	bar=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(192,6)
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background",FrontierInterfaceStyle.meter_box(FrontierInterfaceStyle.INK))
	fill=FrontierInterfaceStyle.meter_box(FrontierInterfaceStyle.ACCENT);bar.add_theme_stylebox_override("fill",fill);add_child(bar)

func update_value(current: float,maximum: float,warning: bool=false) -> void:
	bar.max_value=maxf(1,maximum);bar.value=current
	value_label.text="%d / %d"%[ceili(current),ceili(maximum)] if maximum>0 else "—"
	var color:=FrontierInterfaceStyle.WARNING if warning else FrontierInterfaceStyle.ACCENT
	if fill.bg_color!=color:fill.bg_color=color
	var number_color:=FrontierInterfaceStyle.WARNING if warning else (FrontierInterfaceStyle.TEXT if maximum>0 else FrontierInterfaceStyle.MUTED)
	if value_label.get_theme_color("font_color")!=number_color:value_label.add_theme_color_override("font_color",number_color)
