extends PanelContainer
var flight: FrontierCrewFlightView
var preview: FrontierAtmospherePreview
var heading: Label
var detail: Label
var progress: ProgressBar
var confirmed:=""
func configure(view: FrontierCrewFlightView) -> void:
	flight=view;mouse_filter=Control.MOUSE_FILTER_IGNORE
	theme=FrontierInterfaceStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left=-360;offset_right=-24;offset_top=-470;offset_bottom=-120
	var column:=VBoxContainer.new();add_child(column)
	heading=FrontierInterfaceStyle.label(column,"대기층 확대 관측",18)
	preview=load("res://scripts/ui/atmosphere_preview.gd").new();preview.custom_minimum_size=Vector2(300,235);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(preview)
	progress=ProgressBar.new();progress.max_value=1;progress.show_percentage=false;progress.custom_minimum_size.y=5;column.add_child(progress)
	detail=FrontierInterfaceStyle.label(column,"",13);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for child in column.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hide()
func update(body: Dictionary,scan: Dictionary,blocked: bool) -> void:
	visible=not blocked and not body.is_empty()
	if not visible:return
	var active: bool=scan.get("kind","")=="atmosphere" and scan.get("body_id","")==body.id
	var sample: Dictionary=scan.get("sample",{}) if active else {}
	preview.visible=not sample.is_empty()
	progress.value=float(scan.get("progress",0)) if active else 0.0
	heading.text="대기층 확대 관측"
	if active and not sample.is_empty():
		preview.present(sample,scan.get("origin","")=="dormant")
		if scan.get("known",false):
			heading.text=FrontierEcologyCatalog.form(sample.form_id).name
			detail.text="관측 기록 저장  J 도감\nE를 놓고 다시 유지하면 다음 신호 조사"
		else:detail.text="생체 구조 분석 중  E 유지"
	elif active and scan.get("known",false):detail.text="관측 가능한 생명 신호 없음" if scan.get("empty",true) else "현재 관측 가능한 종을 모두 기록했습니다."
	else:detail.text="E 유지  부유 생명 신호 조사\n착륙할 수 없는 대기층입니다."
	if active and scan.get("known",false) and confirmed!=scan.id:
		confirmed=scan.id;flight.soundscape.complete()
