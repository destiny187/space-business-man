class_name FrontierGraphics
extends RefCounted

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics.json"))
	return _data

static func resolve(key: String) -> String:
	return key if data().profiles.has(key) else str(data().default)

static func apply(viewport: Viewport, environment: Environment, sun: DirectionalLight3D, key: String) -> Dictionary:
	var config: Dictionary = data().profiles[resolve(key)]
	viewport.msaa_3d = int(config.msaa) as Viewport.MSAA
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.mesh_lod_threshold = float(config.lod_pixels)
	environment.ssao_enabled = config.ssao
	environment.ssil_enabled = config.ssil
	environment.ssr_enabled = config.ssr
	environment.glow_enabled = config.glow
	sun.directional_shadow_max_distance = float(config.shadow_distance)
	sun.light_angular_distance = float(config.soft_sun)
	RenderingServer.directional_shadow_atlas_set_size(int(config.shadow_size),true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM if key == "high" else RenderingServer.ENV_SSAO_QUALITY_LOW,key != "high",0.5,2,60,100)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM,true,0.5,2,50,100)
	RenderingServer.screen_space_roughness_limiter_set_active(true,0.25,0.18)
	return config
