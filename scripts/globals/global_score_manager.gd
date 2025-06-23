extends Node

# Global party mode state
var party_mode_active: bool = false
var played_games: Array = []  # List of game IDs that have been played
var global_scores: Dictionary = {}  # player_id: total_score
var game_results: Array = []  # Results from each completed game

# Party configuration
var player_count: int = 2

# Signals
signal party_completed(final_results)
signal game_completed_in_party(game_results)

func _ready():
	pass

# Start party mode
func start_party_mode():
	print("GlobalScoreManager: Starting party mode")
	party_mode_active = true
	played_games.clear()
	global_scores.clear()
	game_results.clear()
	
	# Initialize player scores
	for i in range(player_count):
		global_scores[i] = 0
	
	print("Party mode started with " + str(player_count) + " players")

# Check if a game has been played
func is_game_played(game_id: String) -> bool:
	return game_id in played_games

# Get available games (not yet played)
func get_available_games() -> Array:
	var all_games = MinigameManager.available_minigames.keys()
	var available = []
	
	for game_id in all_games:
		if not is_game_played(game_id):
			available.append(game_id)
	
	return available

# Add score from a completed game
func add_game_result(results: Dictionary):
	if not party_mode_active:
		return
	
	var game_id = results.get("minigame_id", "unknown")
	
	# Mark game as played
	if not is_game_played(game_id):
		played_games.append(game_id)
	
	# Store game results
	game_results.append(results)
	
	# Add scores to global totals
	if results.has("ranking"):
		for player_rank in results.ranking:
			var player_id = player_rank.player_id
			var score = player_rank.score
			global_scores[player_id] += score
			print("Player " + str(player_id + 1) + " earned " + str(score) + " points. Total: " + str(global_scores[player_id]))
	else:
		# Fallback for other score formats
		for player_id in results:
			if typeof(player_id) == TYPE_INT and results[player_id] is int:
				global_scores[player_id] += results[player_id]
	
	# Emit signal for UI updates
	emit_signal("game_completed_in_party", results)
	
	# Check if all games completed
	var total_games = MinigameManager.available_minigames.size()
	if played_games.size() >= total_games:
		complete_party()

# Complete party mode and show final results
func complete_party():
	print("GlobalScoreManager: Party completed!")
	party_mode_active = false
	
	# Create final ranking
	var final_ranking = []
	for player_id in global_scores:
		final_ranking.append({
			"player_id": player_id,
			"total_score": global_scores[player_id]
		})
	
	# Sort by total score (descending)
	final_ranking.sort_custom(func(a, b): return a.total_score > b.total_score)
	
	# Create final results
	var final_results = {
		"final_ranking": final_ranking,
		"game_results": game_results,
		"global_scores": global_scores
	}
	
	print("Final party ranking:")
	for i in range(final_ranking.size()):
		var player_data = final_ranking[i]
		print(str(i + 1) + ". Player " + str(player_data.player_id + 1) + ": " + str(player_data.total_score) + " points")
	
	# Emit completion signal
	emit_signal("party_completed", final_results)
	
	# Show party results screen
	show_party_results(final_results)

# Show party results screen
func show_party_results(results: Dictionary):
	print("Showing party results...")
	
	# Load and show party results scene
	var results_scene = load("res://scenes/party_results.tscn")
	if results_scene:
		var results_instance = results_scene.instantiate()
		get_tree().get_root().add_child(results_instance)
		
		# Display results
		results_instance.display_results(results)
	else:
		# Fallback: return to main menu
		push_error("Could not load party results scene")
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Reset party mode
func reset_party_mode():
	party_mode_active = false
	played_games.clear()
	global_scores.clear()
	game_results.clear()

# Get current party status
func get_party_status() -> Dictionary:
	var total_games = MinigameManager.available_minigames.size()
	var completed_games = played_games.size()
	
	return {
		"is_active": party_mode_active,
		"completed_games": completed_games,
		"total_games": total_games,
		"remaining_games": total_games - completed_games,
		"global_scores": global_scores.duplicate(),
		"played_games": played_games.duplicate()
	}