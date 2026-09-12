extends SceneTree
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
var folder:="/tmp/ground-locomotion/types"
var panels: Array=[]
var report: Array=[]
func _initialize() -> void:call_deferred("run")
func floor_probe(at: Vector3,_reach: float) -> Dictionary:
	return {"point":Vector3(at.x,0,at.z),"normal":Vector3.UP}
func panel(form: Dictionary,index: int) -> Dictionary:
	var holder:=SubViewportContainer.new();root.add_child(holder);holder.position=Vector2(index%3*480,index/3*420);holder.size=Vector2(480,420)
	var viewport:=SubViewport.new();viewport.size=Vector2i(480,420);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;holder.add_child(viewport)
	var stage:=Node3D.new();viewport.add_child(stage)
	var environment:=WorldEnvironment.new();var env:=Environment.new();environment.environment=env;env.background_mode=Environment.BG_COLOR;env.background_color=Color("d3d9d5");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("b0c0cf");env.ambient_light_energy=.55;stage.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-40,0);light.shadow_enabled=true;stage.add_child(light)
	var floor:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(2000,2000);floor.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color("b8b9a5");floor.material_override=Actor.Ink.material(material,{});stage.add_child(floor)
	var creature:=Actor.new();creature.load_far=true;stage.add_child(creature);creature.configure(form);creature.set_process(false);creature.set_state("move")
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;camera.far=200;stage.add_child(camera)
	Actor.Ink.attach(stage)
	var bounds: Dictionary=form.geometry.near;var height: float=bounds.max[1]-bounds.floor_y
	var span: float=maxf(float(bounds.max[0])-float(bounds.min[0]),float(bounds.max[2])-float(bounds.min[2]))
	camera.size=maxf(height*1.4,span*1.35)
	var label:=Label.new();root.add_child(label);label.position=holder.position+Vector2(10,8);label.add_theme_color_override("font_color",Color("263838"));label.add_theme_font_size_override("font_size",15);label.text=form.id+"\n"+str(creature.ground_motion.kind)
	return {"holder":holder,"label":label,"actor":creature,"camera":camera,"height":height,"span":span,"at":Vector3.ZERO,"errors":0,"support":0}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder);root.size=Vector2i(1440,840);root.content_scale_size=root.size
	var seen: Dictionary={};var selected: Array=[]
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/ground_locomotion.json"))
	for form in FrontierEcologyCatalog.all_forms():
		if not data.forms.has(form.id):continue
		var key: String=str(form.get("collection","legacy"))+":"+str(form.get("construction",form.family))
		if seen.has(key):continue
		seen[key]=true;selected.append(form)
	for batch in range(0,selected.size(),6):
		for old in panels:old.holder.queue_free();old.label.queue_free()
		panels.clear();await process_frame
		for i in mini(6,selected.size()-batch):panels.append(panel(selected[batch+i],i))
		for frame_index in 90:
			for p in panels:
				var creature: Node3D=p.actor;var m: RefCounted=creature.ground_motion
				p.at.z+=m.leg_length*.75/60.0
				creature.drive_ground(p.at,Basis.IDENTITY,1.0/60,floor_probe,false);creature.pose()
				var target: Vector3=m.point+Vector3.UP*float(p.height)*.5
				p.camera.global_position=target+Vector3(4,2,4)*maxf(.5,float(p.span)/3);p.camera.look_at(target)
				if frame_index==65:creature.lod_override=1;creature.set_lod(true)
				for c in m.contacts:
					if c.ready and not c.swing:
						p.support+=1
						if float(c.get("error",0))>.18:p.errors+=1
			if frame_index in [45,75]:
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(folder+"/types-%02d-%s.png"%[batch/6,"near" if frame_index==45 else "far"])
		for p in panels:
			report.append({"id":p.actor.definition.id,"kind":p.actor.ground_motion.kind,"limbs":p.actor.ground_motion.limbs.size(),"large_contact_errors":p.errors,"support_samples":p.support})
		print("GAIT_TYPE_PAGE ",batch/6," ",mini(batch+6,selected.size()),"/",selected.size())
	var output:=FileAccess.open(folder+"/types.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("GROUND_GAIT_TYPES ",selected.size());quit()
