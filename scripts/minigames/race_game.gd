extends "res://scripts/minigames/minigame_base.gd"

# Race settings
var track_length: float = 1000.0 # Length for the track 
var progress_per_press: float = 20.0 # Progress per correct button press
var penalty_per_wrong: float = 5.0 # Penalty for wrong button press

# Player state
var player_progress: Dictionary = {} # player_id: current progress
var player_sprites: Dictionary = {}  # player_id: sprite node
var player_detailed_scores: Dictionary = {} # Detailed score breakdown for each player
var player_current_buttons: Dictionary = {} # player_id: current required button
var player_button_timers: Dictionary = {} # player_id: time left to press button
var button_display_time: float = 2.0 # Time to press the correct button

# Available buttons for each player
var available_buttons: Dictionary = {
	0: ["p1_left", "p1_right", "p1_up", "p1_down", "p1_action"],  # A, D, W, S, Space
	1: ["p2_left", "p2_right", "p2_up", "p2_down", "p2_action"]   # Left, Right, Up, Down, Enter
}

# Button display names
var button_names: Dictionary = {
	"p1_left": "A",
	"p1_right": "D", 
	"p1_up": "W",
	"p1_down": "S",
	"p1_action": "SPACE",
	"p2_left": "←",
	"p2_right": "→",
	"p2_up": "↑",
	"p2_down": "↓",
	"p2_action": "ENTER"
}

# Input mapping (keeping for compatibility)
var player_inputs: Dictionary = {
	0: {"team": "red"},
	1: {"team": "blue"},
}

# UI node references - using @onready to get them when scene is ready
@onready var progress_container = $UI/ProgressContainer
@onready var player_lanes_container = $GameContainer/PlayerLanes
@onready var player_lane1 = $GameContainer/PlayerLanes/PlayerLane1
@onready var player_lane2 = $GameContainer/PlayerLanes/PlayerLane2
@onready var progress_bar_p1 = $UI/ProgressContainer/Player1ProgressVBox/ProgressBarP1
@onready var progress_bar_p2 = $UI/ProgressContainer/Player2ProgressVBox/ProgressBarP2
# Button prompt labels will be created dynamically
var button_prompt_labels: Dictionary = {}

func _ready():
	print("Race Game: Ready")
	# Set minigame properties
	minigame_id = "race_game"
	minigame_name = "Race Game"
	minigame_description = "Press the correct button shown on screen to advance!\nPlayer 1: A/D/W/S/Space\nPlayer 2: Arrow Keys/Enter"
	
	# Set time limit to 25 seconds
	minigame_duration = 25.0
	time_remaining = 25.0
	
	super._ready()
	
	$BackgroundMusic.play()
	
	# Update description label if needed
	if description_label:
		description_label.text = minigame_description

func initialize_minigame():
	print("Race Game: Initializing")
	super.initialize_minigame()
	
	# Initialize player references and state
	player_detailed_scores.clear()
	setup_players()
	reset_progress_bars()

func setup_players():
	print("Race Game: Setup players")
	player_progress.clear()
	player_sprites.clear()
	
	# Get player count from MinigameManager
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2) # Limit to 2 players for this minigame
	
	# Store references to player sprites
	player_sprites[0] = player_lane1.get_node("PlayerSprite")
	player_sprites[1] = player_lane2.get_node("PlayerSprite")
	
	# Initialize progress for each player
	for i in range(player_count):
		player_progress[i] = 0.0
		player_scores[i] = 0
		player_finished[i] = false
		player_current_buttons[i] = ""
		player_button_timers[i] = 0.0
		
		# Reset player sprite positions
		if player_sprites.has(i) and is_instance_valid(player_sprites[i]):
			player_sprites[i].position.x = 50
			player_sprites[i].position.y = player_sprites[i].get_meta("initial_y")
		
		# Update player_teams in the base class for consistency
		# Update player_teams in the base class to match player inputs
		var team = player_inputs[i].get("team", "red")
		player_teams[i] = team
	
	# Set second player lane visibility based on player count
	if player_lane2:
		player_lane2.visible = player_count > 1

