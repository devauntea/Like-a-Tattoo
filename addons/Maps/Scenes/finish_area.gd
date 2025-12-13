extends Area3D

@export var player_group := "player"
@export var cutscene_player: AnimationPlayer
@export var cutscene_name := "end_cutscene"

var _done := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	print(body)
	if body.is_in_group(player_group):
		get_tree().change_scene_to_file("res://EndScene.tscn")
	if not body.is_in_group(player_group):
		return

	# Freeze the player (simple + safe)
	if body.has_method("set_physics_process"):
		body.set_physics_process(false)
	if body.has_method("set_process_input"):
		body.set_process_input(false)

	# Optional: hide HUD if your HUD is on the player
	var hud := body.get_node_or_null("HUD")
	if hud:
		hud.visible = false

	if cutscene_player:
		cutscene_player.play(cutscene_name)
	else:
		push_warning("FinishArea: cutscene_player not assigned")
