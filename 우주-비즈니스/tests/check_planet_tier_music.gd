extends SceneTree
class AudioFixture extends Node:
 var session: Dictionary={"active":true,"latest":{"phase":"playing","crew":{"landing":{},"navigation":{}},"location":""},"manifest":{}}
 var arrival: Dictionary={"active":false}
 var menu:=false
 func any_menu_open() -> bool:return menu
func _initialize() -> void:run.call_deferred()
func run() -> void:
 root.size=Vector2i(1200,800)
 var fixture:=AudioFixture.new();root.add_child(fixture)
 fixture.session.manifest=FrontierUniverse.generate(71491)
 var audio: Node=load("res://scripts/app/expedition_audio.gd").new();fixture.add_child(audio);audio.configure(fixture)
 var panel:=PanelContainer.new();panel.theme=FrontierInterfaceStyle.theme();panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(panel)
 var grid:=GridContainer.new();grid.columns=3;panel.add_child(grid)
 for id in ["discoveries/buried_aqueduct","discoveries/illuti_dormant_combat_robot","previews/bio_spore_fungus_18","previews/ore_refinery","previews/bio_mantid_01","previews/terraform3/source_control"]:
  var tile:=FrontierItemTile.new();tile.custom_minimum_size=Vector2(380,370);tile.picture=load("res://assets/ui/"+id+".png");tile.caption=id.get_file();grid.add_child(tile)
 var bodies: Dictionary={}
 for ordinal in range(0,1000000,37):
  var body:=FrontierUniverse.body(fixture.session.manifest,ordinal)
  if not bodies.has(int(body.planet_tier)):bodies[int(body.planet_tier)]=body
  if bodies.size()==5:break
 assert(bodies.size()==5)
 var tiers: Array=[1] if "--stop-only" in OS.get_cmdline_user_args() else [1,2,3,4,5]
 for tier in tiers:
  DisplayServer.window_move_to_foreground()
  fixture.session.latest.crew.landing={"body_id":bodies[tier].id};fixture.session.latest.location=bodies[tier].id
  await create_timer(3.3).timeout
  assert(audio.current_mood=="planet_t"+str(tier))
  var player: AudioStreamPlayer=audio.music[audio.current_mood]
  assert(player.playing and player.stream.get_length()>119)
  print("MUSIC_SIGNAL ",tier," ",AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Music"),0))
  var position:=player.get_playback_position();fixture.menu=true;await create_timer(.4).timeout
  assert(player.stream_paused and absf(player.get_playback_position()-position)<.15)
  fixture.menu=false
  print("PLANET_TIER_MUSIC ",tier," duration=",player.stream.get_length()," peak=",AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Music"),0))
 fixture.session.latest.crew.landing={};await create_timer(3).timeout;assert(audio.current_mood=="space")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/production/media/transparent-ui-tier-music/game-ui.png"))
 fixture.session.active=false;await create_timer(.1).timeout
 for player in audio.music.values():assert(not player.playing)
 print("PLANET_TIER_MUSIC_OK: ",tiers,", menu pause, space return, stop")
 quit()
