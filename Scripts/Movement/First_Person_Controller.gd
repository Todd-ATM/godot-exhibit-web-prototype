class_name Player
extends CharacterBody3D

@export_range(1, 20, 0.5) var speed: float = 4.0
@export_range(10, 200, 1) var acceleration: float = 60.0
@export_range(0.1, 3.0, 0.1, "or_greater") var camera_sens: float = 1.0

@export var focus_lerp_speed: float = 5.0


@export var presentation_markers: Array[Node3D] = []

# Footsteps
@export var footstep_min_interval: float = 0.32
@export var footstep_max_interval: float = 0.48
@export var footstep_pitch_min: float = 0.88
@export var footstep_pitch_max: float = 1.12
@export var footstep_volume_db: float = -24.0
@export var footstep_volume_random_min: float = -1.5
@export var footstep_volume_random_max: float = 0.5

@onready var camera: Camera3D = $Head/Camera3D
@onready var footstep_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var mouse_captured: bool = false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_dir: Vector2 = Vector2.ZERO
var look_dir: Vector2 = Vector2.ZERO

var walk_vel: Vector3 = Vector3.ZERO
var grav_vel: Vector3 = Vector3.ZERO

var footstep_timer: float = 0.0

var is_focused: bool = false
var is_lerping: bool = false
var current_focus_target: Node3D = null

var saved_camera_transform: Transform3D
var target_camera_transform: Transform3D

var guided_walkthrough_active: bool = false
var current_marker_index: int = -1


func _ready() -> void:
	randomize()

	if footstep_player != null:
		footstep_player.volume_db = footstep_volume_db

	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit"):
		get_tree().quit()

	if event.is_action_pressed("start_walkthrough"):
		start_guided_walkthrough()

	if event.is_action_pressed("next_marker"):
		go_to_next_marker()

	if event.is_action_pressed("previous_marker"):
		go_to_previous_marker()

	if event.is_action_pressed("end_walkthrough"):
		end_guided_walkthrough()

	if event is InputEventMouseMotion and mouse_captured and not is_focused:
		look_dir = event.relative * 0.001
		_rotate_camera()


func _physics_process(delta: float) -> void:
	if is_focused:
		velocity = Vector3.ZERO
		return

	velocity = _walk(delta) + _gravity(delta)
	move_and_slide()

	_handle_footsteps(delta)


func _process(delta: float) -> void:
	if is_lerping:
		camera.global_transform = camera.global_transform.interpolate_with(
			target_camera_transform,
			focus_lerp_speed * delta
		)

		var distance_to_target: float = camera.global_transform.origin.distance_to(
			target_camera_transform.origin
		)

		if distance_to_target < 0.03:
			camera.global_transform = target_camera_transform
			is_lerping = false


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func _rotate_camera(sens_mod: float = 1.0) -> void:
	rotation.y -= look_dir.x * camera_sens * sens_mod

	camera.rotation.x = clampf(
		camera.rotation.x - look_dir.y * camera_sens * sens_mod,
		deg_to_rad(-85.0),
		deg_to_rad(85.0)
	)


func _walk(delta: float) -> Vector3:
	move_dir = Input.get_vector("left", "right", "forward", "backward")

	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x

	var walk_dir: Vector3 = (right * move_dir.x + forward * -move_dir.y).normalized()

	walk_vel = walk_vel.move_toward(
		walk_dir * speed * move_dir.length(),
		acceleration * delta
	)

	return walk_vel


func _gravity(delta: float) -> Vector3:
	if is_on_floor():
		grav_vel = Vector3.ZERO
	else:
		grav_vel.y -= gravity * delta

	return grav_vel


func focus_camera_to(target: Node3D) -> void:
	if target == null:
		return


	if not is_focused:
		saved_camera_transform = camera.global_transform

	is_focused = true
	is_lerping = true
	current_focus_target = target

	velocity = Vector3.ZERO
	target_camera_transform = target.global_transform


func return_camera_to_player() -> void:
	is_focused = false
	is_lerping = true
	current_focus_target = null
	target_camera_transform = saved_camera_transform


func start_guided_walkthrough() -> void:
	if presentation_markers.is_empty():
		push_warning("No presentation markers assigned.")
		return

	guided_walkthrough_active = true
	current_marker_index = 0
	focus_camera_to(presentation_markers[current_marker_index])


func go_to_next_marker() -> void:
	if presentation_markers.is_empty():
		return

	if not guided_walkthrough_active:
		start_guided_walkthrough()
		return

	current_marker_index += 1

	if current_marker_index >= presentation_markers.size():
		current_marker_index = presentation_markers.size() - 1
		return

	focus_camera_to(presentation_markers[current_marker_index])


func go_to_previous_marker() -> void:
	if presentation_markers.is_empty():
		return

	if not guided_walkthrough_active:
		start_guided_walkthrough()
		return

	current_marker_index -= 1

	if current_marker_index < 0:
		current_marker_index = 0
		return

	focus_camera_to(presentation_markers[current_marker_index])


func end_guided_walkthrough() -> void:
	if not is_focused:
		return

	guided_walkthrough_active = false
	current_marker_index = -1
	return_camera_to_player()


func _handle_footsteps(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	var is_moving: bool = horizontal_speed > 0.2
	var grounded: bool = is_on_floor()

	if not is_moving or not grounded:
		footstep_timer = 0.0
		return

	footstep_timer -= delta

	if footstep_timer <= 0.0:
		_play_footstep()

		var speed_factor: float = clampf(horizontal_speed / speed, 0.6, 1.4)
		var random_interval: float = randf_range(footstep_min_interval, footstep_max_interval)

		footstep_timer = random_interval / speed_factor


func _play_footstep() -> void:
	if footstep_player == null:
		return

	footstep_player.pitch_scale = randf_range(footstep_pitch_min, footstep_pitch_max)
	footstep_player.volume_db = footstep_volume_db + randf_range(
		footstep_volume_random_min,
		footstep_volume_random_max
	)

	footstep_player.play()
