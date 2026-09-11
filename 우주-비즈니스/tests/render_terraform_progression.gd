extends "res://tests/test_crew_surface.gd"
const Recovery=preload("res://scripts/world/terraform_surface_material.gd")
var folder:="res://../docs/production/media/terraform-surfaces/progression"
var records: Dictionary={}
func capture(surface: FrontierCrewSurfaceScene,world: Dictionary,id: String,delay: float=1.0) -> void:
 surface.business_view.accept(world.business);surface.presence.accept(world.business);surface.hydrology.accept(world.business)
 await create_timer(delay).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder+"/"+id+".png")
 var site: Dictionary=world.business.sites[surface.body.id]
 var c:=FrontierFreeTerraform.sample(site,Vector2(30,28))
 records[id]={"environment":c.environment.duplicate(),"restoration":c.restoration2.duplicate(),"inventory":site.inventory.duplicate(),"revision":site.free_terraform.revision}
func measure(mat: ShaderMaterial,enabled: bool) -> Dictionary:
 mat.set_shader_parameter("recovery_surface_enabled",enabled)
 for i in 20:await process_frame
 var frames: Array[float]=[];var last:=Time.get_ticks_usec()
 for i in 120:
  await process_frame
  var now:=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
 frames.sort()
 return {"enabled":enabled,"median_ms":frames[60],"p95_ms":frames[114],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"gpu_ms":null}
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var preferences:=FrontierClientSettings.ensure(self);preferences.values=FrontierClientSettings.DEFAULTS.duplicate()
 for group in preferences.graphics_groups():preferences._merge_quality(group,2 if group=="anti_aliasing" else 1)
 preferences.values.fps=0;preferences.values.vsync=false;preferences.values.volume=.15;preferences.apply_all()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var core:=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("복원 지면 검수",0)
 check(core.start(FrontierUniverse.new_world(91723),owner,persist),"isolated world")
 core.world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));core.world.terrain_settings_hash=FrontierUniverse.fingerprint(core.world.terrain_settings)
 var body: Dictionary={}
 for i in range(8,5000):
  var candidate:=FrontierUniverse.body(core.world.manifest,i)
  if int(candidate.planet_tier)==2 and candidate.get("traits",{}).get("id","")=="oxidized":body=candidate;break
 check(not body.is_empty(),"T2 dry family")
 if body.is_empty():quit(1);return
 core.world.location=body.id;core.world.crew.landing={"body_id":body.id,"epoch":1};core.world.crew.members[owner.character_id].area="surface";core.world.crew.members[owner.character_id].aboard=false
 core.world.ecology=FrontierEcology.create();FrontierEcology.ensure_planet(core.world.ecology,body);FrontierPlanetaryCycles.ensure_region(core.world,body)
 core.world.business=FrontierExpeditionBusiness.create();var site:=FrontierExpeditionBusiness.ensure_site(core.world)
 check(FrontierFreeTerraform.active(site),"saved free restoration")
 # Prepared climate/stock/installations isolate surface progression; stages use the real production function.
 site.free_terraform.base.merge({"temperature":18.0,"pressure":1.0,"oxygen":.21,"toxicity":0.0,"water":0.0,"ecology":0.0},true)
 site.free_terraform.restoration={"soil":10.0,"salinity":65.0}
 site.environment=site.free_terraform.base.duplicate();site.restoration2=site.free_terraform.restoration.duplicate()
 for i in site.free_terraform.air.size():site.free_terraform.air[i]=[.21,1.0,0.0]
 site.free_terraform.cells.clear();FrontierFreeTerraform.ensure_cells(site,body,Vector2(30,28),42)
 site.inventory.ice=5000;site.inventory.mineral_filter=5000;site.inventory.soil_base=5000
 var water: Dictionary={"id":"review-water","type":"water","tier":2,"position":[18,2,20],"yaw":0.0,"enabled":true,"active":true,"status":"급수","work":0.0,"region_id":"region:0"}
 var soil: Dictionary={"id":"review-soil","type":"biolab","tier":2,"position":[43,2,20],"yaw":0.0,"enabled":true,"active":true,"status":"토양 개량","work":0.0,"region_id":"region:0"}
 site.buildings={water.id:water,soil.id:soil};site.state="active"
 for key in site.free_terraform.cells:site.free_terraform.soil_winners[key]={"id":soil.id,"strength":1.0}
 var viewer:=Node3D.new();root.add_child(viewer);viewer.position=Vector3(30,3,38)
 core.world.crew.members[owner.character_id].position=[30,3,38]
 var session:=FrontierCrewSession.new();session.hosting=true;session.active=true;session.authority=core;session.manifest=core.world.manifest;session.latest={"crew":core.world.crew,"self_id":owner.character_id};root.add_child(session);session.set_process(false)
 var camera:=Camera3D.new();viewer.add_child(camera);camera.current=true;camera.far=2600;camera.look_at_from_position(Vector3(30,4.7,42),Vector3(30,2,22))
 var surface:=FrontierCrewSurfaceScene.new();root.add_child(surface);surface.configure(session,FrontierCrewSurfaceReplica.packet(core.world,owner.character_id),viewer,camera);FrontierInkStyle.attach(surface)
 var deadline:=Time.get_ticks_msec()+90000
 while Time.get_ticks_msec()<deadline:
  await process_frame
  if surface.terrain.ready_for([viewer.position]) and surface.distant.build_count>0 and surface.distant.task_id==-1:break
 check(surface.terrain.ready_for([viewer.position]) and surface.distant.build_count>0,"real ground streamed")
 surface.set_process(false);surface.lamp.light_energy=0;surface.environment.fog_enabled=false;surface.environment.background_mode=Environment.BG_COLOR;surface.environment.background_color=Color("819194");surface.environment.ambient_light_energy=.55
 surface.atmosphere.sun.rotation_degrees=Vector3(-42,-32,0);surface.atmosphere.sun.light_energy=1.5;surface.atmosphere.sun.light_color=Color("ffedda")
 var mat: ShaderMaterial=surface.terrain.material
 var texture: Texture2DArray=mat.get_shader_parameter("recovery_textures")
 check(texture!=null and texture.get_layers()==2 and texture.get_width()==512,"two bounded recovery maps")
 check((mat.get_shader_parameter("surface_textures") as Texture2DArray).get_layers()<=6,"native palette remains bounded")
 await capture(surface,core.world,"0-barren")
 var water_cells:=FrontierFreeTerraform.covered(site,water);var soil_cells:=FrontierFreeTerraform.covered(site,soil)
 for stage in 3:
  for i in 250:
   var c:=FrontierFreeTerraform.sample(site,Vector2(30,28))
   if (stage==0 and float(c.environment.water)>=35) or (stage==1 and float(c.restoration2.soil)>=65) or (stage==2 and float(c.environment.ecology)>=80):break
   FrontierFreeTerraform.local_machine(core.world,site,body,water,water_cells,10)
   if stage>0:FrontierFreeTerraform.local_machine(core.world,site,body,soil,soil_cells,10)
  FrontierFreeTerraform.finish(site,1.0)
  await capture(surface,core.world,["1-hydrated","2-amended","3-established"][stage],12.0 if stage==2 else 1.0)
 check(float(records["1-hydrated"].environment.water)>float(records["0-barren"].environment.water),"actual water delivery")
 check(float(records["2-amended"].restoration.soil)>float(records["1-hydrated"].restoration.soil),"actual soil amendment")
 check(float(records["3-established"].environment.ecology)>=80,"actual ecological establishment")
 check(int(site.inventory.ice)<5000 and int(site.inventory.soil_base)<5000 and int(site.inventory.mineral_filter)<5000,"real inputs consumed")
 var copy: Dictionary=JSON.parse_string(JSON.stringify(site));var copy_mat:=ShaderMaterial.new();copy_mat.shader=mat.shader
 FrontierSurfaceRecovery.shader_regions(copy_mat,body,{"sites":{body.id:copy}})
 check(copy_mat.get_shader_parameter("original_surface_state")==mat.get_shader_parameter("original_surface_state"),"saved original conditions reproduce")
 check(copy_mat.get_shader_parameter("free_values").get_image().get_data()==mat.get_shader_parameter("free_values").get_image().get_data(),"saved progress reproduces GPU inputs")
 # Fixed final geometry, isolated shader on/off cost; this is not gameplay FPS.
 surface.process_mode=Node.PROCESS_MODE_DISABLED
 var timing: Array=[]
 for enabled in [false,true,true,false]:timing.append(await measure(mat,enabled))
 mat.set_shader_parameter("recovery_surface_enabled",true)
 FileAccess.open(folder+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"body":body.id,"stages":records,"timing":timing,"scope":"Prepared T2 climate/installations/stock; stages from production local_machine; actual CrewSurfaceScene; Medium 1280x800; shader-only ABBA comparison"},"  "))
 # This prepared visual fixture is not a valid gameplay save; suppress session shutdown saving.
 session.hosting=false;session.active=false
 print("TERRAFORM_SURFACE_CHECKS ",checks," FAILURES ",failures)
 quit(1 if failures else 0)
