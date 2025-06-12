extends "res://scripts/minigames/minigame_base.gd"

# Game settings
var cell_size = 40
var grid_width = 25
var grid_height = 25
var lava_speed = 11.3  # Cells per second (to fill the grid in 60 seconds)

# Spiral shrinking parameters
var spiral_pos = Vector2.ZERO
var spiral_direction = 0  # 0 = right, 1 = down, 2 = left, 3 = up
var spiral_length = 1
var spiral_step_count = 0

# Game state
var lava_cells = []
var player_detailed_scores = {}
var eliminated_players = {}

# Time tracking
var shrink_timer = 0.0
var shrink_interval = 0.0  # Will be calculated in _ready

# Player settings
const PLAYER_SPEED = 250.0
const PUSH_POWER = 4000.0

const PUSH_RANGE = 50

# Node references
@onready var platform = $GameContainer/PlatformContainer/Platform
@onready var player_spawn_points = $GameContainer/PlayerSpawnPoints
@onready var player1 = $GameContainer/Players/Player1
@onready var player2 = $GameContainer/Players/Player2
@onready var debug_info = $GameContainer/DebugInfo

func _ready():
	print("Shrinking Platform: Ready")
	# Set minigame properties
	minigame_id = "shrinking_platform"
	minigame_name = "Shrinking Platform"
	minigame_description = "Stay on the platform as it shrinks! Push opponents into the lava!\nControls:\nPlayer 1: WASD (move) + Space (push)\nPlayer 2: Arrow Keys (move) + Enter (push)"
	
	# Set time limit to 60 seconds
	minigame_duration = 60.0
	
	# Set shrink interval based on lava speed
	shrink_interval = 1.0 / lava_speed  # Duration between adding lava cells
	
	super._ready()
	
	$BackgroundMusic.play()
	
	# Update description label
	if description_label:
		description_label.text = minigame_description

func initialize_minigame():
	print("Shrinking Platform: Initializing")
	super.initialize_minigame()
	
	player_detailed_scores.clear()
	setup_game_area()
	setup_players()
	reset_spiral()

# Initialize the platform and game area
func setup_game_area():
	# Make sure platform exists
	if not is_instance_valid(platform):
		print("Platform not found!")
		return
		
	# Configure platform grid size
	platform.columns = grid_width
	
	# Clear any existing cells
	for child in platform.get_children():
		child.queue_free()
	
	# Add cells to the platform
	var total_cells = grid_width * grid_height
	for i in range(total_cells):
		var cell = ColorRect.new()
		cell.name = "Cell_" + str(i)
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		cell.color = Color(0.8, 0.8, 0.8) # Light gray platform
		platform.add_child(cell)
		
	# Update debug info
	update_debug_info()

# Initialize the player characters
func setup_players():
	# Get player count
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)  # Limit to 2 players for this minigame
	
	# Reset player1
	if is_instance_valid(player1):
		player1.position = player_spawn_points.get_node("Player1Spawn").position
		player1.speed = PLAYER_SPEED
		player1.eliminated = false
		player1.visible = true
	
	# Reset player2
	if is_instance_valid(player2):
		player2.position = player_spawn_points.get_node("Player2Spawn").position
		player1.speed = PLAYER_SPEED
		player2.eliminated = false
		player2.visible = player_count > 1  # Only show if we have at least 2 players
	
	# Initialize player scores
	for i in range(player_count):
		player_scores[i] = 0
		player_finished[i] = false

# Reset the spiral parameters to start from the edge
func reset_spiral():
	spiral_pos = Vector2(0, 0)
	spiral_direction = 0  # Start moving right
	spiral_length = grid_width
	spiral_step_count = 0
	
	# Clear existing lava cells
	lava_cells.clear()
	eliminated_players.clear()
	
	# Update debug info
	update_debug_info()

func start_gameplay():
	print("Shrinking Platform: Starting")
	super.start_gameplay()
	
	# Make sure players are visible and active
	if is_instance_valid(player1):
		player1.visible = true
	
	if is_instance_valid(player2):
		player2.visible = MinigameManager.get_player_count() > 1

func _process(delta):
	match current_state:
		MinigameState.INTRO:
			super.process_intro(delta)
		MinigameState.PLAYING:
			process_playing(delta)
		MinigameState.FINISHED:
			process_finished(delta)

