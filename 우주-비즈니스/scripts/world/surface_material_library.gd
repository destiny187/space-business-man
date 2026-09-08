class_name FrontierSurfaceMaterialLibrary
extends RefCounted
## Shared linear packed texture array; independent of planet generation/save rules.
static var _config: Dictionary={}
static var _textures: Texture2DArray
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_materials.json"))
	return _config
static func textures() -> Texture2DArray:
	if _textures!=null:return _textures
	var images: Array[Image]=[]
	for row in config().materials:
		var texture:=load(str(row.texture)) as Texture2D
		var image:=texture.get_image()
		if image.is_compressed():image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		if not image.has_mipmaps():image.generate_mipmaps()
		images.append(image)
	_textures=Texture2DArray.new()
	var error:=_textures.create_from_images(images)
	assert(error==OK,"Surface texture array creation failed")
	return _textures
static func index(id: String) -> int:
	for i in config().materials.size():
		if config().materials[i].id==id:return i
	return 0
static func configure(material: ShaderMaterial,body: Dictionary) -> void:
	var cfg:=config();var traits: Dictionary=body.get("traits",{})
	var profile: Dictionary=cfg.profiles.get(traits.get("id",""),cfg.profiles.cratered)
	if profile.has("deposit_color"):
		material.set_shader_parameter("dust_color",Color(profile.deposit_color).lerp(Color(traits.get("dust",profile.deposit_color)),.2))
	material.set_shader_parameter("surface_textures",textures());material.set_shader_parameter("textured_surface",true)
	material.set_shader_parameter("rock_layer",index(profile.rock));material.set_shader_parameter("deposit_layer",index(profile.deposit))
	material.set_shader_parameter("rock_meters",float(profile.rock_meters));material.set_shader_parameter("deposit_meters",float(profile.deposit_meters))
	for key in ["normal_strength","detail_near","detail_far","snow_meters","ice_meters","freeze_start","freeze_end"]:material.set_shader_parameter(key,float(cfg[key]))
	material.set_shader_parameter("snow_layer",index("snow"));material.set_shader_parameter("ice_layer",index("ice"))
	material.set_shader_parameter("native_temperature",float(traits.get("temperature",20)))
	material.set_shader_parameter("local_temperature",float(traits.get("temperature",20)))
	# Environment water is an index; glacial geology supplies additional retained ice.
	material.set_shader_parameter("volatile_supply",clampf(float(traits.get("water",0))/55.0+(.35 if body.get("kind")=="glacial" else 0.0),0,1))
	material.set_shader_parameter("liquid_allowed",float(traits.get("pressure",0))>.05)
	material.set_shader_parameter("highlight_strength",float(cfg.highlight_strength))
static func orbital(material: ShaderMaterial,traits: Dictionary) -> void:
	material.set_shader_parameter("surface_temperature",float(traits.get("temperature",20)))
	material.set_shader_parameter("surface_water",float(traits.get("water",0))/100.0)
	material.set_shader_parameter("geology_style",{"sedimentary":1,"crystalline":2,"alkaline":3}.get(traits.get("id",""),0))
