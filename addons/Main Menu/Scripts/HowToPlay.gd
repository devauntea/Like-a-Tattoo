extends Control

# use file path instead of PackedScene (we already fixed cyclic issues)
@export_file("*.tscn") var main_menu_scene_path: String

@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton
@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	# play fade-in animation if it exists
	if anim_player and anim_player.has_animation("fade_in"):
		anim_player.play("fade_in")

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	else:
		push_warning("HowToPlay: BackButton not found at $MarginContainer/VBoxContainer/BackButton")


func _on_back_pressed() -> void:
	if main_menu_scene_path != "":
		get_tree().change_scene_to_file(main_menu_scene_path)
	else:
		push_warning("HowToPlay: 'main_menu_scene_path' is empty!")
