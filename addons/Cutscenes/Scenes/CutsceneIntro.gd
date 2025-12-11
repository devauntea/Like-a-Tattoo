extends Control

# After the cutscene is done, load this scene (your actual game)
@export_file("*.tscn") var next_scene_path: String

@onready var dialogue_label: Label = $VBoxContainer/DialogueLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel

var lines: Array[String] = [
	"…Urghhh… What time is it…? My head is killing me.",
	"Another day in this dump. I swear this place gets smaller every time I wake up.",
	"How long have I even been stuck here? Feels like the walls are starting to breathe.",
	"No. No more of this. There's got to be a way out of here.",
	"…Wait. That sound… a vent?",
	"Aha! I'm free! Finally—fresh air. Haven’t smelled that in ages.",
	"Huh? What's that in the distance…? Maybe it's just the fog playing tricks on me.",
	"Whatever. I can't care right now. I just need to find my way home… if home even exists anymore.",
	"A forest…? Of course it’s a forest. Nothing good ever starts in a forest.",
	"Still… something about it feels familiar. Like I've walked these paths before.",
	"…No way. It's following me again. That thing… the shadow—it's here too.",
	"Why does it always show up when I get close to leaving…?",
	"Fine. If it wants to trail behind me, let it. I’m not stopping this time.",
    "I'm getting out of here… no matter what tries to drag me back."
]


var current_index: int = 0

# --- Typewriter settings ---
@export var chars_per_second: float = 30.0  # increase for faster typing

var _is_typing: bool = false
var _current_full_text: String = ""
var _current_shown_text: String = ""
var _char_index: int = 0
var _time_accum: float = 0.0


func _ready() -> void:
	if lines.is_empty():
		dialogue_label.text = ""
		hint_label.text = ""
		return

	_start_typing_line(lines[current_index])


func _process(delta: float) -> void:
	if _is_typing:
		_time_accum += delta
		var seconds_per_char: float = 1.0 / max(chars_per_second, 1.0)
		while _time_accum >= seconds_per_char and _char_index < _current_full_text.length():
			_time_accum -= seconds_per_char
			_char_index += 1
			_current_shown_text = _current_full_text.substr(0, _char_index)
			dialogue_label.text = _current_shown_text

		# Finished typing this line
		if _char_index >= _current_full_text.length():
			_is_typing = false
			hint_label.text = "Click to continue"


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		_on_click()


func _on_click() -> void:
	if _is_typing:
		# If still typing, complete the line instantly
		_finish_current_line_immediately()
	else:
		# Line already fully visible: advance to next
		_advance_cutscene()


func _advance_cutscene() -> void:
	current_index += 1

	# End of cutscene → go to next scene
	if current_index >= lines.size():
		if next_scene_path != "":
			get_tree().change_scene_to_file(next_scene_path)
		else:
			print("Cutscene finished, but 'next_scene_path' is not set.")
		return

	_start_typing_line(lines[current_index])


func _start_typing_line(text: String) -> void:
	_current_full_text = text
	_current_shown_text = ""
	_char_index = 0
	_time_accum = 0.0
	_is_typing = true

	dialogue_label.text = ""
	hint_label.text = ""  # hide hint while typing


func _finish_current_line_immediately() -> void:
	_is_typing = false
	_char_index = _current_full_text.length()
	_current_shown_text = _current_full_text
	dialogue_label.text = _current_full_text
	hint_label.text = "Click to continue"
