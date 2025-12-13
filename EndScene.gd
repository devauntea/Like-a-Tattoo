extends CanvasLayer
# or Control, but CanvasLayer in your case

@export var main_menu_scene_path: String = "res://addons/Main Menu/Scenes/MainMenu.tscn"

@onready var dialogue_label: Label = $CenterContainer/DialogueLabel
@onready var return_timer: Timer = $ReturnTimer

func _ready() -> void:
	dialogue_label.text = "I made it… I’m finally safe."
	dialogue_label.visible = true

	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	return_timer.timeout.connect(_on_return_timer_timeout)
	return_timer.start()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_on_return_timer_timeout()

func _on_return_timer_timeout() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)
