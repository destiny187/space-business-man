extends SubViewportContainer
## A real INK Kestrel remains in front of the loading atmosphere.
var viewport: SubViewport
var stage: Node3D
var hull: Node3D
var camera: Camera3D
var drive: FrontierVesselDriveEffects
var refits: FrontierVesselVisuals
var light: DirectionalLight3D
func configure(vessel: Dictionary) -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE;stretch=true
 viewport=SubViewport.new();viewport.own_world_3d=true;viewport.transparent_bg=true
 viewport.msaa_3d=Viewport.MSAA_2X;viewport.screen_space_aa=Viewport.SCREEN_SPACE_AA_FXAA
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 stage=Node3D.new();viewport.add_child(stage)
 var world:=WorldEnvironment.new();var environment:=Environment.new()
 environment.background_mode=Environment.BG_CLEAR_COLOR
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("a2b5c5");environment.ambient_light_energy=.28
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;world.environment=environment;stage.add_child(world)
 light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-30,0);light.light_color=Color("ffe1b5");light.light_energy=1.8;stage.add_child(light)
 hull=load("res://assets/models/ships/kestrel.glb").instantiate();stage.add_child(hull);FrontierInkStyle.apply(hull,{})
 refits=FrontierVesselVisuals.new();hull.add_child(refits);refits.update_loadout(vessel)
 drive=FrontierVesselDriveEffects.new();hull.add_child(drive);drive.set_thrust(.65,false)
 camera=Camera3D.new();camera.near=.05;camera.far=500;stage.add_child(camera);camera.make_current()
 var contour:=FrontierInkStyle.attach(stage,true);contour.set_shader_parameter("transparent_background",true)
func match_view(source: Node3D,source_camera: Camera3D) -> void:
 camera.transform=source.global_transform.affine_inverse()*source_camera.global_transform
 camera.transform=Transform3D(camera.basis.orthonormalized(),camera.position)
 camera.fov=source_camera.fov
func set_entry_direction(downward: bool) -> void:
 for jet in drive.jets:jet.process_material.direction=Vector3.DOWN if downward else Vector3.BACK
func release() -> void:
 viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 queue_free()
