class_name FrontierVesselCapabilityReadout
extends RefCounted
static func populate(parent: Control,caps: Dictionary,target: int=0) -> void:
	for key in FrontierVesselAccess.config().capabilities:
		var def: Dictionary=FrontierVesselAccess.config().capabilities[key]
		var line:=HBoxContainer.new();line.add_theme_constant_override("separation",8);parent.add_child(line)
		var icon:=TextureRect.new();icon.texture=load("res://assets/ui/interface/"+str(def.icon)+".svg");icon.custom_minimum_size=Vector2(22,22);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;line.add_child(icon)
		var title:=FrontierInterfaceStyle.label(line,def.name,13);title.custom_minimum_size.x=80
		var current:=float(caps.get(key,0));var needed:=float(FrontierVesselAccess.config().tier_requirements.get(str(target),{}).get(key,0))
		var bar:=ProgressBar.new();bar.max_value=float(def.maximum);bar.value=current;bar.show_percentage=false;bar.custom_minimum_size=Vector2(55,10);bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER;line.add_child(bar)
		bar.add_theme_stylebox_override("background",FrontierInterfaceStyle.box(Color("31434d"),Color.TRANSPARENT,0))
		bar.add_theme_stylebox_override("fill",FrontierInterfaceStyle.box(FrontierInterfaceStyle.ACCENT,Color.TRANSPARENT,0))
		var value:=FrontierInterfaceStyle.label(line,"%d → %d"%[current,needed] if needed>current else "%d / %d"%[current,def.maximum],13)
		value.modulate=FrontierInterfaceStyle.WARNING if current<needed else FrontierInterfaceStyle.ACCENT
