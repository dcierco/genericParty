extends Node

# Dictionary of available minigames
var available_minigames: Dictionary = {
	# Format: "minigame_id": {"scene": "path_to_scene", "name": "Display Name", "description": "Short description"}
}

var current_minigame: String = ""
var minigame_instance = null

# Settings for minigame selection
var use_weighted_selection: bool = true
var minigame_weights: Dictionary = {}

func _ready():
	register_all_minigames()
	
	# Connect to GameManager signals
	GameManager.minigame_triggered.connect(_on_minigame_triggered)

# Register all available minigames
func register_all_minigames():
	# Register race game
	register_minigame(
		"race_game", 
		"res://scenes/minigames/race_game.tscn", 
		"Race Game", 
		"Press the correct button shown on screen to advance!\nPlayer 1: A/D/W/Space\nPlayer 2: Arrow Keys/Enter"
	)
	
	# Register shrinking platform game
	register_minigame(
		"shrinking_platform",
		"res://scenes/minigames/shrinking_platform.tscn",
		"Shrinking Platform",
		"Stay on the platform as it shrinks! Push opponents into the lava!\nControls:\nPlayer 1: WASD (move) + Space (push)\nPlayer 2: Arrow Keys (move) + Enter (push)"
	)

	# Register Avoid the Obstacles game
	register_minigame(
		"avoid_the_obstacles",
		"res://scenes/minigames/avoid_the_obstacles.tscn",
		"Avoid the Obstacles!",
		"Dodge the falling objects! Last player standing wins, or survive together!\nControls:\nPlayer 1: A/D (move) + W (jump) + Space (push)\nPlayer 2: Left/Right Arrows (move) + Up (jump) + Enter (push)"
	)

	# Register Jumping Platforms game
	register_minigame(
		"jumping_platforms",
		"res://scenes/minigames/jumping_platforms.tscn",
		"Jumping Platforms!",
		"Jump on platforms and reach the highest point! Push enemies to make them fall!\nControls:\nPlayer 1: A/D (move) + W (jump) + Space (push)\nPlayer 2: Left/Right Arrows (move) + Up (jump) + Enter (push)"
	)

func register_minigame(id: String, scene_path: String, display_name: String, description: String):
	available_minigames[id] = {
		"scene": scene_path,
		"name": display_name,
		"description": description
	}
	minigame_weights[id] = 1.0  # Default equal weight

# Called when GameManager triggers a minigame
func _on_minigame_triggered():
	# Small delay before starting the minigame
	await get_tree().create_timer(0.5).timeout
	
	# Start a random minigame
	start_minigame()

# Get a random minigame based on weights
func select_random_minigame() -> String:
	if available_minigames.is_empty():
		push_error("No minigames registered!")
		return ""
	
	if use_weighted_selection:
		var total_weight: float = 0.0
		for game_id in minigame_weights:
			total_weight += minigame_weights[game_id]
		
		var random_value = randf() * total_weight
		var current_sum = 0.0
		
		for game_id in minigame_weights:
			current_sum += minigame_weights[game_id]
			if random_value <= current_sum:
				return game_id
	
	# Fallback to uniform selection
	var keys = available_minigames.keys()
	return keys[randi() % keys.size()]

# Start a specific minigame
func start_minigame(minigame_id: String = ""):
	if minigame_id.is_empty():
		minigame_id = select_random_minigame()
	
	if minigame_id.is_empty() or not available_minigames.has(minigame_id):
		push_error("Invalid minigame ID: " + minigame_id)
		return
	
	# Clean up any existing minigame instance
	if minigame_instance:
		if minigame_instance.has_signal("minigame_completed"):
			minigame_instance.disconnect("minigame_completed", Callable(self, "_on_minigame_completed"))
		minigame_instance.queue_free()
		minigame_instance = null
	
	current_minigame = minigame_id
	
	# Load the minigame scene
	var minigame_scene = load(available_minigames[minigame_id].scene)
	if minigame_scene:
		minigame_instance = minigame_scene.instantiate()
		get_tree().get_root().add_child(minigame_instance)
		
		# Connect signals from the minigame
		if minigame_instance.has_signal("minigame_completed"):
			minigame_instance.connect("minigame_completed", Callable(self, "_on_minigame_completed"))
	else:
		push_error("Failed to load minigame scene: " + available_minigames[minigame_id].scene)

# Handle minigame completion
func _on_minigame_completed(results: Dictionary):
	if minigame_instance:
		minigame_instance.queue_free()
		minigame_instance = null
	
	# Update minigame weights to reduce chance of repeating the same minigame
	adjust_minigame_weight(current_minigame, 0.5)  # Reduce weight by half
	
	# Pass results to GameManager
	GameManager.apply_minigame_results(results)

# Adjust the weight of a minigame for selection
func adjust_minigame_weight(minigame_id: String, factor: float):
	if minigame_weights.has(minigame_id):
		minigame_weights[minigame_id] *= factor
		# Normalize weights periodically
		if minigame_weights[minigame_id] < 0.1:
			normalize_weights()

# Reset all weights to equal
func normalize_weights():
	for game_id in minigame_weights:
		minigame_weights[game_id] = 1.0

# Get the current number of players from GameManager
func get_player_count() -> int:
	if GameManager.players.size() > 0:
		return GameManager.players.size()
	else:
		return 2  # Default to 2 players if not set 