func reset_progress_bars():
	# Reset progress bars to 0
	if progress_bar_p1:
		progress_bar_p1.value = 0
	if progress_bar_p2:
		progress_bar_p2.value = 0

func start_gameplay():
	print("Race Game: Starting")
	super.start_gameplay()
	
	# Reset sprite positions at game start
	for i in player_sprites:
		if is_instance_valid(player_sprites[i]):
			player_sprites[i].position.x = 50
			player_sprites[i].visible = true
	
	# Create button prompt labels
	create_button_prompt_labels()
	
	# Generate first button prompts for all players
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)
	for i in range(player_count):
		generate_new_button_prompt(i)

func _process(delta):
	match current_state:
		MinigameState.INTRO:
			super.process_intro(delta) # Use base class intro logic
		MinigameState.PLAYING:
			process_playing(delta)
		MinigameState.FINISHED:
			process_finished(delta)

func process_playing(delta):
	if has_time_limit:
		time_remaining -= delta
		update_time_display()
		
		if time_remaining <= 0 and current_state == MinigameState.PLAYING:
			print("RaceGame: Time limit reached!")
			end_minigame()
			return # Important to stop processing after ending
	
	var all_finished = true # Check if game should end now
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2) # Limit to 2 players for this minigame
	
	for player_id in range(player_count):
		# Skip players who already finished
		if player_finished.get(player_id, false):
			continue
		
		all_finished = false # At least one player is still playing
		
		# Update button timer
		player_button_timers[player_id] -= delta
		
		# Check if button timer expired
		if player_button_timers[player_id] <= 0:
			# Time's up! Generate new button prompt
			generate_new_button_prompt(player_id)
		
		# Handle input for all available buttons
		var pressed_button = get_pressed_button(player_id)
		if pressed_button != "":
			if pressed_button == player_current_buttons[player_id]:
				# Correct button pressed!
				player_progress[player_id] = min(player_progress[player_id] + progress_per_press, track_length)
				print("Player " + str(player_id) + " pressed correct button. Progress: " + str(player_progress[player_id]))
				
				# Update progress bar
				update_player_progress(player_id)
				
				# Visual feedback for correct press
				show_feedback(player_id, true)
				
				# Generate new button prompt
				generate_new_button_prompt(player_id)
			else:
				# Wrong button pressed!
				player_progress[player_id] = max(player_progress[player_id] - penalty_per_wrong, 0)
				print("Player " + str(player_id) + " pressed wrong button. Progress: " + str(player_progress[player_id]))
				
				# Update progress bar
				update_player_progress(player_id)
				
				# Visual feedback for wrong press
				show_feedback(player_id, false)
			
			# Update button prompt display
			update_button_prompt_display(player_id)
		
		# Check if player reached finish line
		if player_progress[player_id] >= track_length and not player_finished.get(player_id, false):
			print("Player " + str(player_id) + " reached finish line!")
			finish_player(player_id)
	
	# Check how many players have finished
	var finished_count = 0
	for player_id in player_finished:
		if player_finished[player_id]:
			finished_count += 1
	
	# End game immediately when at least one player finishes
	if finished_count > 0 and current_state == MinigameState.PLAYING:
		print("RaceGame: At least one player finished! Ending minigame.")
		end_minigame()

func update_player_progress(player_id: int):
	# Update progress bar
	match player_id:
		0:
			if progress_bar_p1:
				progress_bar_p1.value = player_progress[player_id]
		1:
			if progress_bar_p2:
				progress_bar_p2.value = player_progress[player_id]
	
	# Update player sprite position
	if player_sprites.has(player_id) and is_instance_valid(player_sprites[player_id]):
		var start_pos_x = 50.0
		var end_pos_x = 850.0
		var normalized_progress = player_progress[player_id] / track_length
		
		# Update x position based on progress, keep y position unchanged
		player_sprites[player_id].position.x = lerp(start_pos_x, end_pos_x, normalized_progress)

