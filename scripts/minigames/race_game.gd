extends "res://scripts/minigames/minigame_base.gd"

# Race settings
var track_length: float = 1000.0 # Length for the track
var progress_per_press: float = 15.0 # Progress per button press

# Player colors
var player_colors = [
	Color(1, 0.2, 0.2),   # Red (Player 1)
	Color(0.2, 0.4, 1),   # Blue (Player 2)
]

# Player state
var player_progress: Dictionary = {} # player_id: current progress
var player_sprites: Dictionary = {}  # player_id: sprite node
var player_lanes: Dictionary = {} # player_id: lane instance
var player_inputs: Dictionary = {
	0: {"action": "p1_action"},
	1: {"action": "p2_action"},
}

# UI elements
var progress_container
var finish_line  
var player_lanes_container

# Remove preload/load variables for the scene
# const PlayerLaneScene = preload("res://scenes/ui/player_lane.tscn")
# var PlayerLaneScene = null

func _ready():
	print("Race Game: Ready")
	# Set minigame properties
	minigame_id = "race_game"
	minigame_name = "Button Mash Race"
	minigame_description = "Mash your action button to reach the finish line first!\nPlayer 1: Space\nPlayer 2: Enter"
	
	# Set time limit to 30 seconds
	minigame_duration = 30.0
	
	# Get UI references
	progress_container = get_node_or_null("UI/ProgressContainer")
	finish_line = get_node_or_null("GameContainer/FinishLine")
	player_lanes_container = get_node_or_null("GameContainer/PlayerLanes")
	
	# Log missing nodes
	if not is_instance_valid(progress_container):
		print("Progress container not found, will create")
	if not is_instance_valid(finish_line):
		print("Finish line not found, will create")
	if not is_instance_valid(player_lanes_container):
		print("Player lanes not found, will create")
	
	super._ready()
	
	# Update description label
	if description_label:
		description_label.text = minigame_description

func initialize_minigame():
	print("Race Game: Initializing")
	super.initialize_minigame()

	# Create missing UI nodes if needed
	ensure_ui_nodes()

	setup_players()
	setup_progress_bars()
	setup_race_inputs()

# Helper function to create UI nodes if they don't exist
func ensure_ui_nodes():
	# Create progress container if needed
	if not is_instance_valid(progress_container):
		print("Creating ProgressContainer")
		progress_container = GridContainer.new()
		progress_container.name = "ProgressContainer"
		
		# Set layout properties - position at bottom center
		if progress_container.has_method("set_anchors_preset"):
			progress_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			
		# Add margin from bottom for better spacing
		progress_container.offset_top = -80
		progress_container.offset_bottom = -20
		
		# Add to UI
		var ui = get_node("UI")
		if ui:
			ui.add_child(progress_container)
		else:
			add_child(progress_container)
	
	# Create GameContainer if needed
	var game_container = get_node_or_null("GameContainer")
	if not game_container:
		print("Creating GameContainer")
		game_container = Control.new()
		game_container.name = "GameContainer"
		
		# Set layout properties - use full screen
		if game_container.has_method("set_anchors_preset"):
			game_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		add_child(game_container)
	
	# Create player lanes container if needed
	if not is_instance_valid(player_lanes_container):
		print("Creating PlayerLanes")
		player_lanes_container = VBoxContainer.new()
		player_lanes_container.name = "PlayerLanes"
		
		# Position in center of screen with proper size
		if player_lanes_container.has_method("set_anchors_preset"):
			player_lanes_container.set_anchors_preset(Control.PRESET_CENTER)
			
		# Make wider and centered
		player_lanes_container.offset_left = -450
		player_lanes_container.offset_top = -150
		player_lanes_container.offset_right = 450
		player_lanes_container.offset_bottom = 100
		
		# Add spacing between lanes
		player_lanes_container.add_theme_constant_override("separation", 50)
		
		game_container.add_child(player_lanes_container)
	
	# Create finish line if needed
	if not is_instance_valid(finish_line):
		print("Creating FinishLine")
		finish_line = Node2D.new()
		finish_line.name = "FinishLine"
		finish_line.position = Vector2(1000, 300)
		game_container.add_child(finish_line)

