class_name FrontierResourceIcons
extends RefCounted

const ROOT := "res://assets/ui/resources/"
static var registry: Dictionary = {}
static var id_aliases: Dictionary = {}

static func names() -> Dictionary:
	if registry.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/resource_icons.json"))
		for row in manifest.icons:
			registry[row.id] = row.name
			for alias in row.aliases: id_aliases[alias] = row.id
		for id in FrontierMinerals.all():
			if not registry.has(id):registry[id]=FrontierMinerals.entry(id).name
	for id in FrontierProductionTier2.config().products:registry[id]=FrontierProductionTier2.product(id).name
	return registry

static func canonical(id: String) -> String:
	if FrontierSpecimenItems.is_item(id):return str(FrontierSpecimenItems.entry(id).get("icon","bio_sample"))
	names()
	return str(id_aliases.get(id,id))

static var textures: Dictionary = {}
static var patterns: Dictionary = {}
static var menu_textures: Dictionary = {}

static func icon_path(id: String) -> String:
	id=canonical(id)
	id=str(FrontierProductionTier2.product(id).get("icon",id))
	return ROOT+id+(".png" if FileAccess.file_exists(ROOT+id+".png") else ".svg")

static func texture(id: String) -> Texture2D:
	id = canonical(id)
	if not names().has(id): return null
	if not textures.has(id): textures[id] = load(icon_path(id))
	return textures[id]

static func menu_texture(id: String) -> Texture2D:
	id = canonical(id)
	if not menu_textures.has(id):
		var source := texture(id)
		if source == null: return null
		var bitmap := source.get_image()
		bitmap.resize(24,24,Image.INTERPOLATE_LANCZOS)
		menu_textures[id] = ImageTexture.create_from_image(bitmap)
	return menu_textures[id]

static func markup(value: String, pixels: int = 26) -> String:
	# Only numeric resource tokens are replaced; prose and unknown resources survive.
	var result := value.replace("[", "[lb]").replace(" · ","   ").replace("·"," ")
	var aliases: Dictionary = {"광물":"stone", "부품":"research_parts"}
	for id in names(): aliases[names()[id]] = id
	var ordered: Array=aliases.keys();ordered.sort_custom(func(a: String,b: String):return a.length()>b.length())
	for word in ordered:
		if not result.contains(word): continue
		if not patterns.has(word):
			var pattern := RegEx.new()
			pattern.compile("(?<![가-힣A-Za-z])"+word+"(?=\\s+[+−-]?\\d)")
			patterns[word] = pattern
		result = patterns[word].sub(result, "[img=%dx%d]%s[/img]" % [pixels,pixels,icon_path(aliases[word])], true)
	if result.contains(" Cr"):
		if not patterns.has("currency"):
			var currency:=RegEx.new()
			currency.compile("(?<![A-Za-z0-9])([+−-]?[0-9][0-9,]*(?:\\.[0-9]+)?)\\s+Cr(?![A-Za-z])")
			patterns.currency=currency
		result=patterns.currency.sub(result,"[img=%dx%d]%scredits.svg[/img] $1"%[pixels,pixels,ROOT],true)
	return result.replace("[/img] ","[/img]\u00a0").replace(" / ","\u00a0/\u00a0")

static func view(id: String, pixels: int = 32) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture(id)
	icon.custom_minimum_size = Vector2.ONE*pixels
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = names().get(canonical(id),id)
	return icon

static func specimen_id(form: Dictionary) -> String:
	return str({"microbe":"microbe_sample","plant":"plant_sample","animal":"animal_sample"}.get(form.get("category",""),"bio_sample"))

static func button_caption(button: Button) -> void:
	var source := button.text
	var formatted := markup(source,24)
	if not formatted.contains("[img="): return
	button.custom_minimum_size.x = maxf(button.custom_minimum_size.x,button.get_minimum_size().x)
	button.tooltip_text = source
	button.text = ""
	button.custom_minimum_size.y = maxf(38,button.custom_minimum_size.y)
	var caption := RichTextLabel.new()
	caption.bbcode_enabled = true
	caption.scroll_active = false
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_top = 5
	caption.offset_left = 6
	caption.offset_right = -6
	caption.add_theme_font_size_override("normal_font_size",14)
	caption.text = "[center]"+formatted+"[/center]"
	button.add_child(caption)
