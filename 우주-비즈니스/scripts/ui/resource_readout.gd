class_name FrontierResourceReadout
extends RichTextLabel

# Keep unformatted source available to callers and as the readable tooltip.
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
