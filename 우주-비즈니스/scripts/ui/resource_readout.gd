class_name FrontierResourceReadout
extends RichTextLabel

# Keep unformatted source available to callers and as the readable tooltip.
var centered_cost:=false
var value: String = "":
	set(next):
		if value == next: return
		value = next
		tooltip_text = next
		text = FrontierResourceIcons.markup(next)

func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	custom_minimum_size.x = 360
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_font_size_override("normal_font_size",16)

func show_cost(cost: Dictionary,stock: Dictionary,with_owned: bool=false,pixels: int=24) -> void:
	var parts: PackedStringArray=[]
	var hints: PackedStringArray=[]
	for id in cost:
		var need:=int(cost[id]);var have:=int(stock.get(id,0))
		var color:=FrontierInterfaceStyle.TEXT if have>=need else FrontierInterfaceStyle.DANGER
		var number: String=("%d/%d"%[have,need]) if with_owned else str(need)
		parts.append("[img=%dx%d]%s[/img] [color=#%s]%s[/color]"%[pixels,pixels,FrontierResourceIcons.icon_path(id),color.to_html(false),number])
		hints.append("%s: %d / %d"%[FrontierCatalog.entry("resources",id).name,have,need])
	var markup: String=("[center]" if centered_cost else "")+"   ".join(parts)+("[/center]" if centered_cost else "")
	var hint: String="\n".join(hints)
	if text==markup and tooltip_text==hint:return
	value="";text=markup;tooltip_text=hint
