extends Control

# UI References
# Remove board game setting references
# @onready var player_count_spinner = $VBoxContainer/SettingsContainer/PlayerCountContainer/PlayerCountSpinner
# @onready var turn_count_spinner = $VBoxContainer/SettingsContainer/TurnCountContainer/TurnCountSpinner
# @onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var minigames_button = $VBoxContainer/MinigamesButton

func _ready():
	# Connect button signals
	# Remove start button connection
	# start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	minigames_button.pressed.connect(_on_minigames_button_pressed)
	
	# Remove setting default values
	# player_count_spinner.value = 4
	# turn_count_spinner.value = 1
	
	# Start background music
	AudioServer.set_bus_volume_linear(1, 0.6)
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

# Open minigame selection menu
func _on_minigames_button_pressed():
	get_tree().change_scene_to_file("res://scenes/minigame_select.tscn")

# Remove credits function for now
# func _on_credits_button_pressed():
# 	# TODO: Implement credits screen
# 	pass 