func process_playing(delta):
	if has_time_limit:
		time_remaining -= delta
		update_time_display()
		
		if time_remaining <= 0:
			end_minigame()
			return
	
	# Shrink the platform over time
	shrink_timer += delta
	if shrink_timer >= shrink_interval:
		shrink_timer = 0
		add_lava_cell()
	
	# Check push
	check_push()
	
	# Check if players are in lava
	check_player_eliminations()
	
	# Check if game is over (only one player left)
	check_game_over()
	
	# Update debug info
	update_debug_info()

# Add a new lava cell at the current spiral position
func add_lava_cell():
	# Calculate cell index
	var cell_index = int(spiral_pos.y * grid_width + spiral_pos.x)
	
	# Get the cell if it exists and not already lava
	if cell_index >= 0 and cell_index < platform.get_child_count() and not cell_index in lava_cells:
		var cell = platform.get_child(cell_index)
		cell.color = Color(1, 0.5, 0, 0.8)  # Orange lava
		lava_cells.append(cell_index)
	
	# Move to next position in spiral
	spiral_step_count += 1
	
	# Check if we need to change direction
	if spiral_step_count == spiral_length:
		spiral_direction = (spiral_direction + 1) % 4  # Change direction
		spiral_step_count = 0
		
		# After turning twice (completing one "layer" of the spiral), reduce spiral_length
		if spiral_direction % 2 == 0:
			spiral_length -= 1
	
	# Move in current direction
	match spiral_direction:
		0: # Right
			spiral_pos.x += 1
		1: # Down
			spiral_pos.y += 1
		2: # Left
			spiral_pos.x -= 1
		3: # Up
			spiral_pos.y -= 1
	
	# Ensure we stay within bounds
	spiral_pos.x = clamp(spiral_pos.x, 0, grid_width - 1)
	spiral_pos.y = clamp(spiral_pos.y, 0, grid_height - 1)

func check_push():
	if Input.is_action_just_pressed("p1_action"):
		push_other_players(player1)
		
	if Input.is_action_just_pressed("p2_action"):
		push_other_players(player2)

# Push other players away from this player
func push_other_players(pusher):
	var active_players = []
	
	# Add player1 if active
	if is_instance_valid(player1) and not player1.eliminated and player1 != pusher:
		active_players.append(player1)
	
	# Add player2 if active
	if is_instance_valid(player2) and not player2.eliminated and player2 != pusher:
		active_players.append(player2)
	
	# Push each active player
	for player in active_players:
		var distance = player.position.distance_to(pusher.position)
		if distance < PUSH_RANGE:  # Push range
			var push_direction = (player.position - pusher.position).normalized()
			player.position += push_direction * PUSH_POWER * 0.05  # Small immediate push
			player.velocity += push_direction * PUSH_POWER

# Check if any players are touching lava
func check_player_eliminations():
	# Check player 1
	check_single_player_elimination(player1)
	
	# Check player 2
	check_single_player_elimination(player2)

# Check if a single player is touching lava
func check_single_player_elimination(player: CharacterBody2D):
	if not is_instance_valid(player) or player.eliminated:
		return
		
	# Get the cell the player is on
	var player_pos = player.position - platform.global_position
	var cell_x = int(player_pos.x / cell_size)
	var cell_y = int(player_pos.y / cell_size)
	
	# Keep within bounds
	cell_x = clamp(cell_x, 0, grid_width - 1)
	cell_y = clamp(cell_y, 0, grid_height - 1)
	
	var cell_index = cell_y * grid_width + cell_x
	
	# Check if player is on a lava cell
	if cell_index in lava_cells:
		eliminate_player(player)
		
	# Also check if player is out of bounds
	var platform_width = grid_width * cell_size
	var platform_height = grid_height * cell_size
	if player_pos.x < 0 or player_pos.x >= platform_width or player_pos.y < 0 or player_pos.y >= platform_height:
		eliminate_player(player)

# Eliminate a player who fell into lava
func eliminate_player(player):
	if player.eliminated:
		return
		
	player.eliminate()
	player.visible = false
	
	var player_id = player.player_id
	eliminated_players[player_id] = true
	
	# Calculate survival score: percentage of platform consumed when eliminated
	var survival_score = int((float(lava_cells.size()) / (grid_width * grid_height)) * 100)
	
	# Store detailed score breakdown
	player_detailed_scores[player_id] = {
		"survival": survival_score,
		"win_bonus": 0, # No win bonus yet (will be set for last player standing)
		"total": survival_score
	}
	
	var team = player_teams.get(player_id, "red")
	print("Player " + str(player_id + 1) + " (Team " + team + ") eliminated! Survival score: " + str(survival_score))