func finish_player(player_id: int):
	var rank = get_finish_rank(player_id)
	
	# Calculate score based on rank and distance
	var total_players = MinigameManager.get_player_count()
	total_players = min(total_players, 2) # Limit to 2 players for this minigame
	
	# Base score is percentage of distance traveled (max 100 points)
	var distance_score = int((player_progress[player_id] / track_length) * 100)
	
	# First place bonus (50 points)
	var first_place_bonus = 50 if rank == 1 else 0
	
	# Completion bonus for finishing the race (200 points - very hard to achieve)
	var completion_bonus = 200 if player_progress[player_id] >= track_length else 0
	
	# Total score
	var score = distance_score + first_place_bonus + completion_bonus
	
	# Store detailed score breakdown for results display
	player_detailed_scores[player_id] = {
		"distance": distance_score,
		"first_place_bonus": first_place_bonus,
		"completion_bonus": completion_bonus,
		"total": score
	}
	
	# Mark player as finished and set score
	set_player_finished(player_id, score)
	
	# Get player's team from base class
	var team = player_teams.get(player_id, "red")
	print("Player " + str(player_id) + " (Team " + team + ") finished in rank " + str(rank))
	print("Score breakdown: Distance " + str(distance_score) + ", First place: " + str(first_place_bonus) + ", Completion: " + str(completion_bonus) + ", Total: " + str(score))
	
	# Add visual indicator for finish rank
	if player_sprites.has(player_id) and is_instance_valid(player_sprites[player_id]):
		var finish_label = Label.new()
		finish_label.text = str(rank) + "!"
		finish_label.add_theme_font_size_override("font_size", 20)
		finish_label.add_theme_color_override("font_color", Color(1, 1, 0))
		finish_label.position = Vector2(0, -30)
		player_sprites[player_id].add_child(finish_label)

func get_finish_rank(finished_player_id: int) -> int:
	# Count how many players have finished before this one
	var rank = 0
	for player_id in player_finished:
		if player_finished[player_id] and player_id != finished_player_id:
			rank += 1
	return rank + 1 # Rank starts at 1

func process_finished(delta):
	# Call superclass logic
	super.process_finished(delta)

func cleanup_button_prompt_labels():
	# Remove button prompt labels from the scene
	for player_id in button_prompt_labels:
		var label = button_prompt_labels[player_id]
		if is_instance_valid(label):
			label.queue_free()
	button_prompt_labels.clear()

func _exit_tree():
	print("Race Game: Cleaning up")
	# Clean up button prompts
	cleanup_button_prompt_labels()
	
	# Clear dictionaries
	player_progress.clear()
	player_sprites.clear()
	player_inputs.clear()
	player_current_buttons.clear()
	player_button_timers.clear()

func end_minigame():
	print("Race Game: Game over")
	
	# Make sure we only end the game once
	if current_state == MinigameState.FINISHED or current_state == MinigameState.RESULTS:
		print("Race Game: Already finished, ignoring duplicate end_minigame call")
		return
	
	# Clean up button prompt labels
	cleanup_button_prompt_labels()
	
	# Complete any unfinished players with their current progress
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)
	
	for player_id in range(player_count):
		if not player_finished.get(player_id, false):
			# Calculate score based on distance
			var distance_score = int((player_progress[player_id] / track_length) * 100)
			
			# Store detailed score breakdown
			player_detailed_scores[player_id] = {
				"distance": distance_score,
				"first_place_bonus": 0, # No first place bonus for not finishing
				"completion_bonus": 0, # No completion bonus for not finishing
				"total": distance_score
			}
			
			# Mark as finished with current score
			set_player_finished(player_id, distance_score)
	
	# Let the base class handle results display and transitioning
	super.end_minigame()

