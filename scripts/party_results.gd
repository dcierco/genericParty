extends Control

@onready var winner_label = $VBoxContainer/ResultsContainer/ResultsContent/WinnerLabel
@onready var scores_list = $VBoxContainer/ResultsContainer/ResultsContent/ScoresList
@onready var game_results = $VBoxContainer/ResultsContainer/ResultsContent/GameResults
@onready var new_party_button = $VBoxContainer/ButtonContainer/NewPartyButton
@onready var main_menu_button = $VBoxContainer/ButtonContainer/MainMenuButton
@onready var exit_button = $VBoxContainer/ButtonContainer/ExitButton

var party_results: Dictionary

func _ready():
	# Connect button signals
	new_party_button.pressed.connect(_on_new_party_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

# Display the party results
func display_results(results: Dictionary):
	party_results = results
	
	var ranking = results.get("final_ranking", [])
	var game_results_data = results.get("game_results", [])
	
	if ranking.size() > 0:
		# Show winner
		var winner = ranking[0]
		winner_label.text = "🏆 WINNER: Player " + str(winner.player_id + 1) + " 🏆"
		winner_label.add_theme_color_override("font_color", Color.GOLD)
		
		# Show final scores
		for i in range(ranking.size()):
			var player_data = ranking[i]
			var player_id = player_data.player_id
			var total_score = player_data.total_score
			
			var score_label = Label.new()
			var score_text = ""
			
			# Add medal/position emoji
			match i:
				0:
					score_text = "🥇 Player " + str(player_id + 1) + ": " + str(total_score) + " points"
					score_label.add_theme_color_override("font_color", Color.GOLD)
				1:
					score_text = "🥈 Player " + str(player_id + 1) + ": " + str(total_score) + " points"
					score_label.add_theme_color_override("font_color", Color.SILVER)
				_:
					score_text = str(i + 1) + ". Player " + str(player_id + 1) + ": " + str(total_score) + " points"
					score_label.add_theme_color_override("font_color", Color.WHITE)
			
			score_label.text = score_text
			score_label.add_theme_font_size_override("font_size", 24)
			score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			scores_list.add_child(score_label)
		
		# Add game breakdown
		add_game_breakdown(game_results_data)
	else:
		winner_label.text = "No results available"

# Add detailed breakdown of each game
func add_game_breakdown(game_results_data: Array):
	if game_results_data.size() == 0:
		return
	
	# Show results for each game
	for i in range(game_results_data.size()):
		var game_result = game_results_data[i]
		var game_id = game_result.get("minigame_id", "Unknown")
		var game_name = MinigameManager.available_minigames.get(game_id, {}).get("name", game_id)
		
		# Game header
		var game_label = Label.new()
		game_label.text = "Game " + str(i + 1) + ": " + game_name
		game_label.add_theme_font_size_override("font_size", 18)
		game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_label.add_theme_color_override("font_color", Color.CYAN)
		game_results.add_child(game_label)
		
		# Game results container
		var game_scores_container = HBoxContainer.new()
		game_scores_container.alignment = BoxContainer.ALIGNMENT_CENTER
		game_scores_container.add_theme_constant_override("separation", 40)
		
		# Show ranking for this game
		if game_result.has("ranking"):
			for j in range(game_result.ranking.size()):
				var player_rank = game_result.ranking[j]
				var score_label = Label.new()
				
				var position_text = ""
				match j:
					0: position_text = "🥇 "
					1: position_text = "🥈 "
					_: position_text = str(j + 1) + ". "
				
				score_label.text = position_text + "P" + str(player_rank.player_id + 1) + ": " + str(player_rank.score)
				score_label.add_theme_font_size_override("font_size", 16)
				score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				# Color based on player team
				if player_rank.player_id == 0:
					score_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))  # Light red
				else:
					score_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1))  # Light blue
				
				game_scores_container.add_child(score_label)
		
		game_results.add_child(game_scores_container)
		
		# Add small spacer between games
		if i < game_results_data.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 10)
			game_results.add_child(spacer)

# Start a new party
func _on_new_party_pressed():
	# Reset and start new party
	GlobalScoreManager.reset_party_mode()
	GlobalScoreManager.start_party_mode()
	
	# Go to minigame select
	get_tree().change_scene_to_file("res://scenes/minigame_select.tscn")

# Return to main menu
func _on_main_menu_pressed():
	# Clean up party mode
	GlobalScoreManager.reset_party_mode()
	
	# Go to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Exit the game
func _on_exit_pressed():
	# Clean up party mode
	GlobalScoreManager.reset_party_mode()
	
	# Quit the game
	get_tree().quit()