func setup_players():
	print("Race Game: Setup players")

	# Clear previous lanes/sprites if any
	for i in player_lanes:
		if is_instance_valid(player_lanes[i]):
			player_lanes[i].queue_free()
	player_lanes.clear()
	player_sprites.clear() # Sprites are children of lanes now
	player_progress.clear()

	var player_count = MinigameManager.get_player_count()

	if not is_instance_valid(player_lanes_container):
		printerr("PlayerLanes container node not found!")
		return

	for i in range(player_count):
		player_progress[i] = 0.0

		# Create PlayerLane nodes directly
		var player_lane_instance = Control.new() # Root is a Control node
		player_lane_instance.name = "PlayerLane" + str(i+1)
		# Set layout properties for the Control node to behave like the scene version
		player_lane_instance.layout_mode = 3
		player_lane_instance.set_anchors_preset(Control.PRESET_TOP_WIDE) # Adjust preset if needed
		player_lane_instance.grow_horizontal = Control.GROW_DIRECTION_BOTH
		player_lane_instance.grow_vertical = Control.GROW_DIRECTION_BOTH
		player_lane_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_lane_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
		player_lane_instance.custom_minimum_size = Vector2(0, 60) # Increase lane height

		player_lanes_container.add_child(player_lane_instance)
		player_lanes[i] = player_lane_instance
		
		# Add a track background line for this lane - make it wider and more visually distinct
		var track_line = ColorRect.new()
		track_line.name = "TrackLine"
		track_line.color = Color(0.4, 0.4, 0.4, 1.0) # Medium grey
		track_line.size = Vector2(800, 15) # Width matches track_length, slightly thicker
		# Center the track in the lane
		track_line.position = Vector2(50, 30) # Center in the lane
		track_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player_lane_instance.add_child(track_line)
		
		# Add a finish line
		var finish_marker = ColorRect.new()
		finish_marker.name = "FinishMarker"
		finish_marker.color = Color(1, 1, 0, 1.0) # Yellow
		finish_marker.size = Vector2(5, 30) # Small vertical line but taller
		finish_marker.position = Vector2(845, 22) # At track_length + small offset
		player_lane_instance.add_child(finish_marker)

		# Create and add PlayerLabel
		var player_label = Label.new()
		player_label.name = "PlayerLabel"
		player_label.text = "P" + str(i+1)
		player_label.add_theme_font_size_override("font_size", 20) # Larger text
		# Position label to the left of track
		player_label.position = Vector2(20, 20)
		player_lane_instance.add_child(player_label)

		# Create and add PlayerSprite (Node2D)
		var player_sprite_node = Node2D.new()
		player_sprite_node.name = "PlayerSprite"
		player_sprite_node.position = Vector2(50, 30) # Start at beginning of track line
		# Store initial y position as metadata to reference later
		player_sprite_node.set_meta("initial_y", 30)
		player_lane_instance.add_child(player_sprite_node)
		player_sprites[i] = player_sprite_node # Store reference

		# Create the visual representation (ColorRect) inside PlayerSprite
		var color_rect = ColorRect.new()
		color_rect.color = player_colors[i % player_colors.size()]
		color_rect.size = Vector2(40, 40) # Larger
		color_rect.position = Vector2(-20, -20) # Center on sprite position
		player_sprite_node.add_child(color_rect)
		player_sprite_node.visible = true # Initially visible, will be controlled in gameplay

		print("Created player lane and sprite nodes for player ", i)

