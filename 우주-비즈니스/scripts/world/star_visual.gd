class_name FrontierStarVisual
extends Node3D
var profile: Dictionary
static var _rules: Dictionary={}
static func appearance(system: Dictionary) -> Dictionary:
	if _rules.is_empty():_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/star_visuals.json"))
	var family: String="yellow"
	if int(system.ordinal)>0:
		if FrontierUniverse.derive(int(system.seed),"stellar-activity-v1")%5==0:family="active"
		elif system.star.spectral_type=="M":family="red"
		elif system.star.spectral_type in ["F","A"]:family="blue"
	var result: Dictionary=_rules.profiles[family].duplicate(true);result.id=family
	result.seed=float(FrontierUniverse.derive(int(system.seed),"stellar-surface-v1")%65536)/1024.0
	return result
func configure(system: Dictionary,radius: float) -> void:
	profile=appearance(system)
	var star:=MeshInstance3D.new();star.name="StellarSurface"
	var sphere:=SphereMesh.new();sphere.radius=radius;sphere.height=radius*2;sphere.radial_segments=128;sphere.rings=64;star.mesh=sphere
	var surface:=ShaderMaterial.new();surface.shader=load("res://assets/materials/space/star.gdshader")
	for key in ["mode","surface_speed","cell_scale","radiance","limb_darkening"]:surface.set_shader_parameter(key,profile[key])
	surface.set_shader_parameter("seed_offset",profile.seed);surface.set_shader_parameter("tint",Color(profile.tint));star.material_override=surface;add_child(star)
	var corona:=MeshInstance3D.new();corona.name="StellarCorona"
	var disc:=QuadMesh.new();disc.size=Vector2.ONE*radius*5;corona.mesh=disc
	var glow:=ShaderMaterial.new();glow.shader=load("res://assets/materials/space/glow.gdshader")
	glow.set_shader_parameter("mode",profile.mode);glow.set_shader_parameter("seed_offset",profile.seed);glow.set_shader_parameter("tint",Color(profile.tint));glow.set_shader_parameter("strength",profile.corona_strength)
	corona.material_override=glow;corona.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(corona)
	var sunlight:=OmniLight3D.new();sunlight.light_color=Color(profile.light_tint);sunlight.light_energy=float(FrontierOrbitalPresentation.config().lighting.stellar_energy);sunlight.omni_range=90000;sunlight.omni_attenuation=.25;add_child(sunlight)
