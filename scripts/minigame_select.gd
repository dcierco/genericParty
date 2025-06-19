extends Control

@onready var minigame_list = $MarginContainer/VBoxContainer/MinigameList
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionPanel/Description
@onready var back_button = $MarginContainer/VBoxContainer/ButtonPanel/BackButton
@onready var play_button = $MarginContainer/VBoxContainer/ButtonPanel/PlayButton
@onready var random_button = $MarginContainer/VBoxContainer/ButtonPanel/RandomButton

var selected_minigame: String = ""

func _ready():
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	random_button.pressed.connect(_on_random_button_pressed)
	minigame_list.item_selected.connect(_on_minigame_selected)
	
	# Populate minigame list
	populate_minigame_list()
	
	# Start background music
	$BackgroundMusic.play()

# Fill the list with available minigames
func populate_minigame_list():
	minigame_list.clear()
	
	for minigame_id in MinigameManager.available_minigames:
		var minigame_data = MinigameManager.available_minigames[minigame_id]
		minigame_list.add_item(minigame_data.name)
		minigame_list.set_item_metadata(minigame_list.get_item_count() - 1, minigame_id)
	
	# Select first item by default if there are minigames
	if minigame_list.get_item_count() > 0:
		minigame_list.select(0)
		_on_minigame_selected(0)
	else:
		description_label.text = "No minigames available"
		play_button.disabled = true
		random_button.disabled = true

# Handle minigame selection
func _on_minigame_selected(index):
	selected_minigame = minigame_list.get_item_metadata(index)
	
	if MinigameManager.available_minigames.has(selected_minigame):
		var minigame_data = MinigameManager.available_minigames[selected_minigame]
		description_label.text = minigame_data.description
		play_button.disabled = false
	else:
		description_label.text = "Invalid minigame"
		play_button.disabled = true

# Return to main menu
func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Play randomly selected minigame
func _on_random_button_pressed():
	setup_players()
	var random_minigame = MinigameManager.select_random_minigame()
	start_minigame(random_minigame)

# Start selected minigame
func _on_play_button_pressed():
	setup_players()
	start_minigame(selected_minigame)

# Set up player data for the minigame
func setup_players():
	var player_count = 2
	
	# Create dummy players in the GameManager for testing
	GameManager.players.clear()
	for i in range(player_count):
		GameManager.players.append(GameManager.PlayerData.new(i, "Player " + str(i+1)))
	
	# Set current game state to minigame
	GameManager.current_state = GameManager.GameState.MINIGAME

# Start a specific minigame
func start_minigame(minigame_id: String):
	if minigame_id.is_empty() or not MinigameManager.available_minigames.has(minigame_id):
		push_error("Invalid minigame ID: " + minigame_id)
		return
		
	# Show loading feedback
	description_label.text = "Loading minigame..."
	play_button.disabled = true
	random_button.disabled = true
	
	# Start the selected minigame
	MinigameManager.start_minigame(minigame_id)
	
	# Hide this screen
	visible = false
	
	# Connect to minigame completion to show this screen again
	if MinigameManager.minigame_instance and MinigameManager.minigame_instance.has_signal("minigame_completed"):
		MinigameManager.minigame_instance.minigame_completed.connect(_on_minigame_completed)

# Show this screen again after minigame finishes
func _on_minigame_completed(_results):
	visible = true
	
	# Re-enable buttons
	play_button.disabled = false
	random_button.disabled = false
	
	# Start background music
	AudioServer.set_bus_volume_linear(2, 0)
	AudioServer.set_bus_volume_linear(1, 0.5)
	$BackgroundMusic.play()
	
	# Update description to show last result
	if not _results.is_empty():
		var result_text = ""
		
		# Check if minigame_id exists in results to avoid crash
		if _results.has("minigame_id") and MinigameManager.available_minigames.has(_results.minigame_id):
			result_text = "Last game: " + MinigameManager.available_minigames[_results.minigame_id].name + "\n"
		else:
			result_text = "Last game completed\n"
			
		result_text += "Results:\n"
		
		if _results.has("ranking"):
			for player_rank in _results.ranking:
				var player_id = player_rank.player_id
				var score = player_rank.score
				result_text += "Player " + str(player_id + 1) + ": " + str(score) + "\n"
		else:
			for player_id in _results:
				if typeof(player_id) == TYPE_INT:
					result_text += "Player " + str(player_id + 1) + ": " + str(_results[player_id]) + "\n"
			
		description_label.text = result_text 
