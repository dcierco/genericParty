extends Node2D
class_name MinigameBase

signal minigame_completed(results)
signal results_displayed  # Emitted when results have been shown for the set duration

# Minigame properties
var minigame_id: String = "base_minigame"
var minigame_name: String = "Base Minigame"
var minigame_description: String = "Base class for all minigames"

# Minigame state
enum MinigameState {INIT, INTRO, PLAYING, FINISHED, RESULTS}
var current_state: MinigameState = MinigameState.INIT
var time_remaining: float = 30.0
var has_time_limit: bool = true
var countdown_time: int = 3  # Initial countdown seconds (integer)
var countdown_timer_float: float = 0.0 # Active countdown timer (float)
var finish_positions: Array = []
var results_display_duration: float = 4.0  # How long to show results before transitioning

# Player tracking
var player_scores: Dictionary = {}  # player_id: score
var player_finished: Dictionary = {}  # player_id: has_finished

# Team tracking
var team_colors = {
	"red": Color(1, 0.2, 0.2),   # Red team color
	"blue": Color(0.2, 0.4, 1)    # Blue team color
}
var player_teams = {
	0: "red",   # Player 0 is on red team
	1: "blue"   # Player 1 is on blue team
}
var team_scores = {
	"red": 0,
	"blue": 0
}

# Configuration
var intro_duration: float = 3.0  # Time for "Ready, Set, Go!"
var minigame_duration: float = 60.0  # Default time limit

# UI references
@onready var countdown_label = $UI/IntroContainer/VBoxContainer/CountdownLabel
@onready var description_label = $UI/IntroContainer/VBoxContainer/DescriptionLabel
@onready var intro_container = $UI/IntroContainer
@onready var results_container = $UI/ResultsContainer
@onready var time_label = $UI/TimerContainer/TimeLabel

func _ready():
	print("MinigameBase: _ready called")
	
	# Make sure UI elements start in the correct state
	if intro_container:
		intro_container.visible = true
	if results_container:
		results_container.visible = false
		
	initialize_minigame()
	
func _process(delta):
	# --- REMOVED DEBUG PRINT ---
	# print("MinigameBase _process called. State: " + str(current_state) + ", Delta: " + str(delta))
	# --- END DEBUG PRINT ---
	match current_state:
		MinigameState.INTRO:
			process_intro(delta)
		MinigameState.PLAYING:
			process_playing(delta)
		MinigameState.FINISHED:
			process_finished(delta)
		_: # Handle INIT or other states if needed
			pass # Or print a warning

# Called when minigame is first loaded
func initialize_minigame():
	print("MinigameBase: initialize_minigame called")
	# Reset state
	time_remaining = minigame_duration
	player_scores.clear()
	player_finished.clear()
	finish_positions.clear()
	
	# Reset team scores
	team_scores["red"] = 0
	team_scores["blue"] = 0

	# Set initial state
	current_state = MinigameState.INTRO
	countdown_timer_float = float(countdown_time) # Initialize float timer
	print("Set current_state to INTRO, countdown_timer_float initialized to: " + str(countdown_timer_float)) # Debug confirmation

	# Get UI elements (done via @onready)

	# Start countdown appearance
	start_countdown()

# Process intro/countdown phase
func process_intro(delta):
	# --- REMOVED PREVIOUS DEBUG PRINTS ---
	# Decrement the float timer
	countdown_timer_float -= delta

	# Update the visual label
	if countdown_label:
		# Display the ceiling of the float timer to show 3, 2, 1...
		var display_time = ceil(countdown_timer_float)
		# Prevent showing 0 during countdown, it should jump straight to GO/start
		if display_time > 0:
			countdown_label.text = str(int(display_time))
		else:
			# Optional: Change text briefly to "GO!" before starting
			countdown_label.text = "GO!"
	else:
		print("MinigameBase Error: countdown_label is null in process_intro")


	# When timer reaches zero or below
	if countdown_timer_float <= 0:
		print("Countdown finished! Starting gameplay.")
		start_gameplay() # Transition to the actual game

# Process main gameplay
func process_playing(delta):
	if has_time_limit:
		time_remaining -= delta
		update_time_display()
		
		if time_remaining <= 0:
			end_minigame()
	
	# Check if all players are finished
	var all_finished = true
	for player_id in player_finished:
		if not player_finished[player_id]:
			all_finished = false
			break
	
	if all_finished:
		end_minigame()
	
	# Override in child classes to add gameplay logic

# Process finished state
func process_finished(_delta):
	# Usually just waiting for animation or results display
	# Override in child classes if needed
	pass

# Start the gameplay after intro
func start_gameplay():
	print("MinigameBase: start_gameplay called")
	current_state = MinigameState.PLAYING
	
	# Hide intro UI, show game UI if needed
	if intro_container:
		intro_container.visible = false
	
	# Potentially make game elements visible here or in derived class override
	# Example: if game_area_node: game_area_node.visible = true