# Override the display_results function to show team-based results
func display_results():
	# Base class will handle making the container visible
		
	# Get the results list before calling super (which will clear it)
	var results_list = $UI/ResultsContainer/VBoxContainer/ResultsList
	if results_list:
		# Clear existing results
		for child in results_list.get_children():
			child.queue_free()
	
	# Calculate team results first using base class implementation
	super.display_results()
	
	# Get team panels and labels
	var red_team_panel = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/RedTeamPanel
	var blue_team_panel = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/BlueTeamPanel
	var red_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/RedTeamPanel/RedTeamLabel
	var blue_team_label = $UI/ResultsContainer/VBoxContainer/TeamResultsContainer/BlueTeamPanel/BlueTeamLabel
	
	# Add race-specific info to team labels
	if red_team_label and blue_team_label:
		# Check who reached the finish line
		var red_finished = false
		var blue_finished = false
		var red_progress = 0
		var blue_progress = 0
		
		for player_id in player_progress:
			var team = player_teams.get(player_id, "red")
			if team == "red":
				red_progress = player_progress[player_id]
				red_finished = player_progress[player_id] >= track_length
			elif team == "blue":
				blue_progress = player_progress[player_id]
				blue_finished = player_progress[player_id] >= track_length
		
		# Enhance the win/lose message with race details
		if red_finished and not blue_finished:
			red_team_label.text = "RED TEAM WINS\nFirst to finish!"
			blue_team_label.text = "BLUE TEAM LOSES\nToo slow!"
		elif blue_finished and not red_finished:
			blue_team_label.text = "BLUE TEAM WINS\nFirst to finish!"
			red_team_label.text = "RED TEAM LOSES\nToo slow!"
		elif red_finished and blue_finished:
			# Both finished, check who was first
			if team_scores["red"] > team_scores["blue"]:
				red_team_label.text = "RED TEAM WINS\nFinished first!"
				blue_team_label.text = "BLUE TEAM LOSES\nFinished second!"
			else:
				blue_team_label.text = "BLUE TEAM WINS\nFinished first!"
				red_team_label.text = "RED TEAM LOSES\nFinished second!"
		else:
			# No one finished (time ran out)
			if red_progress > blue_progress:
				red_team_label.text = "RED TEAM WINS\nMade more progress!"
				blue_team_label.text = "BLUE TEAM LOSES\nMade less progress!"
			else:
				blue_team_label.text = "BLUE TEAM WINS\nMade more progress!"
				red_team_label.text = "RED TEAM LOSES\nMade less progress!"
	
	# Add detailed player score breakdowns to results list
	if results_list:
		# Get sorted player ranking
		var ranking = get_player_ranking()
		
		# Add player results with detailed breakdown
		for player_data in ranking:
			var player_id = player_data.player_id
			var team = player_teams.get(player_id, "red")
			
			# Create VBox for this player's results
			var player_results = VBoxContainer.new()
			player_results.add_theme_constant_override("separation", 5)
			
			# Player header
			var player_header = Label.new()
			player_header.text = "Player " + str(player_id + 1) + " (" + team.capitalize() + " Team)"
			player_header.add_theme_font_size_override("font_size", 18)
			player_header.add_theme_color_override("font_color", team_colors[team])
			player_results.add_child(player_header)
			
			# Score breakdown
			if player_detailed_scores.has(player_id):
				var score_data = player_detailed_scores[player_id]
				
				# Distance points
				var distance_label = Label.new()
				var distance_percent = int((player_progress[player_id] / track_length) * 100)
				distance_label.text = "+ " + str(score_data.distance) + " points (distance traveled: " + str(distance_percent) + "%)"
				player_results.add_child(distance_label)
				
				# First place bonus if applicable
				if score_data.get("first_place_bonus", 0) > 0:
					var first_place_label = Label.new()
					first_place_label.text = "+ " + str(score_data.first_place_bonus) + " points (first place bonus)"
					first_place_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
					player_results.add_child(first_place_label)
				
				# Completion bonus if applicable
				if score_data.get("completion_bonus", 0) > 0:
					var completion_label = Label.new()
					completion_label.text = "+ " + str(score_data.completion_bonus) + " points (completion bonus)"
					completion_label.add_theme_color_override("font_color", Color(0, 1, 0))
					player_results.add_child(completion_label)
				
				# Total
				var total_label = Label.new()
				total_label.text = "Total: " + str(score_data.total) + " points"
				total_label.add_theme_font_size_override("font_size", 16)
				total_label.add_theme_color_override("font_color", Color(1, 1, 1))
				player_results.add_child(total_label)
			
			# Add to results list
			results_list.add_child(player_results)
			
			# Add spacer
			var spacer = HSeparator.new()
			results_list.add_child(spacer)
	
	# Animate the results panels
	if red_team_panel and blue_team_panel:
		# Create a single tween for both panels to ensure proper sequencing
		var tween = create_tween()
		
		# First, make panels pulse by scaling
		tween.tween_property(red_team_panel, "modulate", Color(1.2, 1.2, 1.2, 1), 0.5)
		tween.parallel().tween_property(blue_team_panel, "modulate", Color(1.2, 1.2, 1.2, 1), 0.5)
		
		# Then back to normal
		tween.tween_property(red_team_panel, "modulate", Color(1, 1, 1, 1), 0.5)
		tween.parallel().tween_property(blue_team_panel, "modulate", Color(1, 1, 1, 1), 0.5)

