extends Node3D

@export var screen_mesh: MeshInstance3D
@export var screen_surface_index: int = 0


@export var player: Player


@export var background_audio: AudioStreamPlayer

@export var ducked_volume_db: float = -35.0
@export var audio_fade_time: float = 0.4
@export var screen_emission_energy: float = 1.0

@onready var camera_position: Marker3D = $CameraPosition
@onready var viewport: SubViewport = $SubViewport
@onready var video_player: VideoStreamPlayer = $SubViewport/VideoStreamPlayer

var video_started: bool = false
var original_background_volume_db: float = 0.0
var audio_tween: Tween = null


func _ready() -> void:
	if background_audio != null:
		original_background_volume_db = background_audio.volume_db

	if video_player.has_signal("finished"):
		video_player.finished.connect(_on_video_finished)

	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	video_player.stop()
	_apply_viewport_to_screen()


func _process(_delta: float) -> void:
	if player == null:
		return

	if Input.is_action_just_pressed("play") and _can_play_video():
		_toggle_video()


func _can_play_video() -> bool:
	if player == null:
		return false

	if not player.is_focused:
		return false

	# The video can play only when the guided camera is focused
	# on this kiosk's own CameraPosition marker.
	return player.current_focus_target == camera_position


func _apply_viewport_to_screen() -> void:
	if screen_mesh == null:
		push_warning("No screen mesh assigned on IpadKiosk.")
		return

	var viewport_texture: ViewportTexture = viewport.get_texture()

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.resource_local_to_scene = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewport_texture

	mat.emission_enabled = true
	mat.emission_texture = viewport_texture
	mat.emission_energy_multiplier = screen_emission_energy

	screen_mesh.set_surface_override_material(screen_surface_index, mat)


func _toggle_video() -> void:
	if not video_started:
		video_player.play()
		video_started = true
		duck_background_audio()
		return

	video_player.paused = not video_player.paused

	if video_player.paused:
		restore_background_audio()
	else:
		duck_background_audio()


func duck_background_audio() -> void:
	if background_audio == null:
		return

	if audio_tween != null:
		audio_tween.kill()

	audio_tween = create_tween()
	audio_tween.tween_property(
		background_audio,
		"volume_db",
		ducked_volume_db,
		audio_fade_time
	)


func restore_background_audio() -> void:
	if background_audio == null:
		return

	if audio_tween != null:
		audio_tween.kill()

	audio_tween = create_tween()
	audio_tween.tween_property(
		background_audio,
		"volume_db",
		original_background_volume_db,
		audio_fade_time
	)


func _on_video_finished() -> void:
	video_started = false
	restore_background_audio()
