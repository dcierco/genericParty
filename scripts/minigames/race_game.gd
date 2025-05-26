extends "res://scripts/minigames/minigame_base.gd"

# Race settings
var track_length: float = 1000.0 # Length for the track 
var progress_per_press: float = 15.0 # Progress per button press

# Player state
var player_progress: Dictionary = {} # player_id: current progress
var player_sprites: Dictionary = {}  # player_id: sprite node
var player_detailed_scores: Dictionary = {} # Detailed score breakdown for each player

# Player state uses team colors from minigame_base.gd

# Input mapping
var player_inputs: Dictionary = {
	0: {"action": "p1_action", "team": "red"},
	1: {"action": "p2_action", "team": "blue"},
}

# UI node references - using @onready to get them when scene is ready
@onready var progress_container = $UI/ProgressContainer
@onready var player_lanes_container = $GameContainer/PlayerLanes
@onready var player_lane1 = $GameContainer/PlayerLanes/PlayerLane1
@onready var player_lane2 = $GameContainer/PlayerLanes/PlayerLane2
@onready var progress_bar_p1 = $UI/ProgressContainer/Player1ProgressVBox/ProgressBarP1
@onready var progress_bar_p2 = $UI/ProgressContainer/Player2ProgressVBox/ProgressBarP2

func _ready():
	print("Race Game: Ready")
	# Set minigame properties
	minigame_id = "race_game"
	minigame_name = "Button Mash Race"
	minigame_description = "Mash your action button to reach the finish line first!\nPlayer 1: Space\nPlayer 2: Enter"
	
	# Set time limit to 10 seconds
	minigame_duration = 10.0
	time_remaining = 10.0
	
	super._ready()
	
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
		
		# Handle input
		var action_name = player_inputs[player_id]["action"]
		if Input.is_action_just_pressed(action_name):
			player_progress[player_id] = min(player_progress[player_id] + progress_per_press, track_length)
			print("Player " + str(player_id) + " pressed action. Progress: " + str(player_progress[player_id]))
			
			# Update progress bar
			update_player_progress(player_id)
			
			# Add a bounce effect as feedback when button is pressed
			if player_sprites.has(player_id) and is_instance_valid(player_sprites[player_id]):
				var initial_y = player_sprites[player_id].get_meta("initial_y")
				var tween = create_tween()
				tween.tween_property(player_sprites[player_id], "position:y", initial_y - 5, 0.1)
				tween.tween_property(player_sprites[player_id], "position:y", initial_y, 0.1)
		
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
	
	# Win bonus for finishing first (100 points)
	var win_bonus = 100 if rank == 1 else 0
	
	# Total score
	var score = distance_score + win_bonus
	
	# Store detailed score breakdown for results display
	player_detailed_scores[player_id] = {
		"distance": distance_score,
		"win_bonus": win_bonus,
		"total": score
	}
	
	# Mark player as finished and set score
	set_player_finished(player_id, score)
	
	# Get player's team from base class
	var team = player_teams.get(player_id, "red")
	print("Player " + str(player_id) + " (Team " + team + ") finished in rank " + str(rank))
	print("Score breakdown: Distance " + str(distance_score) + ", Win bonus: " + str(win_bonus) + ", Total: " + str(score))
	
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

func _exit_tree():
	print("Race Game: Cleaning up")
	# Clear dictionaries
	player_progress.clear()
	player_sprites.clear()
	player_inputs.clear()

func end_minigame():
	print("Race Game: Game over")
	
	# Make sure we only end the game once
	if current_state == MinigameState.FINISHED or current_state == MinigameState.RESULTS:
		print("Race Game: Already finished, ignoring duplicate end_minigame call")
		return
	
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
				"win_bonus": 0, # No win bonus for not finishing
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
				
				# Win bonus if applicable
				if score_data.win_bonus > 0:
					var bonus_label = Label.new()
					bonus_label.text = "+ " + str(score_data.win_bonus) + " points (win bonus)"
					bonus_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
					player_results.add_child(bonus_label)
				
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