func setup_progress_bars():
	print("Race Game: Setup progress bars")
	if not is_instance_valid(progress_container):
		printerr("ProgressContainer node not found!")
		return

	# Clear existing progress bars (if any - safer if re-initializing)
	for child in progress_container.get_children():
		progress_container.remove_child(child)
		child.queue_free()

	var player_count = MinigameManager.get_player_count()
	
	# Explicitly set to player_count columns for horizontal layout
	progress_container.columns = player_count 
	
	# Add margin/spacing between columns for better separation
	if progress_container.has_method("add_theme_constant_override"):
		progress_container.add_theme_constant_override("h_separation", 20)

	for i in range(player_count):
		# Create a VBox for each player's label+progressbar
		var vbox = VBoxContainer.new()
		vbox.name = "PlayerProgressVBox" + str(i+1)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Add player label above progress bar
		var label = Label.new()
		label.text = "Player " + str(i+1)
		# Match color with player sprite
		label.add_theme_color_override("font_color", player_colors[i % player_colors.size()])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		
		# Create progress bar
		var pb = ProgressBar.new()
		pb.name = "ProgressBarP" + str(i+1)
		pb.min_value = 0
		pb.max_value = track_length
		pb.value = 0
		pb.custom_minimum_size = Vector2(100, 20)
		
		# Set progress bar colors to match player colors
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = player_colors[i % player_colors.size()]
		style_box.corner_radius_top_left = 3
		style_box.corner_radius_top_right = 3
		style_box.corner_radius_bottom_left = 3
		style_box.corner_radius_bottom_right = 3
		pb.add_theme_stylebox_override("fill", style_box)
		
		vbox.add_child(pb)
		
		# Add to grid container
		progress_container.add_child(vbox)

func setup_race_inputs():
	print("Race Game: Setting up inputs")
	
	# Clear and recreate player_inputs dictionary
	player_inputs.clear()
	
	# Get player count and create inputs for each player
	var player_count = MinigameManager.get_player_count()
	for i in range(player_count):
		if i == 0:
			player_inputs[i] = {"action": "p1_action"}
		elif i == 1:
			player_inputs[i] = {"action": "p2_action"}
		elif i == 2:
			player_inputs[i] = {"action": "p3_action"}
		elif i == 3:
			player_inputs[i] = {"action": "p4_action"}
		else:
			player_inputs[i] = {"action": "p1_action"}
			
	print("Player inputs configured for " + str(player_count) + " players")

