extends Control

# UI References
@onready var play_button = $VBoxContainer/PlayButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var minigames_button = $VBoxContainer/MinigamesButton

func _ready():
	# Connect button signals
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	minigames_button.pressed.connect(_on_minigames_button_pressed)
	
	# Remove setting default values
	# player_count_spinner.value = 4
	# turn_count_spinner.value = 1
	
	# Start background music
	AudioServer.set_bus_volume_linear(1, 0.5)
	$BackgroundMusic.play()

# Remove board game start function
# func _on_start_button_pressed():
# 	var player_count = int(player_count_spinner.value)
# 	var turn_count = int(turn_count_spinner.value)
# 	
# 	# Initialize game with selected settings
# 	GameManager.start_new_game(player_count, turn_count)
# 	
# 	# Load board scene
# 	get_tree().change_scene_to_file("res://scenes/board/main_board.tscn")

# Quit game
func _on_quit_button_pressed():
	get_tree().quit()

# Start party mode (play all games with global scoring)
func _on_play_button_pressed():
	# Initialize global party mode
	GlobalScoreManager.start_party_mode()
	get_tree().change_scene_to_file("res://scenes/minigame_select.tscn")

# Open minigame selection menu
func _on_minigames_button_pressed():
	get_tree().change_scene_to_file("res://scenes/minigame_select.tscn")

# Remove credits function for now
# func _on_credits_button_pressed():
# 	# TODO: Implement credits screen
# 	pass 
