class_name FrontierAtmospherePreview
extends FrontierEquipmentPreview
const Actor=preload("res://scripts/actors/creatures/bestiary_actor.gd")
func present(sample: Dictionary,dormant: bool) -> void:
	var key: String=sample.form_id+":"+sample.look_id
	if model_path==key:return
	model_path=key
	if is_instance_valid(model):stage.remove_child(model);model.queue_free()
	var form:=FrontierEcologyCatalog.form(sample.form_id)
	model=Actor.new();model.load_far=false;model.show_effects=false;stage.add_child(model)
	model.configure(form,FrontierEcologyCatalog.look(sample.form_id,sample.look_id));model.set_state("dormant" if dormant else "idle")
	var geometry: Dictionary=form.geometry.near
	var low: Vector3=Vector3(geometry.min[0],geometry.min[1],geometry.min[2])*model.base_scale
	var high: Vector3=Vector3(geometry.max[0],geometry.max[1],geometry.max[2])*model.base_scale
	model.position=-(low+high)*.5+Vector3.UP*float(geometry.floor_y)*model.base_scale
	frame_specimen(AABB(low,high-low))
	continuous_rendering=true;request_render()
	tooltip_text="대기층 확대 관측"