# New functions for reflex mechanics
func create_button_prompt_labels():
	# Create button prompt labels for each player
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)
	
	for i in range(player_count):
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 72)
		label.add_theme_color_override("font_color", team_colors[player_teams[i]])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Position labels horizontally: Player 1 on left, Player 2 on right
		if i == 0:
			# Player 1 (red team) on left side
			label.position = Vector2(50, 50)
		else:
			# Player 2 (blue team) on right side  
			label.position = Vector2(1000, 50)
		
		label.size = Vector2(200, 100)
		get_parent().add_child(label)  # Add to main scene instead of player lanes
		button_prompt_labels[i] = label

func generate_new_button_prompt(player_id: int):
	# Generate a random button for the player to press
	var buttons = available_buttons[player_id]
	var random_button = buttons[randi() % buttons.size()]
	player_current_buttons[player_id] = random_button
	player_button_timers[player_id] = button_display_time
	
	update_button_prompt_display(player_id)
	
	print("Player " + str(player_id) + " must press: " + button_names[random_button])

func update_button_prompt_display(player_id: int):
	if button_prompt_labels.has(player_id):
		var label = button_prompt_labels[player_id]
		var button_name = button_names[player_current_buttons[player_id]]
		
		label.text = button_name
		
		# Keep consistent team color
		label.add_theme_color_override("font_color", team_colors[player_teams[player_id]])

func get_pressed_button(player_id: int) -> String:
	# Check which button was pressed by this player
	var buttons = available_buttons[player_id]
	for button in buttons:
		if Input.is_action_just_pressed(button):
			return button
	return ""

func show_feedback(player_id: int, correct: bool):
	# Visual feedback when button is pressed
	if player_sprites.has(player_id) and is_instance_valid(player_sprites[player_id]):
		var sprite = player_sprites[player_id]
		var initial_y = sprite.get_meta("initial_y")
		
		if correct:
			# Green flash and bounce for correct
			sprite.get_child(0).play("default")
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.GREEN, 0.1)
			tween.parallel().tween_property(sprite, "position:y", initial_y - 10, 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
			tween.parallel().tween_property(sprite, "position:y", initial_y, 0.1)
		else:
			# Red flash and shake for incorrect
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.parallel().tween_property(sprite, "position:x", sprite.position.x - 5, 0.05)
			tween.parallel().tween_property(sprite, "position:x", sprite.position.x + 5, 0.05)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
			tween.parallel().tween_property(sprite, "position:x", sprite.position.x, 0.1)
