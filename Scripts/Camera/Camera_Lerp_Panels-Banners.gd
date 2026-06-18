extends Area3D

@onready var camera_target: Marker3D = $Camera_Target

var player: Player = null
var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_in_range and player != null:
		if Input.is_action_just_pressed("interact"):
			if player.is_focused:
				player.return_camera_to_player()
			else:
				player.focus_camera_to(camera_target)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player = body
		player_in_range = true


func _on_body_exited(body: Node3D) -> void:
	if body == player:
		player_in_range = false
		player = null
