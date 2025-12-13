extends CanvasLayer

@export var main_menu_scene_path: String = "res://addons/Main Menu/Scenes/MainMenu.tscn"

@onready var dialogue_label: Label = $DialogueLabel
@onready var return_timer: Timer = $ReturnTimer

func _ready() -> void:
	# One-line insanity dialogue
	dialogue_label.text = "NO!!! Stay away from me..."
	dialogue_label.visible = true

	# Pause the game while cutscene plays
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	return_timer.timeout.connect(_on_return_timer_timeout)
	return_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	# Allow skipping with any input
	if event.is_pressed():
		_on_return_timer_timeout()

func _on_return_timer_timeout() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)