# Check if game should end
func check_game_over():
	var active_players = []
	var last_player_standing = -1
	
	# Check player 1
	if is_instance_valid(player1) and not player1.eliminated:
		active_players.append(player1)
		last_player_standing = player1.player_id
	
	# Check player 2
	if is_instance_valid(player2) and not player2.eliminated:
		active_players.append(player2)
		last_player_standing = player2.player_id
	
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)
	
	if active_players.size() <= 1 and eliminated_players.size() > 0:
		# Award score to last player standing
		if last_player_standing >= 0:
			# Calculate win bonus: 100 points for winning + percentage of platform consumed
			var survival_score = int((float(lava_cells.size()) / (grid_width * grid_height)) * 100)
			var win_bonus = 100
			var total_score = survival_score + win_bonus
			
			# Store detailed score breakdown
			player_detailed_scores[last_player_standing] = {
				"survival": survival_score,
				"win_bonus": win_bonus,
				"total": total_score
			}
			
			# Mark as finished with total score
			set_player_finished(last_player_standing, total_score)
		
		# End the minigame
		print("Shrinking Platform: Game over, last player standing: " + str(last_player_standing + 1))
		end_minigame()

func process_finished(delta):
	super.process_finished(delta)

# Display debug info about platform state
func update_debug_info():
	if is_instance_valid(debug_info):
		debug_info.text = "Platform Cells: " + str(platform.get_child_count()) + "\n"
		debug_info.text += "Lava Cells: " + str(lava_cells.size()) + "\n"
		debug_info.text += "Spiral Position: (" + str(spiral_pos.x) + "," + str(spiral_pos.y) + ")"

# End the minigame and calculate results
func end_minigame():
	print("Shrinking Platform: Game over")
	
	# Make sure we only end the game once
	if current_state == MinigameState.FINISHED or current_state == MinigameState.RESULTS:
		print("Shrinking Platform: Already finished, ignoring duplicate end_minigame call")
		return
	
	# Complete any unfinished players with their current progress
	var player_count = MinigameManager.get_player_count()
	player_count = min(player_count, 2)
	
	for player_id in range(player_count):
		if not player_finished.get(player_id, false):
			# Calculate score based on survival
			var survival_score = int((float(lava_cells.size()) / (grid_width * grid_height)) * 100)
			
			# Store detailed score breakdown
			player_detailed_scores[player_id] = {
				"survival": survival_score,
				"win_bonus": 0, # No win bonus for not finishing
				"total": survival_score
			}
			
			# Mark as finished with current score
			set_player_finished(player_id, survival_score)
	
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
	
	# Add platform-specific info to team labels
	if red_team_label and blue_team_label:
		# Check who survived longer
		var red_survived = not eliminated_players.has(0) 
		var blue_survived = not eliminated_players.has(1)
		
		# Enhance the win/lose message with platform details
		if red_survived and not blue_survived:
			red_team_label.text = "RED TEAM WINS\nLast one standing!"
			blue_team_label.text = "BLUE TEAM LOSES\nFell into lava!"
		elif blue_survived and not red_survived:
			blue_team_label.text = "BLUE TEAM WINS\nLast one standing!"
			red_team_label.text = "RED TEAM LOSES\nFell into lava!"
		else:
			# Both fell or both survived (time ran out)
			if team_scores["red"] > team_scores["blue"]:
				red_team_label.text = "RED TEAM WINS\nSurvived longer!"
				blue_team_label.text = "BLUE TEAM LOSES\nFell earlier!"
			else:
				blue_team_label.text = "BLUE TEAM WINS\nSurvived longer!"
				red_team_label.text = "RED TEAM LOSES\nFell earlier!"
	
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
				
				# Survival points
				var survival_label = Label.new()
				survival_label.text = "+ " + str(score_data.survival) + " points (survived " + str(score_data.survival) + "% of platform collapse)"
				player_results.add_child(survival_label)
				
				# Win bonus if applicable
				if score_data.win_bonus > 0:
					var bonus_label = Label.new()
					bonus_label.text = "+ " + str(score_data.win_bonus) + " points (last survivor bonus)"
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