func start_gameplay():
	print("Race Game: Starting")
	super.start_gameplay()

	# Make player sprites visible
	for i in player_sprites:
		if is_instance_valid(player_sprites[i]):
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

	var all_finished_this_frame = true # Check if game should end now
	var player_count = MinigameManager.get_player_count()

	for player_id in range(player_count):
		# Check if player already finished in a previous frame
		if player_finished.get(player_id, false):
			continue # Skip finished players

		all_finished_this_frame = false # At least one player is still playing

		# --- Handle Input and Progress ---
		# Check if the player_id exists in player_inputs dictionary
		if not player_inputs.has(player_id):
			print("Warning: Player ", player_id, " has no input configuration, skipping")
			continue
			
		var action_name = player_inputs[player_id]["action"]
		if Input.is_action_just_pressed(action_name):
			player_progress[player_id] = min(player_progress[player_id] + progress_per_press, track_length)
			print("Player " + str(player_id) + " pressed action. Progress: " + str(player_progress[player_id]))

			# --- Update Visuals (Progress Bar & Sprite Position) ---
			# Find the progress bar - now inside a VBoxContainer
			var vbox_path = "PlayerProgressVBox" + str(player_id+1)
			var vbox = progress_container.get_node_or_null(vbox_path)
			if vbox:
				var progress_bar = vbox.get_node("ProgressBarP" + str(player_id+1))
				if progress_bar:
					progress_bar.value = player_progress[player_id]
				else:
					printerr("Could not find progress bar inside vbox: ", vbox_path)
			else:
				printerr("Could not find progress bar vbox at path: ", vbox_path)

			if is_instance_valid(player_sprites[player_id]):
				# Calculate sprite position based on progress
				# Sprite should move along the track line from start (50,30) to finish (~850,30)
				var start_pos_x = 50.0 # Match updated TrackLine starting x
				var end_pos_x = 850.0 # Match updated TrackLine ending x (start + width)
				var normalized_progress = player_progress[player_id] / track_length
				
				# Get the stored initial y position to maintain vertical alignment
				var initial_y = player_sprites[player_id].get_meta("initial_y")
				
				# Update x position based on progress, keep y position fixed
				player_sprites[player_id].position.x = lerp(start_pos_x, end_pos_x, normalized_progress)
				player_sprites[player_id].position.y = initial_y
				
				# Add a small bounce effect as feedback when button is pressed
				var tween = create_tween()
				tween.tween_property(player_sprites[player_id], "position:y", initial_y - 5, 0.1)
				tween.tween_property(player_sprites[player_id], "position:y", initial_y, 0.1)

		# --- Check for Finish ---
		if player_progress[player_id] >= track_length and not player_finished.get(player_id, false): # Ensure not already processed
			var rank = get_finish_rank(player_id) # Get rank first
			# Calculate a simple score: e.g., (total players - rank + 1) * 100 points
			# Assuming MinigameManager.get_player_count() gives the number of active players.
			var total_players = MinigameManager.get_player_count()
			var calculated_score = (total_players - rank + 1) * 100 # Higher score for lower rank
			calculated_score = max(0, calculated_score) # Ensure score is not negative

			# Use the base class method to set player as finished and store their score
			set_player_finished(player_id, calculated_score) 
			# player_finished[player_id] = true is handled by set_player_finished
			# player_scores[player_id] = calculated_score is handled by set_player_finished

			print("Player " + str(player_id) + " finished in rank " + str(rank) + " with calculated score: " + str(calculated_score))

			# Optional: Add visual indicator on the player/lane
			if is_instance_valid(player_sprites[player_id]):
				var finish_label = Label.new()
				finish_label.text = str(rank) + "!"
				finish_label.add_theme_font_size_override("font_size", 20)
				finish_label.add_theme_color_override("font_color", Color(1, 1, 0))
				finish_label.position = Vector2(0, -30) # Adjust pos relative to sprite
				player_sprites[player_id].add_child(finish_label)


	# --- Check if All Players Finished ---
	# Check *after* processing all players for the frame
	var current_finishers = player_finished.keys().size()
	if current_finishers >= player_count:
		all_finished_this_frame = true


	if all_finished_this_frame and current_state == MinigameState.PLAYING:
		print("RaceGame: All players finished!")
		end_minigame()

# --- Helper Functions ---

func get_finish_rank(finished_player_id):
	# Count how many players have finished so far
	var rank = 0
	
	# Iterate through all players who have finished
	for player_id in player_finished:
		# Count only players who finished before this one
		if player_finished[player_id] and player_id != finished_player_id:
			rank += 1
	
	# Add 1 because rank starts at 1, not 0
	return rank + 1

# calculate_score is inherited from minigame_base

func process_finished(delta):
	# Call superclass logic
	super.process_finished(delta)

func _exit_tree():
	print("Race Game: Cleaning up")
	# Clear dictionaries
	player_progress.clear()
	player_sprites.clear()
	player_lanes.clear()
	player_inputs.clear()

func end_minigame():
	print("Race Game: Game over")
	current_state = MinigameState.FINISHED
	
	# Show results screen
	if results_container:
		results_container.visible = true
		display_results()
	else:
		print("Results container not found")
		
	# Create results dictionary
	var final_results = player_scores.duplicate()
	final_results["minigame_id"] = minigame_id
	final_results["ranking"] = get_player_ranking()
	
	# Send results
	emit_signal("minigame_completed", final_results)
