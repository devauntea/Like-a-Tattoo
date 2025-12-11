extends Node

var player: AudioStreamPlayer

# Set your menu music file path here:
const MUSIC_PATH := "res://addons/Main Menu/Audio/MainMenuAudio.wav"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	
	player = AudioStreamPlayer.new()
	add_child(player)

	player.stream = preload(MUSIC_PATH)
	player.volume_db = 0.0  # adjust volume if needed
	player.autoplay = false

	if player.stream and not player.playing:
		player.play()
