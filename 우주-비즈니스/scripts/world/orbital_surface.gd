class_name FrontierOrbitalSurface
extends RefCounted
## Cached authored maps: loaded only for bodies present in the current view.
static var _config: Dictionary={}
static var _detail: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/orbital_surface_quality.json"))
	return _config
static func detail(id: String) -> Texture2D:
	if _detail.has(id):return _detail[id]
	# The existing ground packed maps are linear and shared; add mipmaps once.
	var source:=load("res://assets/textures/surfaces/"+id+".png") as Texture2D
	var image:=source.get_image()
	if image.is_compressed():image.decompress()
	if not image.has_mipmaps():image.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(image);_detail[id]=texture
	return texture
static func configure(material: ShaderMaterial,id: String,solar: bool=false) -> void:
	var cfg:=config()
	material.set_shader_parameter("orbital_maps_enabled",true)
	material.set_shader_parameter("orbital_color" if solar else "orbital_relief",load("res://assets/textures/orbital/"+id+".png"))
	var profile: Dictionary=FrontierSurfaceMaterialLibrary.config().profiles.get(id,{})
	var detail_id: String=cfg.solar_detail.get(id,"sand") if solar else profile.get("rock","sand")
	if id in ["frozen","tundra"]:detail_id="ice" if id=="frozen" else "snow"
	material.set_shader_parameter("orbital_detail",detail(detail_id))
	for key in ["medium_scale","fine_scale","detail_strength","bump_strength"]:material.set_shader_parameter("orbital_"+key,float(cfg[key]))
