extends Control

@onready var minigame_list = $MarginContainer/VBoxContainer/MinigameList
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionPanel/Description
@onready var back_button = $MarginContainer/VBoxContainer/ButtonPanel/BackButton
@onready var play_button = $MarginContainer/VBoxContainer/ButtonPanel/PlayButton
@onready var random_button = $MarginContainer/VBoxContainer/ButtonPanel/RandomButton
@onready var player1_score = $MarginContainer/VBoxContainer/GlobalScorePanel/ScoreContainer/Player1Score
@onready var player2_score = $MarginContainer/VBoxContainer/GlobalScorePanel/ScoreContainer/Player2Score
@onready var game_progress = $MarginContainer/VBoxContainer/GlobalScorePanel/ScoreContainer/GameProgress
@onready var global_score_panel = $MarginContainer/VBoxContainer/GlobalScorePanel

var selected_minigame: String = ""

func _ready():
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)
	random_button.pressed.connect(_on_random_button_pressed)
	minigame_list.item_selected.connect(_on_minigame_selected)
	
	# Connect to global score manager
	GlobalScoreManager.game_completed_in_party.connect(_on_game_completed_in_party)
	GlobalScoreManager.party_completed.connect(_on_party_completed)
	
	# Update UI based on party mode
	update_ui_for_party_mode()
	
	# Populate minigame list
	populate_minigame_list()
	
	# Start background music
	$BackgroundMusic.play()

# Fill the list with available minigames
func populate_minigame_list():
	minigame_list.clear()
	
	# Get available games (only unplayed ones in party mode)
	var games_to_show = []
	if GlobalScoreManager.party_mode_active:
		games_to_show = GlobalScoreManager.get_available_games()
	else:
		games_to_show = MinigameManager.available_minigames.keys()
	
	for minigame_id in games_to_show:
		var minigame_data = MinigameManager.available_minigames[minigame_id]
		minigame_list.add_item(minigame_data.name)
		minigame_list.set_item_metadata(minigame_list.get_item_count() - 1, minigame_id)
	
	# Select first item by default if there are minigames
	if minigame_list.get_item_count() > 0:
		minigame_list.select(0)
		_on_minigame_selected(0)
	else:
		if GlobalScoreManager.party_mode_active:
			description_label.text = "All games completed! Check final results above."
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

# Return to main menu or reset party
func _on_back_button_pressed():
	# Check if party is completed (back button becomes "New Party")
	if GlobalScoreManager.party_mode_active:
		var status = GlobalScoreManager.get_party_status()
		if status.completed_games >= status.total_games:
			# Reset party mode and restart
			GlobalScoreManager.reset_party_mode()
			GlobalScoreManager.start_party_mode()
			update_ui_for_party_mode()
			populate_minigame_list()
			back_button.text = "Back to Menu"
			return
	
	# Normal behavior - go back to main menu
	GlobalScoreManager.reset_party_mode()  # Clean up if needed
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Play randomly selected minigame
func _on_random_button_pressed():
	setup_players()
	
	# Get available games for random selection
	var available_games = []
	if GlobalScoreManager.party_mode_active:
		available_games = GlobalScoreManager.get_available_games()
	else:
		available_games = MinigameManager.available_minigames.keys()
	
	if available_games.size() > 0:
		var random_minigame = available_games[randi() % available_games.size()]
		start_minigame(random_minigame)
	else:
		description_label.text = "No games available for random selection"

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
	
	# Add results to global score manager if in party mode
	if GlobalScoreManager.party_mode_active:
		GlobalScoreManager.add_game_result(_results)
	
	# Re-enable buttons
	play_button.disabled = false
	random_button.disabled = false
	
	# Start background music
	AudioServer.set_bus_volume_linear(2, 0)
	AudioServer.set_bus_volume_linear(1, 0.5)
	$BackgroundMusic.play()
	
	# Update UI
	update_ui_for_party_mode()
	populate_minigame_list()
	
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

# Update UI based on party mode status
func update_ui_for_party_mode():
	if GlobalScoreManager.party_mode_active:
		# Show global score panel
		global_score_panel.visible = true
		
		# Update scores
		var status = GlobalScoreManager.get_party_status()
		var scores = status.global_scores
		
		player1_score.text = "Player 1: " + str(scores.get(0, 0)) + " pts"
		player2_score.text = "Player 2: " + str(scores.get(1, 0)) + " pts"
		game_progress.text = "Games: " + str(status.completed_games) + "/" + str(status.total_games)
		
		# Change title
		$MarginContainer/VBoxContainer/TitleLabel.text = "Party Mode - Select Next Game"
	else:
		# Hide global score panel
		global_score_panel.visible = false
		
		# Reset title
		$MarginContainer/VBoxContainer/TitleLabel.text = "Minigame Selection"

# Handle game completion in party mode
func _on_game_completed_in_party(results: Dictionary):
	print("Game completed in party mode: ", results)
	update_ui_for_party_mode()
	populate_minigame_list()

# Handle party completion (results screen will be shown by GlobalScoreManager)
func _on_party_completed(final_results: Dictionary):
	print("Party completed! Results screen will be shown automatically") 
