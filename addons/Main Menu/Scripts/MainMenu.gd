extends Control

@export_file("*.tscn") var main_game_scene_path: String
@export_file("*.tscn") var how_to_play_scene_path: String

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var how_button: Button = $VBoxContainer/HowToPlayButton
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	if anim_player:
		anim_player.play("fade_in")

	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	else:
		push_warning("MainMenu: PlayButton not found at $VBoxContainer/PlayButton")

	if how_button:
		how_button.pressed.connect(_on_how_pressed)
	else:
		push_warning("MainMenu: HowToPlayButton not found at $VBoxContainer/HowToPlayButton")


func _on_play_pressed() -> void:
	if main_game_scene_path != "":
		get_tree().change_scene_to_file(main_game_scene_path)
	else:
		push_warning("MainMenu: 'main_game_scene_path' is empty!")


func _on_how_pressed() -> void:
	if how_to_play_scene_path != "":
		get_tree().change_scene_to_file(how_to_play_scene_path)
	else:
		push_warning("MainMenu: 'how_to_play_scene_path' is empty!")
