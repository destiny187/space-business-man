class_name FrontierCorporateOrbital
extends RefCounted
static func restored(body: Dictionary) -> bool:return body.get("management",{}).get("state","")=="restored"
static func apply(material: ShaderMaterial,body: Dictionary) -> void:
	if not restored(body):return
	material.set_shader_parameter("gas_bands",false)
	material.set_shader_parameter("land_color",Color("578975"));material.set_shader_parameter("sea_color",Color("286995"))
	material.set_shader_parameter("sea_level",.48);material.set_shader_parameter("molten",false)
	material.set_shader_parameter("cloud_amount",float(body.management.cloud));material.set_shader_parameter("city_strength",float(body.management.city_strength))
