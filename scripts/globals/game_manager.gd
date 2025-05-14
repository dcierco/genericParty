extends Node

# Game state enums
enum GameState {MAIN_MENU, BOARD, MINIGAME, RESULTS}

# Player stats
class PlayerData:
	var player_id: int
	var name: String
	var coins: int = 0
	var stars: int = 0
	var position: Vector2 = Vector2.ZERO
	var current_space: int = 0
	
	func _init(id: int, player_name: String):
		player_id = id
		name = player_name

# Game configuration
var current_state: GameState = GameState.MAIN_MENU
var players: Array[PlayerData] = []
var current_player_index: int = 0
var total_turns: int = 10
var current_turn: int = 1

# Minigame configuration
var last_minigame_results: Dictionary = {}
var minigame_frequency: int = 4  # Trigger minigame every X turns

# Signals
signal minigame_triggered
signal game_state_changed(new_state)

func _ready():
	pass

# Game flow control
func start_new_game(player_count: int, turns: int = 10):
	players.clear()
	for i in range(player_count):
		players.append(PlayerData.new(i, "Player " + str(i+1)))
	
	current_player_index = 0
	total_turns = turns
	current_turn = 1
	set_game_state(GameState.BOARD)
	
	# Additional initialization

func next_player_turn():
	current_player_index = (current_player_index + 1) % players.size()
	if current_player_index == 0:
		current_turn += 1
	
	# Check if we should trigger a minigame
	if current_player_index == players.size() - 1 and current_turn % minigame_frequency == 0:
		trigger_minigame()
	
	# Check if game is over
	if current_turn > total_turns and current_player_index == 0:
		end_game()

func get_current_player() -> PlayerData:
	return players[current_player_index]

func trigger_minigame():
	set_game_state(GameState.MINIGAME)
	emit_signal("minigame_triggered")
	# MinigameManager will handle the actual minigame launch

func apply_minigame_results(results: Dictionary):
	last_minigame_results = results
	
	# Apply results to player data (coins, etc.)
	var ranking = results.get("ranking", [])
	
	# Award coins based on ranking
	if ranking.size() > 0:
		# First place gets most coins
		var coin_rewards = [10, 5, 3, 1]  # Rewards by place
		
		for i in range(min(ranking.size(), coin_rewards.size())):
			var player_id = ranking[i].player_id
			var coins_to_add = coin_rewards[i]
			
			# Find player and add coins
			for player in players:
				if player.player_id == player_id:
					player.coins += coins_to_add
					break
	
	# Return to board after results
	set_game_state(GameState.BOARD)

func end_game():
	set_game_state(GameState.RESULTS)
	
	# Calculate final results, determine winner
	var winner = determine_winner()
	
	# Display results (this would connect to a UI)
	print("Game Over! Winner: " + winner.name)
	
	# Return to main menu after delay
	await get_tree().create_timer(5.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func determine_winner() -> PlayerData:
	var highest_stars = -1
	var highest_coins = -1
	var winner = null
	
	# First priority: most stars
	for player in players:
		if player.stars > highest_stars:
			highest_stars = player.stars
			highest_coins = player.coins
			winner = player
		elif player.stars == highest_stars:
			# Tie breaker: coins
			if player.coins > highest_coins:
				highest_coins = player.coins
				winner = player
	
	return winner

# Set game state and emit signal
func set_game_state(new_state: GameState):
	current_state = new_state
	emit_signal("game_state_changed", new_state) 