# Update the time display
func update_time_display():
	if time_label:
		time_label.text = str(int(time_remaining))

# Mark a player as finished
func set_player_finished(player_id: int, score: int = 0):
	player_scores[player_id] = score
	player_finished[player_id] = true
	
	# Update team score
	var team = player_teams.get(player_id, "red") # Default to red if not specified
	team_scores[team] += score
	
	print("Player " + str(player_id) + " (Team " + team + ") finished with score: " + str(score))

# End the minigame and calculate results
func end_minigame():
	print("MinigameBase: end_minigame called")
	
	# Prevent multiple calls
	if current_state == MinigameState.FINISHED or current_state == MinigameState.RESULTS:
		print("MinigameBase: Already in finished state, ignoring duplicate end_minigame call")
		return
		
	current_state = MinigameState.FINISHED
	
	# Show results screen
	if results_container:
		results_container.visible = true
		display_results() # Call function to populate results
		
		# Move to RESULTS state and start timer
		current_state = MinigameState.RESULTS
		show_results_and_transition()
	else:
		print("MinigameBase Error: results_container is null in end_minigame")
		# Emit signal immediately if we can't show results
		create_and_emit_results()

# Get ranked list of players by score
func get_player_ranking() -> Array:
	var players_by_score = []
	
	for player_id in player_scores:
		players_by_score.append({
			"player_id": player_id,
			"score": player_scores[player_id]
		})
	
	# Sort by score (descending)
	players_by_score.sort_custom(Callable(self, "_sort_by_score"))
	
	return players_by_score

# Custom sort function for scores
func _sort_by_score(a, b):
	return a.score > b.score 

# Start the countdown animation
func start_countdown():
	print("MinigameBase: start_countdown called")
	# Enable the countdown UI
	if intro_container:
		intro_container.visible = true
	else:
		print("MinigameBase Error: intro_container is null in start_countdown")


	# Initial countdown value
	if countdown_label:
		countdown_label.text = str(countdown_time) # Show initial integer value (e.g., "3")
		print("Set initial countdown label to: " + countdown_label.text)
	else:
		print("MinigameBase Error: countdown_label is null in start_countdown")

# Calculate team scores based on player scores
func calculate_team_results():
	team_scores["red"] = 0
	team_scores["blue"] = 0
	
	for player_id in player_scores:
		var team = player_teams.get(player_id, "red") # Default to red if no team assigned
		team_scores[team] += player_scores[player_id]
	
	# Determine winning team
	var winning_team = "red"
	if team_scores["blue"] > team_scores["red"]:
		winning_team = "blue"
	
	return winning_team

# Called when the minigame ends (time runs out or all players finish)
func display_results():
	# Calculate team results
	var winning_team = calculate_team_results()
	
	# Get references to team panels and labels
	var red_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/RedTeamPanel/RedTeamLabel
	var blue_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/BlueTeamPanel/BlueTeamLabel
	
	# Update team result text
	if red_team_label:
		if winning_team == "red":
			red_team_label.text = "RED TEAM WINS"
		else:
			red_team_label.text = "RED TEAM LOSES"
	
	if blue_team_label:
		if winning_team == "blue":
			blue_team_label.text = "BLUE TEAM WINS"
		else:
			blue_team_label.text = "BLUE TEAM LOSES"
	
	# Display individual player scores in the results list
	var results_list = $UI/ResultsContainer/VBoxContainer/ResultsList
	if results_list:
		# Clear existing results
		for child in results_list.get_children():
			child.queue_free()
			
		# Get sorted player ranking
		var ranking = get_player_ranking()
		
		# Add player results
		for player_data in ranking:
			var player_id = player_data.player_id
			var score = player_data.score
			var team = player_teams.get(player_id, "red")
			
			var result_label = Label.new()
			result_label.text = "Player " + str(player_id + 1) + ": " + str(score) + " points"
			result_label.add_theme_color_override("font_color", team_colors[team])
			results_list.add_child(result_label)

# Shows results for the set duration, then transitions
func show_results_and_transition():
	print("MinigameBase: Showing results for " + str(results_display_duration) + " seconds")
	
	# Wait for the specified duration
	await get_tree().create_timer(results_display_duration).timeout
	
	# Create and emit results
	create_and_emit_results()
	
	# Emit signal that results have been displayed
	emit_signal("results_displayed")

# Creates and emits the results
func create_and_emit_results():
	# Create results dictionary with minigame_id included
	var final_results = player_scores.duplicate()
	final_results["minigame_id"] = minigame_id
	final_results["ranking"] = get_player_ranking()
	
	# Emit signal with complete results
	print("MinigameBase: Emitting minigame_completed signal with results")
	emit_signal("minigame_completed", final_results)

# Called when the minigame ends (time runs out or all players finish)
func go_back_to_menu():
	# Implementation of go_back_to_menu function
	pass 
